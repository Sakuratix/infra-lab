.PHONY: test lint up down tf-check helm-check
test:      ; cd app && python -m pytest -q
lint:      ; ruff check . && ruff format --check .
up:        ; docker compose up -d --build
down:      ; docker compose down -v
tf-check:  ; cd terraform && terraform fmt -check && terraform init -backend=false && terraform validate
helm-check:; helm lint helm/app && helm template demo helm/app > /dev/null
