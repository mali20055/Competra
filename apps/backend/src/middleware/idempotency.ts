import { Request, Response, NextFunction } from 'express';
import prisma from '../lib/prisma.js';
import { ConflictError } from '../lib/errors.js';

const IDEMPOTENCY_HEADER = 'x-idempotency-key';
const IDEMPOTENCY_EXPIRY_HOURS = 24;

/**
 * Idempotency middleware for preventing duplicate operations
 * 
 * Critical for operations like:
 * - Tournament creation
 * - Starting a tournament (fixture generation)
 * - Match score submission
 * 
 * @example
 * router.post('/tournament/start', idempotency, controller.startTournament);
 */
export async function idempotency(
    req: Request,
    res: Response,
    next: NextFunction
): Promise<void> {
    const idempotencyKey = req.headers[IDEMPOTENCY_HEADER] as string | undefined;

    // If no key provided, skip idempotency check but continue
    if (!idempotencyKey) {
        return next();
    }

    try {
        // Check if we've already processed this key
        const existingKey = await prisma.idempotencyKey.findUnique({
            where: { key: idempotencyKey },
        });

        if (existingKey) {
            // Check if expired
            if (existingKey.expires_at < new Date()) {
                // Key expired, delete it and allow new request
                await prisma.idempotencyKey.delete({
                    where: { key: idempotencyKey },
                });
            } else if (existingKey.response) {
                // Return cached response
                res.status(200).json(existingKey.response);
                return;
            } else {
                // Request is still being processed
                throw new ConflictError(
                    'Request with this idempotency key is already being processed',
                    'DUPLICATE_REQUEST'
                );
            }
        }

        // Create new idempotency key record
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + IDEMPOTENCY_EXPIRY_HOURS);

        await prisma.idempotencyKey.create({
            data: {
                key: idempotencyKey,
                user_id: (req as Request & { userId?: string }).userId,
                expires_at: expiresAt,
            },
        });

        // Store the original json method
        const originalJson = res.json.bind(res);

        // Override json to cache the response
        res.json = function (body: unknown): Response {
            // Only cache successful responses
            if (res.statusCode >= 200 && res.statusCode < 300) {
                prisma.idempotencyKey
                    .update({
                        where: { key: idempotencyKey },
                        data: { response: body as object },
                    })
                    .catch((err) => {
                        console.error('Failed to cache idempotency response:', err);
                    });
            }

            return originalJson(body);
        };

        next();
    } catch (error) {
        // Clean up on error
        if (idempotencyKey) {
            await prisma.idempotencyKey.delete({
                where: { key: idempotencyKey },
            }).catch(() => {
                // Ignore deletion errors
            });
        }
        next(error);
    }
}

/**
 * Cleanup expired idempotency keys (run periodically)
 */
export async function cleanupExpiredKeys(): Promise<number> {
    const result = await prisma.idempotencyKey.deleteMany({
        where: {
            expires_at: { lt: new Date() },
        },
    });
    return result.count;
}
