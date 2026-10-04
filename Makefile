.PHONY: start stop logs shell test test-web test-downloader e2e up-fake

# Containers run as this user so files on the bind mounts stay yours.
export UID := $(shell id -u)
export GID := $(shell id -g)

# Run the app with real APIs (needs OPENAI_API_KEY / ANTHROPIC_API_KEY in .env).
start:
	docker compose up --build

stop:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec web bash

# All test layers. Restarts the stack with FAKE_SERVICES=true: no external API calls.
test: up-fake test-web test-downloader e2e

up-fake:
	FAKE_SERVICES=true docker compose up --build -d --wait

test-web:
	docker compose exec web bin/rails test

test-downloader:
	docker compose exec downloader npm test

e2e: e2e/node_modules
	cd e2e && npx playwright test

e2e/node_modules: e2e/package.json
	cd e2e && npm install && npx playwright install chromium --only-shell
