package tracker_test

import (
	"testing"

	"github.com/google/uuid"
)

func TestOfflineTaskCreateReplay(t *testing.T) {
	tests := []struct {
		name      string
		completed bool
	}{
		{name: "open"}, {name: "completed", completed: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			id := uuid.NewString()
			body := map[string]any{"id": id, "title": "Offline task"}
			first := f.request(t, "POST", "/tasks", body, 201)
			if first["id"] != id {
				t.Fatal("client ID was not retained")
			}
			f.request(t, "PATCH", "/tasks/"+id, map[string]any{"title": "Edited later"}, 200)
			if tt.completed {
				f.request(t, "POST", "/tasks/"+id+"/complete", nil, 200)
			}
			replay := f.request(t, "POST", "/tasks", body, 201)
			if replay["id"] != id || replay["title"] != "Edited later" || replay["completed"] != tt.completed {
				t.Fatalf("replay changed an existing task: %v", replay)
			}
			collection := f.request(t, "GET", "/tasks", nil, 200)
			other := f.otherUser(t, "other_sync_user")
			other.request(t, "POST", "/tasks", body, 409)
			if collection["total"] != float64(1) {
				t.Fatal("replay created a duplicate")
			}
			f.request(t, "POST", "/tasks", map[string]any{"id": uuid.Nil.String(), "title": "Invalid"}, 400)
		})
	}
}
