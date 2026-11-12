package models

type EnsureLocalUserIn struct {
	Username string
	TimeZone string
}
type GetUsersFilters struct{ Username string }
