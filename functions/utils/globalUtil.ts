import { Request, Response } from 'express';
import * as functions from 'firebase-functions';

/**
 * Standard response format for all APIs
 */
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

/**
 * Send a successful response
 */
export function sendSuccess<T>(res: Response, data: T, message?: string): void {
  const response: ApiResponse<T> = {
    success: true,
    data,
    ...(message && { message })
  };
  res.status(200).json(response);
}

/**
 * Send an error response
 */
export function sendError(res: Response, error: string, statusCode: number = 400): void {
  const response: ApiResponse = {
    success: false,
    error
  };
  res.status(statusCode).json(response);
}

/**
 * Wrapper for async route handlers to catch errors
 */
export function asyncHandler(fn: (req: Request, res: Response) => Promise<void>) {
  return async (req: Request, res: Response) => {
    try {
      await fn(req, res);
    } catch (error) {
      functions.logger.error('Async handler error:', error);
      sendError(res, 'Internal server error', 500);
    }
  };
}

/**
 * Basic input validation
 */
export function validateInput(data: any, required: string[]): string | null {
  for (const field of required) {
    if (!data || data[field] === undefined || data[field] === null) {
      return `Field '${field}' is required`;
    }
  }
  return null;
}