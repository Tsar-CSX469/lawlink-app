import express from 'express';
import * as functions from 'firebase-functions';

/**
 * Create a simple Express app with basic middleware
 * This is our standard setup for all Firebase Functions
 */
export function createExpressApp(): express.Application {
  const app = express();

  // CORS configuration - Allow requests from your Flutter app
  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Max-Age', '3600');
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    next();
  });

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
