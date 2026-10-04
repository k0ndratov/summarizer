.PHONY: start stop logs shell test test-web test-downloader e2e

start:
	docker compose up --build

stop:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec web bash

test: test-web test-downloader e2e

test-web:
	docker compose exec web bin/rails test

test-downloader:
	docker compose exec downloader npm test

e2e:
	cd e2e && npx playwright test
