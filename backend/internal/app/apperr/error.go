package apperr

type Error struct {
	Code    ErrorCode
	Status  int
	Message string
}

func (e *Error) Error() string      { return string(e.Code) }
func ErrValidation() *Error         { return publicError(CodeValidation) }
func ErrNotFound() *Error           { return publicError(CodeNotFound) }
func ErrConflict() *Error           { return publicError(CodeConflict) }
func ErrUnauthorized() *Error       { return publicError(CodeUnauthorized) }
func ErrInternal() *Error           { return publicError(CodeInternal) }
func ErrRateLimited() *Error        { return publicError(CodeRateLimited) }
func ErrInvalidCredentials() *Error { return publicError(CodeInvalidCredentials) }
func ErrUsernameTaken() *Error      { return publicError(CodeUsernameTaken) }
func ErrInvalidUsername() *Error    { return publicError(CodeInvalidUsername) }
func ErrInvalidPassword() *Error    { return publicError(CodeInvalidPassword) }
func ErrInvalidAvatar() *Error      { return publicError(CodeInvalidAvatar) }
func ErrInvalidTimeZone() *Error    { return publicError(CodeInvalidTimeZone) }
func ErrForbidden() *Error          { return publicError(CodeForbidden) }
func ErrMethodNotAllowed() *Error   { return publicError(CodeMethodNotAllowed) }
func ErrUnavailable() *Error        { return publicError(CodeUnavailable) }

func ErrInvalidAttachment() *Error { return publicError(CodeInvalidAttachment) }
