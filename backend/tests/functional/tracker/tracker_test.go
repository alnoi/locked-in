package tracker_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/alnoi/locked-in/backend/internal/app"
	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestTasks(t *testing.T) {
	tests := []struct {
		name string
		run  func(*testing.T, *fixture)
	}{
		{"minimal_and_patch", func(t *testing.T, f *fixture) {
			task := f.request(t, "POST", "/tasks", map[string]any{"title": "Inbox"}, 201)
			id := task["id"].(string)
			if _, exists := task["listID"]; exists {
				t.Fatal("minimal task unexpectedly has a list")
			}
			f.request(t, "PATCH", "/tasks/"+id, map[string]any{"durationMinutes": 45, "deadlineDate": "2026-11-20"}, 200)
			planned := f.request(t, "PATCH", "/tasks/"+id, map[string]any{"plannedAt": "2026-11-19T10:00:00+03:00"}, 200)
			if planned["durationMinutes"] != float64(45) || planned["deadlineDate"] != "2026-11-20" {
				t.Fatalf("task=%v", planned)
			}
			done := f.request(t, "POST", "/tasks/"+id+"/complete", nil, 200)
			if done["completed"] != true {
				t.Fatal("not completed")
			}
			open := f.request(t, "POST", "/tasks/"+id+"/reopen", nil, 200)
			if open["completed"] != false {
				t.Fatal("not reopened")
			}
			cleared := f.request(t, "PATCH", "/tasks/"+id, map[string]any{"clearDeadlineDate": true, "clearPlannedAt": true}, 200)
			if _, exists := cleared["deadlineDate"]; exists {
				t.Fatal("deadline not cleared")
			}
			if cleared["durationMinutes"] != float64(45) {
				t.Fatal("duration lost")
			}
			f.request(t, "DELETE", "/tasks/"+id, nil, 204)
			f.request(t, "GET", "/tasks/"+id, nil, 404)
			f.request(t, "PATCH", "/tasks/"+id, map[string]any{"title": "Revive"}, 404)
		}},
		{"project_depth", func(t *testing.T, f *fixture) {
			root := f.request(t, "POST", "/tasks", map[string]any{"title": "Project"}, 201)
			child := f.request(t, "POST", "/tasks", map[string]any{"title": "Step", "parentID": root["id"]}, 201)
			f.request(t, "POST", "/tasks", map[string]any{"title": "Too deep", "parentID": child["id"]}, 409)
			other := f.request(t, "POST", "/tasks", map[string]any{"title": "Other"}, 201)
			f.request(t, "PATCH", "/tasks/"+root["id"].(string), map[string]any{"parentID": other["id"]}, 409)
			f.request(t, "PATCH", "/tasks/"+root["id"].(string), map[string]any{"parentID": root["id"]}, 400)
			f.request(t, "DELETE", "/tasks/"+root["id"].(string), nil, 409)
			f.request(t, "PATCH", "/tasks/"+child["id"].(string), map[string]any{"clearParentID": true}, 200)
			f.request(t, "DELETE", "/tasks/"+root["id"].(string), nil, 204)
		}},
		{"calendar_overlap_and_offsets", func(t *testing.T, f *fixture) {
			for _, in := range []map[string]any{
				{"title": "Cross midnight", "plannedAt": "2026-11-10T23:30:00+03:00", "durationMinutes": 90},
				{"title": "Point", "plannedAt": "2026-11-11T00:00:00+03:00"},
				{"title": "Unscheduled", "durationMinutes": 60},
				{"title": "Next day", "plannedAt": "2026-11-12T00:00:00+03:00", "durationMinutes": 30},
			} {
				f.request(t, "POST", "/tasks", in, 201)
			}
			result := f.request(t, "GET", "/tasks?plannedFrom=2026-11-10T21:00:00Z&plannedTo=2026-11-11T21:00:00Z&limit=1", nil, 200)
			if result["total"] != float64(2) || len(result["items"].([]any)) != 1 {
				t.Fatalf("calendar=%v", result)
			}
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) { f := newFixture(t); tt.run(t, f) })
	}
}

