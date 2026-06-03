FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY static/ static/
COPY templates/ templates/

RUN mkdir -p static/uploads

EXPOSE 4010

CMD ["gunicorn", "--bind", "0.0.0.0:4010", "--workers", "2", "--timeout", "60", "app:app"]
