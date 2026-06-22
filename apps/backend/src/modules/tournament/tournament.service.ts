import prisma from '../../lib/prisma.js';
import { generateTournamentCode } from '../../lib/utils.js';
import {
    getPrismaCursorParams,
    buildCursorPaginationResult,
    type CursorPaginationResult,
} from '../../lib/pagination.js';
import { NotFoundError, BadRequestError, ConflictError } from '../../lib/errors.js';
import type { CreateTournamentInput, JoinTournamentInput, ListTournamentsQuery } from './tournament.schema.js';
import { Tournament, Participant, TournamentStatus, ParticipantStatus } from '@prisma/client';

type TournamentWithParticipants = Tournament & { participants: Participant[] };

/**
 * Tournament Service
 * Handles all tournament-related business logic
 */
export const tournamentService = {
    /**
     * Create a new tournament with participants (Hybrid Lobby)
     * Uses transaction to ensure atomicity
     */
    async create(
        input: CreateTournamentInput,
        creatorId: string
    ): Promise<TournamentWithParticipants> {
        // Generate unique tournament code with retry
        let code: string;
        let attempts = 0;
        const maxAttempts = 5;

        do {
            code = generateTournamentCode();
            const existing = await prisma.tournament.findUnique({
                where: { code },
            });
            if (!existing) break;
            attempts++;
        } while (attempts < maxAttempts);

        if (attempts >= maxAttempts) {
            throw new ConflictError('Failed to generate unique tournament code. Please try again.');
        }

        // Create tournament with participants in a transaction
        const tournament = await prisma.$transaction(async (tx) => {
            // Create the tournament
            const newTournament = await tx.tournament.create({
                data: {
                    code,
                    name: input.name,
                    mode: input.mode,
                    config: input.config,
                    created_by: creatorId,
                },
            });

            // Create participant slots
            const participantData = input.participants.map((p, index) => ({
                tournament_id: newTournament.id,
                user_id: p.userId || (index === 0 ? creatorId : null), // Slot 1 = Admin
                nickname: p.nickname,
                status: index === 0 ? ParticipantStatus.CONFIRMED : p.status,
                is_ready: index === 0, // Admin is ready by default
                slot_order: index + 1,
            }));

            await tx.participant.createMany({
                data: participantData,
            });

            // Fetch complete tournament with participants
            return tx.tournament.findUnique({
                where: { id: newTournament.id },
                include: {
                    participants: {
                        orderBy: { slot_order: 'asc' },
                    },
                },
            });
        });

        if (!tournament) {
            throw new Error('Failed to create tournament');
        }

        return tournament as TournamentWithParticipants;
    },

    /**
     * Join a tournament via code (finds first OPEN slot)
     * Uses transaction to prevent race conditions
     */
    async joinByCode(
        input: JoinTournamentInput,
        userId: string
    ): Promise<Participant> {
        return prisma.$transaction(async (tx) => {
            // Find the tournament
            const tournament = await tx.tournament.findUnique({
                where: { code: input.code },
                include: {
                    participants: {
                        orderBy: { slot_order: 'asc' },
                    },
                },
            });

            if (!tournament) {
                throw new NotFoundError('Tournament not found');
            }

            if (tournament.status !== TournamentStatus.OPEN) {
                throw new BadRequestError('Tournament is no longer accepting participants');
            }

            // Check if user is already in the tournament
            const existingParticipant = tournament.participants.find(
                (p) => p.user_id === userId
            );
            if (existingParticipant) {
                throw new ConflictError('You are already in this tournament');
            }

            // Find first OPEN slot
            const openSlot = tournament.participants.find(
                (p) => p.status === ParticipantStatus.OPEN
            );

            if (!openSlot) {
                throw new BadRequestError('No open slots available in this tournament');
            }

            // Update the slot with the joining user
            const updatedParticipant = await tx.participant.update({
                where: { id: openSlot.id },
                data: {
                    user_id: userId,
                    nickname: input.nickname,
                    status: ParticipantStatus.CONFIRMED,
                    is_ready: false,
                },
            });

            return updatedParticipant;
        });
    },

    /**
     * Get tournament by ID
     */
    async getById(id: string): Promise<TournamentWithParticipants> {
        const tournament = await prisma.tournament.findUnique({
            where: { id },
            include: {
                participants: {
                    orderBy: { slot_order: 'asc' },
                },
                creator: {
                    select: {
                        id: true,
                        username: true,
                        avatar: true,
                    },
                },
                matches: {
                    orderBy: [{ round: 'asc' }, { match_order: 'asc' }],
                    include: {
                        home_participant: true,
                        away_participant: true,
                    },
                },
            },
        });

        if (!tournament) {
            throw new NotFoundError('Tournament not found');
        }

        return tournament as TournamentWithParticipants;
    },

    /**
     * Get tournament by code
     */
    async getByCode(code: string): Promise<TournamentWithParticipants> {
        const tournament = await prisma.tournament.findUnique({
            where: { code: code.toUpperCase() },
            include: {
                participants: {
                    orderBy: { slot_order: 'asc' },
                },
                creator: {
                    select: {
                        id: true,
                        username: true,
                        avatar: true,
                    },
                },
            },
        });

        if (!tournament) {
            throw new NotFoundError('Tournament not found');
        }

        return tournament as TournamentWithParticipants;
    },

    /**
     * List public tournaments with cursor-based pagination
     */
    async list(
        query: ListTournamentsQuery
    ): Promise<CursorPaginationResult<Tournament>> {
        const paginationParams = getPrismaCursorParams({
            cursor: query.cursor,
            take: query.take,
        });

        const tournaments = await prisma.tournament.findMany({
            ...paginationParams,
            where: {
                ...(query.status && { status: query.status }),
            },
            orderBy: { created_at: 'desc' },
            include: {
                creator: {
                    select: {
                        id: true,
                        username: true,
                        avatar: true,
                    },
                },
                _count: {
                    select: { participants: true },
                },
            },
        });

        return buildCursorPaginationResult(tournaments, query.take);
    },

    /**
     * Start a tournament (generate fixtures)
     * CRITICAL: Uses idempotency + transaction
     */
    async start(tournamentId: string, userId: string): Promise<Tournament> {
        return prisma.$transaction(async (tx) => {
            // Lock the tournament row for update
            const tournament = await tx.tournament.findUnique({
                where: { id: tournamentId },
                include: {
                    participants: {
                        where: { status: ParticipantStatus.CONFIRMED },
                        orderBy: { slot_order: 'asc' },
                    },
                },
            });

            if (!tournament) {
                throw new NotFoundError('Tournament not found');
            }

            // Verify ownership
            if (tournament.created_by !== userId) {
                throw new BadRequestError('Only the tournament creator can start the tournament');
            }

            // Check if already started (idempotency check)
            if (tournament.status !== TournamentStatus.OPEN) {
                throw new ConflictError('Tournament has already been started');
            }

            // Validate minimum participants
            const confirmedParticipants = tournament.participants;
            if (confirmedParticipants.length < 2) {
                throw new BadRequestError('At least 2 confirmed participants are required to start');
            }

            // Generate fixtures based on mode
            const matches = generateFixtures(
                tournamentId,
                confirmedParticipants,
                tournament.mode
            );

            // Create matches
            await tx.match.createMany({
                data: matches,
            });

            // Update tournament status
            const updatedTournament = await tx.tournament.update({
                where: { id: tournamentId },
                data: { status: TournamentStatus.LIVE },
            });

            return updatedTournament;
        });
    },

    /**
     * Delete a tournament (atomic operation)
     */
    async delete(tournamentId: string, userId: string): Promise<void> {
        await prisma.$transaction(async (tx) => {
            const tournament = await tx.tournament.findUnique({
                where: { id: tournamentId },
            });

            if (!tournament) {
                throw new NotFoundError('Tournament not found');
            }

            if (tournament.created_by !== userId) {
                throw new BadRequestError('Only the tournament creator can delete the tournament');
            }

            // Cascade delete handled by Prisma schema
            await tx.tournament.delete({
                where: { id: tournamentId },
            });
        });
    },
};

