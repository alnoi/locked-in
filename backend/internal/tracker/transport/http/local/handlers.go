package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	identity "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/gin-gonic/gin"
)

type Handlers struct {
	usecase trackerUseCase
	user    identity.User
}

func New(usecase trackerUseCase, user identity.User) *Handlers {
	return &Handlers{usecase: usecase, user: user}
}
func (h *Handlers) actor() identity.Actor { return identity.Actor{UserID: h.user.ID} }
func (h *Handlers) GetMe(c *gin.Context) {
	c.JSON(200, tracker_genapi.UserOut{Id: h.user.ID, Username: h.user.Username, TimeZone: h.user.TimeZone, CreatedAt: h.user.CreatedAt})
}
