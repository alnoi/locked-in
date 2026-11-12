package tracker_test

import "testing"

func TestCollectionQueries(t *testing.T) {
	f := newFixture(t)
	for _, title := range []string{"Alpha", "Beta"} {
		f.request(t, "POST", "/tasks", map[string]any{"title": title}, 201)
	}
	tests := []struct {
		name   string
		query  string
		status int
		total  float64
		length int
		first  string
	}{
		{"descending", "?sortBy=title&sortDesc=1", 200, 2, 2, "Beta"},
		{"pagination_total", "?sortBy=title&limit=1&offset=1", 200, 2, 1, "Beta"},
		{"offset_without_limit", "?sortBy=title&offset=1", 200, 2, 2, "Alpha"},
		{"created_range", "?createdAtTo=2000-01-01T00:00:00Z", 200, 0, 0, ""},
		{"bad_sort", "?sortBy=owner_id", 400, 0, 0, ""},
		{"bad_direction", "?sortDesc=2", 400, 0, 0, ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out := f.request(t, "GET", "/tasks"+tt.query, nil, tt.status)
			if tt.status != 200 {
				return
			}
			items := out["items"].([]any)
			if out["total"] != tt.total || len(items) != tt.length {
				t.Fatalf("out=%v", out)
			}
			if tt.first != "" && items[0].(map[string]any)["title"] != tt.first {
				t.Fatalf("order=%v", items)
			}
		})
	}
}
