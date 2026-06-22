import { Request, Response, NextFunction } from 'express';
import { ZodSchema } from 'zod';
import { BadRequestError } from '../lib/errors.js';

type ValidateSource = 'body' | 'query' | 'params';

/**
 * Validation middleware factory using Zod schemas
 * 
 * @example
 * router.post('/tournament', validate(createTournamentSchema, 'body'), controller.create);
 */
export function validate<T>(schema: ZodSchema<T>, source: ValidateSource = 'body') {
    return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
        try {
            const data = req[source];
            const validated = await schema.parseAsync(data);

            // Replace original data with validated (and transformed) data
            req[source] = validated as typeof req[typeof source];

            next();
        } catch (error) {
            next(error); // Will be caught by error handler
        }
    };
}

/**
 * Validate multiple sources at once
 * 
 * @example
 * router.put('/tournament/:id', 
 *   validateMultiple({ 
 *     params: paramsSchema, 
 *     body: updateSchema 
 *   }), 
 *   controller.update
 * );
 */
export function validateMultiple(schemas: Partial<Record<ValidateSource, ZodSchema>>) {
    return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
        try {
            for (const [source, schema] of Object.entries(schemas)) {
                if (schema) {
                    const data = req[source as ValidateSource];
                    const validated = await schema.parseAsync(data);
                    req[source as ValidateSource] = validated as typeof req[typeof source as ValidateSource];
                }
            }
            next();
        } catch (error) {
            next(error);
        }
    };
}
