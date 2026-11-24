package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/feedback/models"
	identitymodels "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/google/uuid"
)

type AuthorizedUseCase struct{ core *UseCase }

func NewAuthorized(core *UseCase) *AuthorizedUseCase { return &AuthorizedUseCase{core: core} }
func (u *AuthorizedUseCase) CreateBugReport(ctx context.Context, actor identitymodels.Actor, in *models.CreateBugReportIn) (models.BugReportReceipt, error) {
	in.OwnerID = nil
	if actor.UserID != uuid.Nil {
		in.OwnerID = actor.Scope()
	}
	return u.core.CreateBugReport(ctx, in)
}
