package apperr

type Error struct {
	Code    ErrorCode
	Status  int
	Message string
}

func (e *Error) Error() string { return string(e.Code) }
func ErrValidation() *Error    { return &Error{CodeValidation, 400, "Invalid request"} }
func ErrNotFound() *Error      { return &Error{CodeNotFound, 404, "Resource not found"} }
func ErrConflict() *Error      { return &Error{CodeConflict, 409, "Operation conflicts with existing data"} }
func ErrUnauthorized() *Error  { return &Error{CodeUnauthorized, 401, "Local access required"} }

func ErrInternal() *Error { return &Error{CodeInternal, 500, "Internal server error"} }
