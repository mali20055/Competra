import { Request } from 'express';

declare global {
    namespace Express {
        interface Request {
            userId?: string;
            user?: {
                id: string;
                username: string;
                email: string;
            };
        }
    }
}

export interface AuthenticatedRequest extends Request {
    userId: string;
    user: {
        id: string;
        username: string;
        email: string;
    };
}

export interface PaginatedRequest extends Request {
    query: {
        cursor?: string;
        take?: string;
    };
}

export interface ApiResponse<T = unknown> {
    success: boolean;
    data?: T;
    error?: {
        code: string;
        message: string;
        errors?: Record<string, string[]>;
    };
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
    pagination: {
        nextCursor: string | null;
        hasMore: boolean;
    };
}
