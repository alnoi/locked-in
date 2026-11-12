package tracker_test

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func TestMigrationLifecycle(t *testing.T) {
	tests := []struct{ name string }{{"repeat_replay_down_and_up"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			parsed, err := pgxpool.ParseConfig(os.Getenv("TEST_DATABASE_URL"))
			if err != nil {
				t.Fatal(err)
			}
			parsed.ConnConfig.RuntimeParams["search_path"] = f.settings.Postgres.Schema
			pool, err := pgxpool.NewWithConfig(context.Background(), parsed)
			if err != nil {
				t.Fatal(err)
			}
			defer pool.Close()
			database := stdlib.OpenDBFromPool(pool)
			defer database.Close()
			provider, err := goose.NewProvider(goose.DialectPostgres, database, os.DirFS(f.settings.MigrationsPath))
			if err != nil {
				t.Fatal(err)
			}
			results, err := provider.Up(context.Background())
			if err != nil {
				t.Fatal(err)
			}
			if len(results) != 0 {
				t.Fatal("repeat changed schema")
			}
			paths, err := filepath.Glob(filepath.Join(f.settings.MigrationsPath, "*.sql"))
			if err != nil {
				t.Fatal(err)
			}
			for _, path := range paths {
				migration, err := os.ReadFile(path)
				if err != nil {
					t.Fatal(err)
				}
				up := strings.Split(strings.TrimPrefix(string(migration), "-- +goose Up"), "-- +goose Down")[0]
				if _, err := pool.Exec(context.Background(), up); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := provider.DownTo(context.Background(), 0); err != nil {
				t.Fatal(err)
			}

			applied, err := provider.Up(context.Background())
			if err != nil {
				t.Fatal(err)
			}
			if len(applied) != len(paths) {
				t.Fatalf("applied=%d want %d", len(applied), len(paths))
			}
		})
	}
}
