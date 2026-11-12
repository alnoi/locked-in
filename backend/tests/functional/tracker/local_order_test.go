package tracker_test

import "testing"

func TestListOrderRemovedFromAPI(t *testing.T) {
	tests := []struct{ name string }{{"local_presentation_only"}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			list := f.request(t, "POST", "/lists", map[string]any{"name": "List"}, 201)
			if _, exists := list["position"]; exists {
				t.Fatal("server still stores presentation order")
			}
			f.request(t, "POST", "/lists/"+list["id"].(string)+"/move", map[string]any{}, 404)
		})
	}
}
