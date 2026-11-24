package local

import (
	identity "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/gin-gonic/gin"
)

type Handlers struct {
	usecase trackerUseCase
	actor   func(*gin.Context) identity.Actor
}

func New(usecase trackerUseCase, actor func(*gin.Context) identity.Actor) *Handlers {
	return &Handlers{usecase: usecase, actor: actor}
}
