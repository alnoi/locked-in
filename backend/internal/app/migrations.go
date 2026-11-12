package app

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/pressly/goose/v3/lock"
)

func migrate(ctx context.Context, pool *pgxpool.Pool, path string) (result error) {
	database := stdlib.OpenDBFromPool(pool)
	defer func() {
		if err := database.Close(); err != nil {
			result = fmt.Errorf("migrate: %w", err)
		}
	}()
	locker, err := lock.NewPostgresSessionLocker()
	if err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	provider, err := goose.NewProvider(goose.DialectPostgres, database, os.DirFS(path), goose.WithSessionLocker(locker))
	if err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	if _, err := provider.Up(ctx); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	return nil
}
