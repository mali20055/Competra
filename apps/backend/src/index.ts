import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env.js';
import { errorHandler, defaultRateLimiter } from './middleware/index.js';

// Import routes
import { tournamentRoutes } from './modules/tournament/index.js';
// import authRoutes from './modules/auth/auth.routes.js';

const app = express();

// ============================================================================
// GLOBAL MIDDLEWARE
// ============================================================================

// Security headers
app.use(helmet());

// CORS configuration
app.use(
    cors({
        origin: env.CORS_ORIGIN,
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Idempotency-Key'],
    })
);

// Body parsing
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// Rate limiting
app.use(defaultRateLimiter);

// ============================================================================
// HEALTH CHECK
// ============================================================================

app.get('/health', (_req, res) => {
    res.status(200).json({
        success: true,
        data: {
            status: 'healthy',
            timestamp: new Date().toISOString(),
            environment: env.NODE_ENV,
        },
    });
});

// ============================================================================
// API ROUTES (v1)
// ============================================================================

app.use('/api/v1/tournaments', tournamentRoutes);
// app.use('/api/v1/auth', authRoutes);
// app.use('/api/v1/participants', participantRoutes);
// app.use('/api/v1/matches', matchRoutes);

// ============================================================================
// 404 HANDLER
// ============================================================================

app.use((_req, res) => {
    res.status(404).json({
        success: false,
        error: {
            code: 'NOT_FOUND',
            message: 'The requested resource was not found',
        },
    });
});

// ============================================================================
// GLOBAL ERROR HANDLER
// ============================================================================

app.use(errorHandler);

// ============================================================================
// START SERVER
// ============================================================================

const server = app.listen(env.PORT, () => {
    console.log(`
  🚀 Competra API Server
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🌍 Environment: ${env.NODE_ENV}
  🔗 URL: http://localhost:${env.PORT}
  📊 Health: http://localhost:${env.PORT}/health
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully...');
    server.close(() => {
        console.log('Process terminated.');
        process.exit(0);
    });
});

export default app;
