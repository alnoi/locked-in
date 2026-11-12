package apperr

type ErrorCode string

const (
	CodeValidation   ErrorCode = "validation_error"
	CodeNotFound     ErrorCode = "not_found"
	CodeConflict     ErrorCode = "conflict"
	CodeInternal     ErrorCode = "internal_error"
	CodeUnauthorized ErrorCode = "unauthorized"
)
