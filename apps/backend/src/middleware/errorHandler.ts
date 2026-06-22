import { Request, Response, NextFunction } from 'express';
import { AppError, ValidationError } from '../lib/errors.js';
import { env } from '../config/env.js';
import { ZodError } from 'zod';

export interface ErrorResponse {
    success: false;
    error: {
        code: string;
        message: string;
        errors?: Record<string, string[]>;
        stack?: string;
    };
}

/**
 * Global error handler middleware
 * Catches all errors and returns consistent JSON responses
 */
export function errorHandler(
    err: Error,
    _req: Request,
    res: Response,
    _next: NextFunction
): void {
    // Log error in development
    if (env.isDev) {
        console.error('Error:', err);
    }

    // Handle Zod validation errors
    if (err instanceof ZodError) {
        const errors: Record<string, string[]> = {};
        err.errors.forEach((e) => {
            const path = e.path.join('.');
            if (!errors[path]) {
                errors[path] = [];
            }
            errors[path].push(e.message);
        });

        const response: ErrorResponse = {
            success: false,
            error: {
                code: 'VALIDATION_ERROR',
                message: 'Validation failed',
                errors,
            },
        };

        res.status(422).json(response);
        return;
    }

    // Handle custom validation errors
    if (err instanceof ValidationError) {
        const response: ErrorResponse = {
            success: false,
            error: {
                code: err.code,
                message: err.message,
                errors: err.errors,
            },
        };

        res.status(err.statusCode).json(response);
        return;
    }

    // Handle custom application errors
    if (err instanceof AppError) {
        const response: ErrorResponse = {
            success: false,
            error: {
                code: err.code,
                message: err.message,
                ...(env.isDev && { stack: err.stack }),
            },
        };

        res.status(err.statusCode).json(response);
        return;
    }

    // Handle unknown errors
    const response: ErrorResponse = {
        success: false,
        error: {
            code: 'INTERNAL_ERROR',
            message: env.isProd ? 'An unexpected error occurred' : err.message,
            ...(env.isDev && { stack: err.stack }),
        },
    };

    res.status(500).json(response);
}
