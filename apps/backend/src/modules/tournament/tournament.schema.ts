import { z } from 'zod';
import { TournamentMode, ParticipantStatus } from '@prisma/client';

// ============================================================================
// TOURNAMENT SCHEMAS
// ============================================================================

/**
 * Tournament configuration schema
 */
export const tournamentConfigSchema = z.object({
    pointsPerWin: z.number().int().min(1).max(10).default(3),
    pointsPerDraw: z.number().int().min(0).max(5).default(1),
    pointsPerLoss: z.number().int().min(0).max(3).default(0),
    matchDurationMinutes: z.number().int().min(1).max(120).optional(),
    allowDraws: z.boolean().default(true),
});

/**
 * Participant slot definition for tournament creation
 */
export const participantSlotSchema = z.object({
    nickname: z.string().min(1).max(30).trim(),
    status: z.nativeEnum(ParticipantStatus).default('OPEN'),
    userId: z.string().cuid().optional(), // For friend invites
});

/**
 * Create tournament request schema
 */
export const createTournamentSchema = z.object({
    name: z
        .string()
        .min(3, 'Tournament name must be at least 3 characters')
        .max(50, 'Tournament name must be at most 50 characters')
        .trim(),
    mode: z.nativeEnum(TournamentMode),
    config: tournamentConfigSchema.optional().default({}),
    participants: z
        .array(participantSlotSchema)
        .min(2, 'At least 2 participants required')
        .max(32, 'Maximum 32 participants allowed'),
});

/**
 * Join tournament request schema
 */
export const joinTournamentSchema = z.object({
    code: z
        .string()
        .length(4, 'Tournament code must be 4 characters')
        .toUpperCase()
        .regex(/^[A-Z2-9]{4}$/, 'Invalid tournament code format'),
    nickname: z
        .string()
        .min(1, 'Nickname is required')
        .max(30, 'Nickname must be at most 30 characters')
        .trim(),
});

/**
 * Start tournament request schema
 */
export const startTournamentSchema = z.object({
    tournamentId: z.string().cuid(),
});

/**
 * Get tournament by ID params schema
 */
export const getTournamentParamsSchema = z.object({
    id: z.string().cuid(),
});

/**
 * List tournaments query schema (cursor-based pagination)
 */
export const listTournamentsQuerySchema = z.object({
    cursor: z.string().cuid().optional(),
    take: z.coerce.number().int().min(1).max(50).default(20),
    status: z.nativeEnum({ OPEN: 'OPEN', LIVE: 'LIVE', COMPLETED: 'COMPLETED' } as const).optional(),
});

// ============================================================================
// TYPE EXPORTS
// ============================================================================

export type TournamentConfig = z.infer<typeof tournamentConfigSchema>;
export type ParticipantSlot = z.infer<typeof participantSlotSchema>;
export type CreateTournamentInput = z.infer<typeof createTournamentSchema>;
export type JoinTournamentInput = z.infer<typeof joinTournamentSchema>;
export type StartTournamentInput = z.infer<typeof startTournamentSchema>;
export type ListTournamentsQuery = z.infer<typeof listTournamentsQuerySchema>;
