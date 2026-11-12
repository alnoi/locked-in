package apperr

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func WriteError(c *gin.Context, err error) {
	var expected *Error
	if errors.As(err, &expected) {
		c.AbortWithStatusJSON(expected.Status, gin.H{"code": expected.Code, "message": expected.Message})
		return
	}
	if value, ok := c.Get("logger"); ok {
		if logger, ok := value.(*zap.Logger); ok {
			logger.Error("request failed", zap.Error(err))
		}
	}
	c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"code": CodeInternal, "message": "Internal server error"})
}
