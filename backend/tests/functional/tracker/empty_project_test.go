package tracker_test

import "testing"

func TestEmptyProjectLifecycle(t *testing.T) {
	f := newFixture(t)
	task := f.request(t, "POST", "/tasks", map[string]any{"title": "Empty project"}, 201)
	id := task["id"].(string)
	converted := f.request(t, "PATCH", "/tasks/"+id, map[string]any{"isProject": true}, 200)
	if converted["isProject"] != true {
		t.Fatalf("converted=%v", converted)
	}
	loaded := f.request(t, "GET", "/tasks/"+id, nil, 200)
	if loaded["isProject"] != true {
		t.Fatalf("loaded=%v", loaded)
	}
	child := f.request(t, "POST", "/tasks", map[string]any{"title": "Child", "parentID": id}, 201)
	childID := child["id"].(string)
	f.request(t, "PATCH", "/tasks/"+childID, map[string]any{"isProject": true}, 409)
	f.request(t, "PATCH", "/tasks/"+childID, map[string]any{"clearParentID": true}, 200)
	f.request(t, "PATCH", "/tasks/"+id, map[string]any{"isProject": false}, 200)
	loaded = f.request(t, "GET", "/tasks/"+id, nil, 200)
	if loaded["isProject"] != false {
		t.Fatalf("dissolved=%v", loaded)
	}
}
