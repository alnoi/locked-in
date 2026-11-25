package tracker_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func TestTaskOrder(t *testing.T) {
	tests := []struct {
		name string
		run  func(*testing.T, *fixture)
	}{
		{"new_migration_replay_down_up", func(t *testing.T, f *fixture) {
			config, err := pgxpool.ParseConfig(os.Getenv("TEST_DATABASE_URL"))
			if err != nil {
				t.Fatal(err)
			}
			config.ConnConfig.RuntimeParams["search_path"] = f.settings.Postgres.Schema
			database := stdlib.OpenDB(*config.ConnConfig)
			defer database.Close()
			provider, err := goose.NewProvider(goose.DialectPostgres, database, os.DirFS(f.settings.MigrationsPath))
			if err != nil {
				t.Fatal(err)
			}
			if _, err := provider.DownTo(context.Background(), 18); err != nil {
				t.Fatal(err)
			}
			if _, err := provider.Up(context.Background()); err != nil {
				t.Fatal(err)
			}
			migration, err := os.ReadFile(filepath.Join(f.settings.MigrationsPath, "00019_create_task_orders.sql"))
			if err != nil {
				t.Fatal(err)
			}
			up := strings.Split(strings.TrimPrefix(string(migration), "-- +goose Up"), "-- +goose Down")[0]
			for range 2 {
				if _, err := database.ExecContext(context.Background(), up); err != nil {
					t.Fatal(err)
				}
			}
		}},
		{"sync_and_restart", func(t *testing.T, f *fixture) {
			token := taskOrderAccount(t, f, "order_owner")
			ids := taskOrderTasks(t, f, token, 3)
			expected := []string{ids[2], ids[0], ids[1]}
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": expected}, 200)
			login := f.request(t, "POST", "/auth/login", map[string]any{"username": "order_owner", "password": "task-order-password"}, 200)
			taskOrderAssert(t, taskOrderRequest(t, f, login["accessToken"].(string), "GET", "/task-order", nil, 200), expected)
			restarted := startFixture(t, f.settings)
			taskOrderAssert(t, taskOrderRequest(t, restarted, token, "GET", "/task-order", nil, 200), expected)
		}},
		{"partial_order_preserves_hidden_and_new_tasks", func(t *testing.T, f *fixture) {
			token := taskOrderAccount(t, f, "order_partial")
			ids := taskOrderTasks(t, f, token, 5)
			selected := []string{ids[3], ids[1]}
			expected := []string{ids[0], ids[3], ids[2], ids[1], ids[4]}
			taskOrderAssert(t, taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": selected}, 200), expected)
			added := taskOrderTasks(t, f, token, 1)[0]
			expected = append(expected, added)
			taskOrderAssert(t, taskOrderRequest(t, f, token, "GET", "/task-order", nil, 200), expected)
			taskOrderRequest(t, f, token, "DELETE", "/tasks/"+ids[2], nil, 204)
			expected = []string{ids[0], ids[3], ids[1], ids[4], added}
			taskOrderAssert(t, taskOrderRequest(t, f, token, "GET", "/task-order", nil, 200), expected)
		}},
		{"initial_import_does_not_overwrite_synced_order", func(t *testing.T, f *fixture) {
			token := taskOrderAccount(t, f, "order_initial")
			ids := taskOrderTasks(t, f, token, 3)
			expected := []string{ids[2], ids[1], ids[0]}
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": expected, "initializeOnly": true}, 200)
			taskOrderAssert(t, taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": ids, "initializeOnly": true}, 200), expected)
		}},
		{"validation_and_owner_isolation", func(t *testing.T, f *fixture) {
			token := taskOrderAccount(t, f, "order_private")
			other := taskOrderAccount(t, f, "order_other")
			ids := taskOrderTasks(t, f, token, 2)
			foreign := taskOrderTasks(t, f, other, 1)[0]
			taskOrderRequest(t, f, "", "GET", "/task-order", nil, 401)
			taskOrderRequest(t, f, "", "PUT", "/task-order", map[string]any{"taskIDs": ids}, 401)
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": []string{ids[0], foreign}}, 404)
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": []string{ids[0], ids[0]}}, 400)
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": []string{uuid.Nil.String()}}, 400)
			taskOrderRequest(t, f, token, "PUT", "/task-order", map[string]any{"taskIDs": nil}, 400)
			taskOrderAssert(t, taskOrderRequest(t, f, token, "GET", "/task-order", nil, 200), ids)
			taskOrderAssert(t, taskOrderRequest(t, f, other, "GET", "/task-order", nil, 200), []string{foreign})
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) { tt.run(t, newFixture(t)) })
	}
}
func taskOrderAccount(t *testing.T, f *fixture, name string) string {
	t.Helper()
	return f.request(t, "POST", "/auth/register", map[string]any{"username": name, "password": "task-order-password", "timeZone": "UTC"}, 201)["accessToken"].(string)
}
func taskOrderTasks(t *testing.T, f *fixture, token string, count int) []string {
	t.Helper()
	ids := make([]string, 0, count)
	for range count {
		ids = append(ids, taskOrderRequest(t, f, token, "POST", "/tasks", map[string]any{"title": "Task"}, 201)["id"].(string))
	}
	return ids
}
func taskOrderAssert(t *testing.T, value map[string]any, expected []string) {
	t.Helper()
	actual := make([]string, 0)
	for _, id := range value["taskIDs"].([]any) {
		actual = append(actual, id.(string))
	}
	if !reflect.DeepEqual(actual, expected) {
		t.Fatalf("order=%v want %v", actual, expected)
	}
}
func taskOrderRequest(t *testing.T, f *fixture, token, method, path string, body any, status int) map[string]any {
	t.Helper()
	encoded, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	request, err := http.NewRequestWithContext(context.Background(), method, f.server.URL+"/api/v1"+path, bytes.NewReader(encoded))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/json")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	response, err := f.server.Client().Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	data, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != status {
		t.Fatalf("%s %s: %d want %d: %s", method, path, response.StatusCode, status, data)
	}
	result := map[string]any{}
	if len(data) > 0 {
		if err := json.Unmarshal(data, &result); err != nil {
			t.Fatal(err)
		}
	}
	return result
}
