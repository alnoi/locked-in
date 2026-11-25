package apperr

type ErrorCode string

const (
	CodeInvalidAttachment  ErrorCode = "invalid_attachment"
	CodeInvalidCredentials ErrorCode = "invalid_credentials"
	CodeUserNotFound       ErrorCode = "user_not_found"
	CodeWrongPassword      ErrorCode = "wrong_password"
	CodeUsernameTaken      ErrorCode = "username_taken"
	CodeInvalidUsername    ErrorCode = "invalid_username"
	CodeInvalidPassword    ErrorCode = "invalid_password"
	CodeInvalidAvatar      ErrorCode = "invalid_avatar"
	CodeInvalidTimeZone    ErrorCode = "invalid_time_zone"
	CodeForbidden          ErrorCode = "forbidden"
	CodeMethodNotAllowed   ErrorCode = "method_not_allowed"
	CodeUnavailable        ErrorCode = "server_unavailable"
	CodeRateLimited        ErrorCode = "rate_limited"
	CodeValidation         ErrorCode = "validation_error"
	CodeNotFound           ErrorCode = "not_found"
	CodeConflict           ErrorCode = "conflict"
	CodeInternal           ErrorCode = "internal_error"
	CodeUnauthorized       ErrorCode = "unauthorized"
)
