# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS test
WORKDIR /src
RUN pip install --no-cache-dir pytest==8.3.3
COPY . .
RUN pytest -q

FROM python:3.12-slim
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN useradd --uid 10001 --no-create-home app
WORKDIR /app
COPY --from=test /src/app.py .
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz').status==200 else 1)"
ENTRYPOINT ["python", "app.py"]
