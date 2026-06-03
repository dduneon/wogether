# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Wogether (워게더)** — a workout accountability app where users form crews, set weekly goals, post workout logs (with photos), and nudge each other to stay on track.

The app name in the codebase/DB is "wogether" (database: `wogether.db`), but the repo folder is `owoonstagram`.

## Running the App

```bash
source .venv/bin/activate
python app.py          # starts on http://0.0.0.0:3030 with debug=True
```

For production:
```bash
gunicorn app:app
```

The SQLite DB (`wogether.db`) and upload folder (`static/uploads/`) are created automatically on first run.

## Architecture

Everything lives in a single file: [`app.py`](app.py). There is no blueprint or package structure.

**Sections (marked with comments):**
1. App config — Flask, SQLAlchemy, upload settings, KST timezone helpers
2. DB models — all SQLAlchemy models defined here
3. Web auth routes — `/signup`, `/login`, `/logout`
4. Web crew routes — `/`, `/crew/create`, `/join/<code>`, `/crew/<id>`, etc.
5. Web goal routes — goal creation, approval, deletion
6. Web workout log routes — photo upload + log creation
7. Web nudge/notification routes
8. Android REST API — token-authenticated JSON API mirroring the web routes under `/api/`

**Two auth systems run in parallel:**
- Web: Flask-Login session-based (`@login_required`)
- API: Bearer token via `User.api_token` (`@token_required` decorator, sets `request.api_user`)

## Data Model

```
User ──< CrewMembership >── Crew
User ──< Goal (per crew, weekly frequency)
         Goal ──< GoalApproval (crew members vote to approve goals)
User ──< WorkoutLog (per crew, optionally linked to a Goal)
         WorkoutLog ──< WorkoutImage (stored as WebP in static/uploads/)
Notification (nudge | goal_request | goal_approved | join)
```

**Goal approval flow:** New goals start as `pending`. Each non-owner crew member must approve. `Goal.refresh_status()` flips to `approved` when all have voted (or immediately for 1-member crews).

## Key Conventions

- All timestamps stored as UTC in the DB; KST (UTC+9) used for display and weekly progress calculations. Use `kst_now()` and `week_range_kst()` helpers.
- Images are resized to max 1080×1080 and saved as WebP at 80% quality via `save_optimized_image()`.
- Flash messages and UI text are in Korean.
- `SECRET_KEY` should be set via environment variable in production (defaults to a dev value).
