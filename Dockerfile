FROM node:20-slim AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM python:3.12-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY migrations/ ./migrations/
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

RUN mkdir -p static/uploads

EXPOSE 4010

CMD ["gunicorn", "--bind", "0.0.0.0:4010", "--workers", "2", "--timeout", "60", "app:app"]
