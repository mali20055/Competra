import rateLimit from 'express-rate-limit';
import { env } from '../config/env.js';
import { TooManyRequestsError } from '../lib/errors.js';

/**
 * Default rate limiter for general API endpoints
 */
export const defaultRateLimiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX_REQUESTS * 5, // More lenient for general endpoints
    message: {
        success: false,
        error: {
            code: 'TOO_MANY_REQUESTS',
            message: 'Too many requests, please try again later'
        }
    },
    standardHeaders: true,
    legacyHeaders: false,
});

/**
 * Strict rate limiter for auth endpoints (login, register)
 * More restrictive to prevent brute force attacks
 */
export const authRateLimiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: 10, // Only 10 attempts per minute
    message: {
        success: false,
        error: {
            code: 'TOO_MANY_REQUESTS',
            message: 'Too many authentication attempts, please try again later'
        }
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, _res, next) => {
        next(new TooManyRequestsError('Too many authentication attempts'));
    },
});

/**
 * Rate limiter for search endpoints
 * Prevents scraping attempts
 */
export const searchRateLimiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX_REQUESTS,
    message: {
        success: false,
        error: {
            code: 'TOO_MANY_REQUESTS',
            message: 'Too many search requests, please try again later'
        }
    },
    standardHeaders: true,
    legacyHeaders: false,
});

/**
 * Rate limiter for tournament creation
 */
export const createTournamentRateLimiter = rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MS * 5, // 5 minutes window
    max: 10, // Max 10 tournaments per 5 minutes
    message: {
        success: false,
        error: {
            code: 'TOO_MANY_REQUESTS',
            message: 'Tournament creation limit reached, please try again later'
        }
    },
    standardHeaders: true,
    legacyHeaders: false,
});
