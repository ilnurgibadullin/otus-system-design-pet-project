# syntax=docker/dockerfile:1
FROM python:3.11-slim as base
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_VENV_IN_PROJECT=1

# Установка Poetry
RUN pip install poetry==1.5.1

# Копирование зависимостей
COPY pyproject.toml poetry.lock* ./
RUN poetry export -f requirements.txt --without-hashes -o requirements.txt

# Builder stage
FROM base as builder
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM base as production
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Копирование установленных зависимостей
COPY --from=builder /root/.local /root/.local

# Копирование приложения
COPY . .

# Создание пользователя
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["python", "src/main.py"]

# Test stage
FROM base as test
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install pytest pytest-cov

COPY . .

CMD ["pytest", "--cov=src", "--cov-report=xml", "--junitxml=test-results/results.xml"]