func TestBoardsPreserveListGrouping(t *testing.T) {
	tests := []struct{ name string }{{"filtered_child_and_both_lists"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			board := f.request(t, "POST", "/boards", map[string]any{"name": "Работа"}, 201)
			first := f.request(t, "POST", "/lists", map[string]any{"name": "В планах", "boardID": board["id"]}, 201)
			second := f.request(t, "POST", "/lists", map[string]any{"name": "В работе", "boardID": board["id"]}, 201)
			tag := f.request(t, "POST", "/tags", map[string]any{"name": "backend"}, 201)
			child := f.request(t, "POST", "/boards", map[string]any{"name": "Backend", "parentID": board["id"], "tagIDs": []any{tag["id"]}}, 201)
			task := f.request(t, "POST", "/tasks", map[string]any{"title": "Первое", "listID": first["id"], "tagIDs": []any{tag["id"]}}, 201)
			f.request(t, "POST", "/tasks", map[string]any{"title": "Второе", "listID": second["id"], "tagIDs": []any{tag["id"]}}, 201)
			f.request(t, "POST", "/tasks", map[string]any{"title": "Без тега", "listID": first["id"]}, 201)
			result := f.request(t, "GET", "/tasks?boardID="+child["id"].(string), nil, 200)
			if result["total"] != float64(2) {
				t.Fatalf("tasks=%v", result)
			}
			result = f.request(t, "GET", "/lists?boardID="+child["id"].(string), nil, 200)
			if result["total"] != float64(2) {
				t.Fatalf("lists=%v", result)
			}
			ids := map[string]bool{}
			for _, item := range result["items"].([]any) {
				ids[item.(map[string]any)["id"].(string)] = true
			}
			if !ids[first["id"].(string)] || !ids[second["id"].(string)] {
				t.Fatal("lists were duplicated or lost")
			}
			f.request(t, "PATCH", "/tasks/"+task["id"].(string), map[string]any{"listID": second["id"]}, 200)
			result = f.request(t, "GET", "/tasks?boardID="+child["id"].(string)+"&listID="+second["id"].(string), nil, 200)
			if result["total"] != float64(2) {
				t.Fatal("move did not preserve filtered board membership")
			}
			f.request(t, "POST", "/lists", map[string]any{"name": "Wrong", "boardID": child["id"]}, 400)
			f.request(t, "PATCH", "/boards/"+board["id"].(string), map[string]any{"parentID": child["id"]}, 409)
			f.request(t, "DELETE", "/boards/"+board["id"].(string), nil, 409)
			other := f.otherUser(t, "other")
			other.request(t, "GET", "/boards/"+board["id"].(string), nil, 404)
			other.request(t, "GET", "/tasks?boardID="+child["id"].(string), nil, 404)
		})
	}
}

func TestValidation(t *testing.T) {
	f := newFixture(t)
	tests := []struct {
		name   string
		method string
		path   string
		body   any
		status int
	}{
		{"missing_title", "POST", "/tasks", map[string]any{}, 400},
		{"blank_title", "POST", "/tasks", map[string]any{"title": "  "}, 400},
		{"invalid_date", "POST", "/tasks", map[string]any{"title": "Bad", "deadlineDate": "2026-02-30"}, 400},
		{"two_deadlines", "POST", "/tasks", map[string]any{"title": "Bad", "deadlineDate": "2026-11-20", "deadlineAt": "2026-11-20T10:00:00Z"}, 400},
		{"zero_duration", "POST", "/tasks", map[string]any{"title": "Bad", "durationMinutes": 0}, 400},
		{"negative_duration", "POST", "/tasks", map[string]any{"title": "Bad", "durationMinutes": -1}, 400},
		{"oversize_duration", "POST", "/tasks", map[string]any{"title": "Bad", "durationMinutes": 2147483648}, 400},
		{"bad_color", "POST", "/tags", map[string]any{"name": "Bad", "color": "purple"}, 400},
		{"bad_uuid", "GET", "/tasks/nope", nil, 400},
		{"bad_limit", "GET", "/tasks?limit=0", nil, 400},
		{"inverted_interval", "GET", "/tasks?plannedFrom=2026-11-20T00:00:00Z&plannedTo=2026-11-19T00:00:00Z", nil, 400},
		{"null_field", "POST", "/tasks", map[string]any{"title": "Test", "listID": nil}, 400},
		{"unknown_field", "POST", "/tasks", map[string]any{"title": "No", "ownerID": uuid.NewString()}, 400},
		{"root_filter", "POST", "/lists", map[string]any{"name": "Wrong", "filterCompleted": true}, 400},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			response := f.request(t, tt.method, tt.path, tt.body, tt.status)
			if response["message"] == nil || response["code"] == nil {
				t.Fatalf("missing safe error: %v", response)
			}
		})
	}
}

func TestCommentsAndIsolation(t *testing.T) {
	tests := []struct{ name string }{{"owner_scope_and_deleted_parent"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			other := f.otherUser(t, "second")
			task := f.request(t, "POST", "/tasks", map[string]any{"title": "Private"}, 201)
			taskID := task["id"].(string)
			comment := f.request(t, "POST", "/comments", map[string]any{"taskID": taskID, "text": "A note"}, 201)
			commentID := comment["id"].(string)
			other.request(t, "GET", "/tasks/"+taskID, nil, 404)
			other.request(t, "PATCH", "/tasks/"+taskID, map[string]any{"title": "Leak"}, 404)
			other.request(t, "POST", "/comments", map[string]any{"taskID": taskID, "text": "Leak"}, 404)
			other.request(t, "GET", "/comments/"+commentID, nil, 404)
			result := other.request(t, "GET", "/tasks", nil, 200)
			if result["total"] != float64(0) {
				t.Fatal("owner data leaked")
			}
			f.request(t, "PATCH", "/comments/"+commentID, map[string]any{"text": "Updated"}, 200)
			f.request(t, "DELETE", "/tasks/"+taskID, nil, 204)
			f.request(t, "GET", "/comments/"+commentID, nil, 404)
			f.request(t, "PATCH", "/comments/"+commentID, map[string]any{"text": "After delete"}, 404)
		})
	}
}