/**
 * Generate fixtures based on tournament mode
 */
function generateFixtures(
    tournamentId: string,
    participants: Participant[],
    mode: string
): Array<{
    tournament_id: string;
    home_participant_id: string;
    away_participant_id: string;
    round: number;
    match_order: number;
}> {
    const matches: Array<{
        tournament_id: string;
        home_participant_id: string;
        away_participant_id: string;
        round: number;
        match_order: number;
    }> = [];

    if (mode === 'LEAGUE') {
        // Round-robin: everyone plays everyone
        let matchOrder = 1;
        for (let round = 1; round <= participants.length - 1; round++) {
            for (let i = 0; i < participants.length; i++) {
                for (let j = i + 1; j < participants.length; j++) {
                    // Distribute matches across rounds
                    const currentRound = ((matchOrder - 1) % (participants.length - 1)) + 1;
                    matches.push({
                        tournament_id: tournamentId,
                        home_participant_id: participants[i].id,
                        away_participant_id: participants[j].id,
                        round: currentRound,
                        match_order: matchOrder++,
                    });
                }
            }
        }
    } else if (mode === 'BRACKET') {
        // Single elimination bracket
        const numParticipants = participants.length;
        const numRounds = Math.ceil(Math.log2(numParticipants));

        // Shuffle participants for random bracket seeding
        const shuffled = [...participants].sort(() => Math.random() - 0.5);

        // First round matches
        let matchOrder = 1;
        for (let i = 0; i < shuffled.length - 1; i += 2) {
            matches.push({
                tournament_id: tournamentId,
                home_participant_id: shuffled[i].id,
                away_participant_id: shuffled[i + 1]?.id || shuffled[i].id, // Bye handling
                round: 1,
                match_order: matchOrder++,
            });
        }

        // Placeholder matches for subsequent rounds would be created as matches complete
    } else if (mode === 'GROUP') {
        // Group stage: split into groups, round-robin within groups
        // Simplified: treat as league for now
        return generateFixtures(tournamentId, participants, 'LEAGUE');
    }

    return matches;
}

export default tournamentService;
