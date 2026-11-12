package tracker_test

import "testing"

func TestDataSurvivesRestart(t *testing.T) {
	tests := []struct{ name string }{{"same_local_user_and_tasks"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			first := newFixture(t)
			user := first.request(t, "GET", "/me", nil, 200)
			task := first.request(t, "POST", "/tasks", map[string]any{"title": "Persistent"}, 201)
			second := startFixture(t, first.settings)
			restoredUser := second.request(t, "GET", "/me", nil, 200)
			if restoredUser["id"] != user["id"] {
				t.Fatal("local user was duplicated")
			}
			restoredTask := second.request(t, "GET", "/tasks/"+task["id"].(string), nil, 200)
			if restoredTask["title"] != "Persistent" {
				t.Fatal("task was not persisted")
			}
		})
	}
}
