package tracker_test

import (
	"context"
	"os"
	"testing"
	"testing/fstest"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func TestLegacyMigrationUpgrade(t *testing.T) {
	tests := []struct{ name string }{{"original_version_one_preserves_data"}}
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
			if _, err := provider.DownTo(context.Background(), 0); err != nil {
				t.Fatal(err)
			}
			original, err := os.ReadFile("testdata/00001_init.sql")
			if err != nil {
				t.Fatal(err)
			}
			legacy, err := goose.NewProvider(goose.DialectPostgres, database, fstest.MapFS{"00001_init.sql": &fstest.MapFile{Data: original}})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := legacy.Up(context.Background()); err != nil {
				t.Fatal(err)
			}
			if _, err := pool.Exec(context.Background(), "INSERT INTO users(username,time_zone) VALUES('legacy','UTC'); INSERT INTO tasks(owner_id,title) SELECT id,'Keep this task' FROM users WHERE username='legacy'"); err != nil {
				t.Fatal(err)
			}
			if _, err := pool.Exec(context.Background(), `INSERT INTO lists(owner_id,name) SELECT id,'Первый старый список' FROM users WHERE username='legacy';
INSERT INTO lists(owner_id,name) SELECT id,'Второй старый список' FROM users WHERE username='legacy';
INSERT INTO tags(owner_id,name) SELECT id,'старый тег' FROM users WHERE username='legacy';
INSERT INTO lists(owner_id,name,parent_id) SELECT owner_id,'Старый фильтр',id FROM lists WHERE name='Первый старый список';
INSERT INTO list_tags(owner_id,list_id,tag_id) SELECT list.owner_id,list.id,tag.id FROM lists list JOIN tags tag ON tag.owner_id=list.owner_id WHERE list.name='Старый фильтр';
INSERT INTO tasks(owner_id,title,list_id) SELECT owner_id,'Задача ' || name,id FROM lists WHERE parent_id IS NULL;
INSERT INTO task_tags(owner_id,task_id,tag_id) SELECT task.owner_id,task.id,tag.id FROM tasks task JOIN tags tag ON tag.owner_id=task.owner_id WHERE task.list_id IS NOT NULL;`); err != nil {
				t.Fatal(err)
			}
			applied, err := provider.Up(context.Background())
			if err != nil {
				t.Fatal(err)
			}
			if len(applied) != 13 {
				t.Fatalf("applied=%d want 13", len(applied))
			}
			settings := f.settings
			settings.LocalUser.Username = "legacy"
			upgraded := startFixture(t, settings)
			result := upgraded.request(t, "GET", "/tasks", nil, 200)
			items := result["items"].([]any)
			if result["total"] != float64(3) || len(items) != 3 {
				t.Fatalf("lost legacy data: %v", result)
			}
			boards := upgraded.request(t, "GET", "/boards", nil, 200)
			var childID string
			for _, entry := range boards["items"].([]any) {
				board := entry.(map[string]any)
				if board["name"] == "Старый фильтр" {
					childID = board["id"].(string)
				}
			}
			if childID == "" {
				t.Fatal("legacy filter not migrated")
			}
			inherited := upgraded.request(t, "GET", "/lists?boardID="+childID, nil, 200)
			if inherited["total"] != float64(2) {
				t.Fatalf("legacy lists lost: %v", inherited)
			}
			selected := upgraded.request(t, "GET", "/tasks?boardID="+childID, nil, 200)
			if selected["total"] != float64(2) {
				t.Fatalf("legacy tags lost: %v", selected)
			}
		})
	}
}
