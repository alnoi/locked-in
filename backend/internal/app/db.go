package app

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"strconv"

	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func openDatabase(ctx context.Context, settings config.Postgres) (*pgxpool.Pool, error) {
	address := url.URL{Scheme: "postgres", Host: net.JoinHostPort(settings.Host, strconv.Itoa(int(settings.Port))), Path: "/" + settings.Database, User: url.UserPassword(settings.User, settings.Password)}
	parameters := url.Values{}
	parameters.Set("sslmode", settings.SSLMode)
	address.RawQuery = parameters.Encode()
	parsed, err := pgxpool.ParseConfig(address.String())
	if err != nil {
		return nil, fmt.Errorf("openDatabase: invalid connection settings")
	}
	parsed.ConnConfig.RuntimeParams["search_path"] = pgx.Identifier{settings.Schema}.Sanitize()
	parsed.MaxConns = settings.MaxConns
	parsed.MinConns = settings.MinConns
	parsed.MaxConnLifetime = settings.MaxConnLifetime
	parsed.MaxConnIdleTime = settings.MaxConnIdleTime
	parsed.ConnConfig.ConnectTimeout = settings.ConnectTimeout
	pool, err := pgxpool.NewWithConfig(ctx, parsed)
	if err != nil {
		return nil, fmt.Errorf("openDatabase: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("openDatabase: %w", err)
	}
	return pool, nil
}
