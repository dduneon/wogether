# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wogether (워게더)** — 크루를 만들고, 주간 운동 목표를 설정하고, 인증 사진을 올리며 서로 독촉하는 운동 책임 앱.

앱/DB명: `wogether` (MariaDB, DB명 `wogether`).

## Running the App

```bash
# 웹 앱 (Flask가 React 빌드 서빙)
source .venv/bin/activate
python app.py          # http://0.0.0.0:3030, debug=True

# 프로덕션
gunicorn app:app

# React 개발 서버 (vite.config.js에서 /api → localhost:3030 프록시)
cd frontend && npm install && npm run dev   # http://localhost:5173

# React 빌드 (app.py가 frontend/dist/ 를 정적으로 서빙)
cd frontend && npm run build

# Flutter 앱
cd mobile && flutter run       # 연결된 Android 기기/에뮬레이터
cd mobile && flutter build apk
```

DB 테이블은 첫 요청 시 `before_request`에서 자동 생성(`db.create_all()`). 로컬 개발 시 MariaDB와 MinIO가 필요하며 환경변수로 연결 설정.

## Architecture

**단일 Flask 파일(`app.py`) + React SPA + Flutter 앱**의 세 가지 클라이언트 구조:

| | 경로 | 상태 |
|---|---|---|
| **Flask API + SPA 서버** | `app.py` | 운영 중 — `/api/` 엔드포인트 + `frontend/dist/` 정적 서빙 |
| **React SPA** | `frontend/` | 운영 중 — `app.py`의 `/api/` 소비 |
| **Flutter 앱** | `mobile/` | Android 앱 — `app.py`의 `/api/` 소비 |
| **backend/ 패키지** | `backend/` | WIP — `app.py` Blueprint 분리 시도, 미완성 |

### app.py 구조

1. **앱 설정** — Flask(`static_folder=frontend/dist`), SQLAlchemy, MinIO, Firebase Admin, KST 헬퍼
2. **DB 모델** — 모든 SQLAlchemy 모델
3. **React SPA 서빙** — `/<path:path>` catch-all → `frontend/dist/index.html` fallback
4. **REST API** — `/api/` 하위, `@token_required` Bearer 토큰 인증

### 인증

React/Flutter 모두 **Bearer 토큰**만 사용 (`User.api_token`, `@token_required` 데코레이터, `request.api_user` 설정).  
Flask-Login은 모델 상속(`UserMixin`)을 위해 남아 있으나 세션 인증은 사용하지 않음.

### API 엔드포인트

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/api/signup` | 회원가입 |
| POST | `/api/login` | 로그인 |
| GET | `/api/me` | 내 정보 |
| POST | `/api/fcm-token` | FCM 토큰 등록 |
| GET/POST | `/api/crews` | 크루 목록/생성 |
| POST | `/api/crews/join` | 초대코드로 가입 |
| GET | `/api/crews/<id>` | 크루 상세 |
| POST | `/api/crews/<id>/leave` | 크루 탈퇴 |
| GET/POST | `/api/crews/<id>/goals` | 목표 목록/생성 |
| POST | `/api/goals/<id>/approve` | 목표 승인 |
| DELETE | `/api/goals/<id>` | 목표 삭제 |
| GET/POST | `/api/crews/<id>/logs` | 운동 로그 목록/인증 |
| DELETE | `/api/logs/<id>` | 로그 삭제 |
| POST | `/api/logs/<id>/like` | 좋아요 |
| POST | `/api/crews/<id>/nudge/<uid>` | 콕 찌르기 |
| GET | `/api/notifications` | 알림 목록 |
| POST | `/api/notifications/read` | 전체 읽음 처리 |
| DELETE | `/api/notifications/<id>` | 알림 삭제 |
| GET | `/api/notifications/unread-count` | 읽지 않은 알림 수 |
| GET | `/api/dashboard` | 대시보드 |

### React 프론트엔드 (`frontend/`)

Vite + React SPA. `src/api/client.js`는 axios 기반, `localStorage`의 Bearer 토큰으로 인증, 401 시 자동 로그아웃.

- **인증 상태**: `src/context/AuthContext.jsx`
- **테마**: `src/context/ThemeContext.jsx`
- **라우팅**: `src/App.jsx` (react-router-dom)
- **개발 프록시**: `vite.config.js`에서 `/api`, `/static` → `http://localhost:3030`

### Flutter 앱 (`mobile/`)

`lib/api/client.dart`가 Bearer 토큰(SharedPreferences)으로 `/api/` 호출. GoRouter(`lib/router.dart`)로 화면 전환.

## Data Model

```
User ──< CrewMembership >── Crew
User ──< Goal (크루별, 주간 횟수)
         Goal ──< GoalApproval (팀원 투표로 승인)
User ──< WorkoutLog (크루별, Goal에 선택적 연결)
         WorkoutLog ──< WorkoutImage (WebP로 MinIO에 저장, filename만 DB에)
Notification (nudge | goal_request | goal_approved | join)
CrewActivity  (피드용 이벤트 로그)
WorkoutLike
```

**목표 승인 흐름:** 새 목표는 `pending` 상태. 소유자 외 모든 팀원이 승인해야 `approved`로 전환. `Goal.refresh_status()`가 처리. 1인 크루는 즉시 자동 승인.

**운동 인증 → 목표 진행률:** `Goal.progress_this_week()`이 이번 주 KST 기준 해당 목표에 연결된 WorkoutLog 수를 카운트.

## Key Conventions

- **타임존:** DB에 UTC 저장, 표시·주간 계산은 KST(UTC+9). `kst_now()`, `week_range_kst()` 헬퍼 사용.
- **이미지:** `save_optimized_image()`로 최대 1080×1080, WebP 80% 품질로 MinIO에 저장.
- **UI 텍스트·에러 메시지:** 한국어.
- **환경변수:** `SECRET_KEY` 기본값은 dev용 — 프로덕션에서 반드시 변경.

## Docker / CI

Dockerfile은 멀티스테이지 빌드 — Node로 React 빌드 후 Python 이미지에 `frontend/dist/` 복사.

```bash
docker build -t wogether .

docker run -d \
  --network service-net \
  -p 4010:4010 \
  -e SECRET_KEY=실제키 \
  -e DB_HOST=mariadb -e DB_USER=wogether -e DB_PASSWORD=비밀번호 -e DB_NAME=wogether \
  -e MINIO_ENDPOINT=minio:9000 -e MINIO_ACCESS_KEY=admin -e MINIO_SECRET_KEY=비밀번호 \
  -e MINIO_BUCKET=wogether -e MINIO_PUBLIC_URL=http://서버IP:9000 \
  ghcr.io/dduneon/wogether:main
```

GitHub Actions(`.github/workflows/docker-publish.yml`)가 `main` 브랜치 push 또는 `v*.*.*` 태그 시 자동 빌드·푸시.
