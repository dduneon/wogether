# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wogether (워게더)** — 크루를 만들고, 주간 운동 목표를 설정하고, 인증 사진을 올리며 서로 독촉하는 운동 책임 앱.

레포 폴더명은 `owoonstagram`이지만 앱/DB명은 `wogether` (`wogether.db`).

## Running the App

```bash
# 웹 앱 (Flask + Jinja2 템플릿, 현재 서비스 중인 버전)
source .venv/bin/activate
python app.py          # http://0.0.0.0:3030, debug=True

# 프로덕션
gunicorn app:app

# React 프론트엔드 개발 서버 (backend/ API와 연동)
cd frontend && npm install && npm run dev

# React 빌드
cd frontend && npm run build
```

SQLite DB(`wogether.db`)와 업로드 폴더(`static/uploads/`)는 첫 실행 시 자동 생성.

## Architecture

코드베이스에 **두 가지 서버 구현이 공존**한다:

| | 경로 | 상태 |
|---|---|---|
| **웹 앱** | `app.py` (단일 파일) | 현재 운영 중 |
| **API 서버** (리팩토링 중) | `backend/` 패키지 | WIP — `app.py`의 API 부분을 Blueprint로 분리한 것 |
| **React SPA** | `frontend/` | WIP — `backend/`의 `/api/` 엔드포인트 소비 |

### app.py 구조 (섹션별 주석으로 구분)

1. **앱 설정** — Flask, SQLAlchemy, 업로드 설정, KST 타임존 헬퍼
2. **DB 모델** — 모든 SQLAlchemy 모델
3. **웹 인증 라우트** — `/signup`, `/login`, `/logout`
4. **웹 크루 라우트** — `/`, `/crew/create`, `/join/<code>`, `/crew/<id>`
5. **웹 목표 라우트** — 목표 생성·승인·삭제
6. **웹 운동 인증 라우트** — 사진 업로드 + 인증 등록
7. **웹 독촉·알림 라우트**
8. **Android REST API** — `/api/` 하위, 토큰 인증

### 두 가지 인증 시스템이 병렬로 동작

- **웹:** Flask-Login 세션 기반 (`@login_required`)
- **API:** `User.api_token` Bearer 토큰 (`@token_required` 데코레이터, `request.api_user` 설정)

### backend/ 패키지 구조

```
backend/
  app.py          # create_app() 팩토리
  config.py
  extensions.py   # db, login_manager 인스턴스
  helpers.py
  models/__init__.py
  routes/api/     # auth, crews, goals, logs, notifications Blueprint
```

### frontend/ 구조

React + Vite SPA. `src/api/client.js`는 axios 기반으로 `/api/` 호출, localStorage의 Bearer 토큰으로 인증. 401 시 자동 로그아웃.

## Data Model

```
User ──< CrewMembership >── Crew
User ──< Goal (크루별, 주간 횟수)
         Goal ──< GoalApproval (팀원 투표로 승인)
User ──< WorkoutLog (크루별, Goal에 선택적 연결)
         WorkoutLog ──< WorkoutImage (WebP로 static/uploads/ 저장)
Notification (nudge | goal_request | goal_approved | join)
CrewActivity  (피드용 이벤트 로그)
WorkoutLike
```

**목표 승인 흐름:** 새 목표는 `pending` 상태. 소유자 외 모든 팀원이 승인해야 `approved`로 전환. `Goal.refresh_status()`가 처리. 1인 크루는 즉시 자동 승인.

**운동 인증 → 목표 진행률:** `Goal.progress_this_week()`이 이번 주 KST 기준 해당 목표에 연결된 WorkoutLog 수를 카운트.

## Key Conventions

- **타임존:** DB에 UTC로 저장, 표시·주간 계산은 KST(UTC+9). `kst_now()`, `week_range_kst()` 헬퍼 사용.
- **이미지:** `save_optimized_image()`로 최대 1080×1080, WebP 80% 품질 저장.
- **UI 텍스트·플래시 메시지:** 한국어.
- **환경변수:** `SECRET_KEY` (기본값은 dev용, 프로덕션에서 반드시 변경).

## Docker / CI

```bash
# 로컬 빌드 테스트
docker build -t wogether .

# 실행 (MariaDB는 별도 컨테이너로 service-net에 띄워야 함)
docker run -d \
  --network service-net \
  -p 8000:8000 \
  -v /host/uploads:/app/static/uploads \
  -e SECRET_KEY=실제키 \
  -e DB_HOST=mariadb \
  -e DB_PORT=3306 \
  -e DB_USER=wogether \
  -e DB_PASSWORD=비밀번호 \
  -e DB_NAME=wogether \
  ghcr.io/dduneon/wogether:main
```

**DB 환경변수:**

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `DB_HOST` | `localhost` | MariaDB 호스트 |
| `DB_PORT` | `3306` | MariaDB 포트 |
| `DB_USER` | `wogether` | DB 유저 |
| `DB_PASSWORD` | `` | DB 비밀번호 |
| `DB_NAME` | `wogether` | DB 이름 |

GitHub Actions(`/.github/workflows/docker-publish.yml`)가 `main` 브랜치 push 또는 `v*.*.*` 태그 시 `ghcr.io/dduneon/wogether`로 자동 빌드·푸시.
