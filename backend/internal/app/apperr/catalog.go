package apperr

var publicErrors = map[ErrorCode]Error{
	CodeInvalidAttachment:  {CodeInvalidAttachment, 400, "Choose a valid PNG or JPEG screenshot."},
	CodeValidation:         {CodeValidation, 400, "Check the request fields and try again."},
	CodeNotFound:           {CodeNotFound, 404, "The requested item is no longer available."},
	CodeConflict:           {CodeConflict, 409, "This operation conflicts with related items. Refresh and try again."},
	CodeInternal:           {CodeInternal, 500, "Internal error. Please contact support."},
	CodeUnauthorized:       {CodeUnauthorized, 401, "Your session has expired. Please sign in again."},
	CodeRateLimited:        {CodeRateLimited, 429, "Too many attempts. Please wait and try again."},
	CodeInvalidCredentials: {CodeInvalidCredentials, 401, "Incorrect username or password."},
	CodeUsernameTaken:      {CodeUsernameTaken, 409, "This username is already taken."},
	CodeInvalidUsername:    {CodeInvalidUsername, 400, "Username must contain 3 to 32 Latin letters, numbers, underscores, dots or hyphens."},
	CodeInvalidPassword:    {CodeInvalidPassword, 400, "Password must contain at least 8 characters and no more than 256 bytes."},
	CodeInvalidAvatar:      {CodeInvalidAvatar, 400, "Select a valid avatar or leave it empty."},
	CodeInvalidTimeZone:    {CodeInvalidTimeZone, 400, "Select a valid time zone."},
	CodeForbidden:          {CodeForbidden, 403, "You do not have access to this action."},
	CodeMethodNotAllowed:   {CodeMethodNotAllowed, 405, "This action is not supported."},
	CodeUnavailable:        {CodeUnavailable, 503, "No connection with server. Please try again later."},
}

func publicError(code ErrorCode) *Error {
	value, exists := publicErrors[code]
	if !exists {
		return nil
	}
	return &value
}
