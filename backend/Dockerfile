# syntax=docker/dockerfile:1
FROM golang:1.27.4-alpine3.24 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.6.0 --config api/oapi.cfg.yaml api/service/local_tracker/openapi.yaml \
    && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/trackit ./cmd/locked_in

FROM alpine:3.24
RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -g 1001 trackit \
    && adduser -D -H -u 1001 -G trackit trackit
WORKDIR /srv/trackit
COPY --from=builder /out/trackit /usr/local/bin/trackit
COPY migrations ./migrations
USER 1001:1001
ENTRYPOINT ["/usr/local/bin/trackit"]
