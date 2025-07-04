import * as functions from "firebase-functions";
import { Request, Response } from 'express';
import { createExpressApp } from "../common/express";
import { asyncHandler, sendSuccess } from "../../utils/globalUtil";
import { generateWelcomeMessage } from "../services/messageService";

// Create Express app
const app = createExpressApp();

/**
 * POST /greeting - Generate a welcome message
 * Body: { name?: string }
 */
app.post('/greeting', asyncHandler(async (req: Request, res: Response) => {
  // Basic validation (optional for greeting)
  const { name } = req.body;
  
  // Generate message
  const message = generateWelcomeMessage(name || "Anonymous");
  
  // Send response using standard format
  sendSuccess(res, {
    message,
    user: name || "Anonymous",
    timestamp: new Date().toISOString()
  });
}));

/**
 * GET /greeting?name=John - Alternative GET endpoint for testing
 */
app.get('/greeting', asyncHandler(async (req: Request, res: Response) => {
  const name = req.query.name as string;
  const message = generateWelcomeMessage(name || "Anonymous");
  
  sendSuccess(res, {
    message,
    user: name || "Anonymous",
    timestamp: new Date().toISOString()
  });
}));

// Export the function
export const helloLawLink = functions.https.onRequest(app);