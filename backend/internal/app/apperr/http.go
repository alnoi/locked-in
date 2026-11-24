package apperr

import (
	"errors"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func WriteError(c *gin.Context, err error) {
	var expected *Error
	if errors.As(err, &expected) && expected != nil {
		if safe := publicError(expected.Code); safe != nil {
			c.AbortWithStatusJSON(safe.Status, gin.H{"code": safe.Code, "message": safe.Message})
			return
		}
	}
	if value, ok := c.Get("logger"); ok {
		if logger, ok := value.(*zap.Logger); ok {
			logger.Error("request failed", zap.Error(err))
		}
	}
	safe := ErrInternal()
	c.AbortWithStatusJSON(safe.Status, gin.H{"code": safe.Code, "message": safe.Message})
}
