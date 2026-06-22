/**
 * Custom error classes for consistent API error handling
 */

export class AppError extends Error {
    public readonly statusCode: number;
    public readonly isOperational: boolean;
    public readonly code: string;

    constructor(
        message: string,
        statusCode: number = 500,
        code: string = 'INTERNAL_ERROR',
        isOperational: boolean = true
    ) {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.isOperational = isOperational;

        Error.captureStackTrace(this, this.constructor);
    }
}

export class BadRequestError extends AppError {
    constructor(message: string = 'Bad request', code: string = 'BAD_REQUEST') {
        super(message, 400, code);
    }
}

export class UnauthorizedError extends AppError {
    constructor(message: string = 'Unauthorized', code: string = 'UNAUTHORIZED') {
        super(message, 401, code);
    }
}

export class ForbiddenError extends AppError {
    constructor(message: string = 'Forbidden', code: string = 'FORBIDDEN') {
        super(message, 403, code);
    }
}

export class NotFoundError extends AppError {
    constructor(message: string = 'Resource not found', code: string = 'NOT_FOUND') {
        super(message, 404, code);
    }
}

export class ConflictError extends AppError {
    constructor(message: string = 'Resource conflict', code: string = 'CONFLICT') {
        super(message, 409, code);
    }
}

export class TooManyRequestsError extends AppError {
    constructor(message: string = 'Too many requests', code: string = 'TOO_MANY_REQUESTS') {
        super(message, 429, code);
    }
}

export class ValidationError extends AppError {
    public readonly errors: Record<string, string[]>;

    constructor(errors: Record<string, string[]>, message: string = 'Validation failed') {
        super(message, 422, 'VALIDATION_ERROR');
        this.errors = errors;
    }
}
