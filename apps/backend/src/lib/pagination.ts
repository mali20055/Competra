/**
 * Cursor-based pagination utility
 * SECURITY: Never use page=1 style pagination to prevent scraping
 */

export interface CursorPaginationParams {
    cursor?: string;
    take?: number;
}

export interface CursorPaginationResult<T> {
    data: T[];
    nextCursor: string | null;
    hasMore: boolean;
}

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

/**
 * Validates and normalizes pagination parameters
 */
export function normalizePaginationParams(params: CursorPaginationParams): {
    cursor: string | undefined;
    take: number;
} {
    let take = params.take ?? DEFAULT_PAGE_SIZE;

    // Enforce max page size
    if (take > MAX_PAGE_SIZE) {
        take = MAX_PAGE_SIZE;
    }

    if (take < 1) {
        take = DEFAULT_PAGE_SIZE;
    }

    return {
        cursor: params.cursor,
        take,
    };
}

/**
 * Builds cursor pagination result from Prisma query results
 */
export function buildCursorPaginationResult<T extends { id: string }>(
    items: T[],
    take: number
): CursorPaginationResult<T> {
    const hasMore = items.length > take;
    const data = hasMore ? items.slice(0, take) : items;
    const nextCursor = hasMore && data.length > 0 ? data[data.length - 1].id : null;

    return {
        data,
        nextCursor,
        hasMore,
    };
}

/**
 * Prisma cursor pagination helper
 * Usage: const result = await prisma.user.findMany({
 *   ...getPrismaCursorParams({ cursor, take }),
 *   where: { ... }
 * });
 */
export function getPrismaCursorParams(params: CursorPaginationParams) {
    const { cursor, take } = normalizePaginationParams(params);

    return {
        take: take + 1, // Fetch one extra to determine hasMore
        ...(cursor && {
            cursor: { id: cursor },
            skip: 1, // Skip the cursor item itself
        }),
    };
}