func TestConcurrentHierarchyChanges(t *testing.T) {
	tests := []struct{ name string }{{"cannot_create_cycle"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			first := f.request(t, "POST", "/tasks", map[string]any{"title": "First"}, 201)["id"].(string)
			second := f.request(t, "POST", "/tasks", map[string]any{"title": "Second"}, 201)["id"].(string)
			var wait sync.WaitGroup
			statuses := make(chan int, 2)
			for _, pair := range [][2]string{{first, second}, {second, first}} {
				wait.Add(1)
				go func(pair [2]string) {
					defer wait.Done()
					body, _ := json.Marshal(map[string]any{"parentID": pair[1]})
					request, err := http.NewRequestWithContext(context.Background(), "PATCH", f.server.URL+"/api/v1/tasks/"+pair[0], bytes.NewReader(body))
					if err != nil {
						statuses <- 0
						return
					}
					request.Header.Set("Content-Type", "application/json")
					response, err := f.server.Client().Do(request)
					if err != nil {
						statuses <- 0
						return
					}
					defer response.Body.Close()
					statuses <- response.StatusCode
				}(pair)
			}
			wait.Wait()
			close(statuses)
			success, conflict := 0, 0
			for status := range statuses {
				if status == 200 {
					success++
				}
				if status == 409 {
					conflict++
				}
			}
			if success != 1 || conflict != 1 {
				t.Fatalf("success=%d conflict=%d", success, conflict)
			}
		})
	}
}

type fixture struct {
	server   *httptest.Server
	settings config.Config
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("TEST_DATABASE_URL is required")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	schema := "locked_in_test_" + uuid.New().String()[:8]
	quoted := pgx.Identifier{schema}.Sanitize()
	if _, err := pool.Exec(ctx, "CREATE SCHEMA "+quoted); err != nil {
		pool.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if _, err := pool.Exec(ctx, "DROP SCHEMA "+quoted+" CASCADE"); err != nil {
			t.Error(err)
		}
		pool.Close()
	})
	parsed, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	settings := config.Config{
		Server:    config.Server{Address: "127.0.0.1:0", RequestTimeout: 5 * time.Second, ShutdownTimeout: 5 * time.Second, MaxBodyBytes: 1 << 20},
		Postgres:  config.Postgres{Host: parsed.ConnConfig.Host, Port: parsed.ConnConfig.Port, Database: parsed.ConnConfig.Database, User: parsed.ConnConfig.User, Password: parsed.ConnConfig.Password, Schema: schema, SSLMode: "disable", MaxConns: 5, MinConns: 0, MaxConnLifetime: time.Minute, MaxConnIdleTime: time.Minute, ConnectTimeout: 5 * time.Second},
		LocalUser: config.LocalUser{Username: "local", TimeZone: "Europe/Moscow"}, MigrationsPath: filepath.Join("..", "..", "..", "migrations"), LogLevel: "error",
	}
	return startFixture(t, settings)
}
func startFixture(t *testing.T, settings config.Config) *fixture {
	t.Helper()
	application, err := app.New(context.Background(), settings)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(application.Handler())
	t.Cleanup(func() { server.Close(); application.Close() })
	return &fixture{server: server, settings: settings}
}
func (f *fixture) otherUser(t *testing.T, name string) *fixture {
	t.Helper()
	settings := f.settings
	settings.LocalUser.Username = name
	return startFixture(t, settings)
}
func (f *fixture) request(t *testing.T, method, path string, body any, status int) map[string]any {
	t.Helper()
	var encoded []byte
	var err error
	if body != nil {
		encoded, err = json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
	}
	request, err := http.NewRequestWithContext(context.Background(), method, f.server.URL+"/api/v1"+path, bytes.NewReader(encoded))
	if err != nil {
		t.Fatal(err)
	}
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
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
		t.Fatalf("%s %s: got %d want %d: %s", method, path, response.StatusCode, status, data)
	}
	result := map[string]any{}
	if len(data) > 0 {
		if err := json.Unmarshal(data, &result); err != nil {
			t.Fatal(fmt.Errorf("decode response: %w", err))
		}
	}
	return result
}
