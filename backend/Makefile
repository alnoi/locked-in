-include .env
export

.PHONY: run build fmt lint unit-test integration-tests up gen-oapi
run:
	go run ./cmd/locked_in
build:
	go build -o bin/locked_in ./cmd/locked_in
fmt:
	golangci-lint fmt
	npm run fmt:sql
lint:
	golangci-lint run
	npm run lint:sql
unit-test:
	go test ./internal/... -short -count=1
integration-tests:
	go test ./tests/functional/... -p 1 -count=1 -timeout 3m
up:
	docker compose up -d --wait
gen-oapi:
	go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.6.0 --config api/oapi.cfg.yaml api/service/local_tracker/openapi.yaml
