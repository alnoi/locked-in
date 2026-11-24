package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateBugReportIn struct {
	ID             uuid.UUID
	OwnerID        *uuid.UUID
	Description    string
	Screenshot     []byte
	ScreenshotMime string
	Platform       string
	AppVersion     string
}
type BugReportReceipt struct {
	ID        uuid.UUID
	CreatedAt time.Time
}
type GetBugReportReceiptsFilters struct {
	ID      uuid.UUID
	OwnerID *uuid.UUID
}
