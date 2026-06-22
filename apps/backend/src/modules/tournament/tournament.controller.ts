import { Request, Response, NextFunction } from 'express';
import tournamentService from './tournament.service.js';
import type {
    CreateTournamentInput,
    JoinTournamentInput,
    ListTournamentsQuery
} from './tournament.schema.js';
import type { AuthenticatedRequest } from '../../types/express.js';

/**
 * Tournament Controller
 * Handles HTTP request/response for tournament operations
 */
export const tournamentController = {
    /**
     * POST /tournaments
     * Create a new tournament
     */
    async create(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const authReq = req as AuthenticatedRequest;
            const input = req.body as CreateTournamentInput;

            const tournament = await tournamentService.create(input, authReq.userId);

            res.status(201).json({
                success: true,
                data: tournament,
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * POST /tournaments/join
     * Join a tournament via code
     */
    async join(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const authReq = req as AuthenticatedRequest;
            const input = req.body as JoinTournamentInput;

            const participant = await tournamentService.joinByCode(input, authReq.userId);

            res.status(200).json({
                success: true,
                data: participant,
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * GET /tournaments/:id
     * Get tournament by ID
     */
    async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const { id } = req.params;

            const tournament = await tournamentService.getById(id);

            res.status(200).json({
                success: true,
                data: tournament,
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * GET /tournaments/code/:code
     * Get tournament by code
     */
    async getByCode(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const { code } = req.params;

            const tournament = await tournamentService.getByCode(code);

            res.status(200).json({
                success: true,
                data: tournament,
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * GET /tournaments
     * List tournaments with cursor-based pagination
     */
    async list(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const query = req.query as unknown as ListTournamentsQuery;

            const result = await tournamentService.list(query);

            res.status(200).json({
                success: true,
                data: result.data,
                pagination: {
                    nextCursor: result.nextCursor,
                    hasMore: result.hasMore,
                },
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * POST /tournaments/:id/start
     * Start a tournament (generate fixtures)
     */
    async start(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const authReq = req as AuthenticatedRequest;
            const { id } = req.params;

            const tournament = await tournamentService.start(id, authReq.userId);

            res.status(200).json({
                success: true,
                data: tournament,
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * DELETE /tournaments/:id
     * Delete a tournament
     */
    async delete(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const authReq = req as AuthenticatedRequest;
            const { id } = req.params;

            await tournamentService.delete(id, authReq.userId);

            res.status(204).send();
        } catch (error) {
            next(error);
        }
    },
};

export default tournamentController;
