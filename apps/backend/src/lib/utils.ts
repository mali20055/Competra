import { nanoid } from 'nanoid';

/**
 * Generates a unique 4-character tournament code
 * Uses uppercase alphanumeric characters for readability
 */
export function generateTournamentCode(): string {
    // Use custom alphabet without confusing characters (0/O, 1/I/L)
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    let code = '';

    for (let i = 0; i < 4; i++) {
        code += alphabet[Math.floor(Math.random() * alphabet.length)];
    }

    return code;
}

/**
 * Generates a unique idempotency key
 */
export function generateIdempotencyKey(): string {
    return nanoid(32);
}

/**
 * Validates tournament code format
 */
export function isValidTournamentCode(code: string): boolean {
    return /^[A-Z2-9]{4}$/.test(code);
}
