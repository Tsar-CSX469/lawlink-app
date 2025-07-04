import express from 'express';
import * as functions from 'firebase-functions';

/**
 * Create a simple Express app with basic middleware
 * This is our standard setup for all Firebase Functions
 */
export function createExpressApp(): express.Application {
  const app = express();

  // Basic middleware
  app.use(express.json({ limit: '1mb' })); // Parse JSON bodies
  app.use(express.urlencoded({ extended: true })); // Parse URL-encoded bodies

  // Basic logging for development
  app.use((req, res, next) => {
    functions.logger.info(`${req.method} ${req.path}`, {
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });
    next();
  });

  // Health check endpoint (standard for all functions)
  app.get('/health', (req, res) => {
    res.json({
      success: true,
      message: 'Function is healthy',
      timestamp: new Date().toISOString()
    });
  });

  return app;
}
