import { Router } from 'express';
import tournamentController from './tournament.controller.js';
import { validate } from '../../middleware/validate.js';
import { idempotency } from '../../middleware/idempotency.js';
import { createTournamentRateLimiter, searchRateLimiter } from '../../middleware/rateLimiter.js';
import {
    createTournamentSchema,
    joinTournamentSchema,
    getTournamentParamsSchema,
    listTournamentsQuerySchema,
} from './tournament.schema.js';

const router = Router();

// ============================================================================
// PUBLIC ROUTES (Authentication required but listed here for clarity)
// ============================================================================

/**
 * GET /tournaments
 * List public tournaments with cursor-based pagination
 */
router.get(
    '/',
    searchRateLimiter,
    validate(listTournamentsQuerySchema, 'query'),
    tournamentController.list
);

/**
 * GET /tournaments/:id
 * Get tournament by ID
 */
router.get(
    '/:id',
    validate(getTournamentParamsSchema, 'params'),
    tournamentController.getById
);

/**
 * GET /tournaments/code/:code
 * Get tournament by code
 */
router.get(
    '/code/:code',
    tournamentController.getByCode
);

// ============================================================================
// AUTHENTICATED ROUTES
// ============================================================================

/**
 * POST /tournaments
 * Create a new tournament
 */
router.post(
    '/',
    createTournamentRateLimiter,
    validate(createTournamentSchema, 'body'),
    tournamentController.create
);

/**
 * POST /tournaments/join
 * Join a tournament via code
 */
router.post(
    '/join',
    validate(joinTournamentSchema, 'body'),
    tournamentController.join
);

/**
 * POST /tournaments/:id/start
 * Start a tournament (generate fixtures)
 * Uses idempotency middleware to prevent double-start
 */
router.post(
    '/:id/start',
    idempotency,
    validate(getTournamentParamsSchema, 'params'),
    tournamentController.start
);

/**
 * DELETE /tournaments/:id
 * Delete a tournament
 */
router.delete(
    '/:id',
    validate(getTournamentParamsSchema, 'params'),
    tournamentController.delete
);

export default router;
