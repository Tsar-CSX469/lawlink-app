import * as functions from "firebase-functions";
import { Request, Response } from 'express';
import { createExpressApp } from "../express";
import { asyncHandler, sendSuccess, sendError } from "../../utils/globalUtil";
import * as quizService from "../services/quizService";

// Create Express app
const app = createExpressApp();

/**
 * GET /quiz/:quizId - Get a specific quiz with questions
 * Path params: quizId (string)
 * Query params: 
 *   - includeAnswers (boolean) - whether to include correct answers (default: false for students)
 */
app.get('/quiz/:quizId', asyncHandler(async (req: Request, res: Response) => {
  const { quizId } = req.params;
  const includeAnswers = req.query.includeAnswers === 'true';

  if (!quizId) {
    return sendError(res, 'Quiz ID is required', 400);
  }

  try {
    const quiz = await quizService.getQuizById(quizId);
    
    if (!quiz) {
      return sendError(res, 'Quiz not found', 404);
    }

    // Remove correct answers from questions unless specifically requested (for admin/teacher use)
    if (!includeAnswers) {
      quiz.questions = quiz.questions.map(question => ({
        ...question,
        correctAnswer: '', // Hide correct answer
        explanation: '' // Hide explanation until after submission
      }));
    }

    sendSuccess(res, {
      quiz,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error fetching quiz:', error);
    sendError(res, 'Failed to fetch quiz', 500);
  }
}));

/**
 * GET /quizzes - Get all available quizzes (without questions)
 * Query params:
 *   - category (string) - filter by category
 */
app.get('/quizzes', asyncHandler(async (req: Request, res: Response) => {
  const { category } = req.query;

  try {
    let quizzes = await quizService.getAvailableQuizzes();

    // Filter by category if specified
    if (category && typeof category === 'string') {
      quizzes = quizzes.filter(quiz => quiz.category.toLowerCase() === category.toLowerCase());
    }

    sendSuccess(res, {
      quizzes,
      count: quizzes.length,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error fetching quizzes:', error);
    sendError(res, 'Failed to fetch quizzes', 500);
  }
}));

/**
 * POST /quiz/:quizId/submit - Submit quiz answers
 * Path params: quizId (string)
 * Body: {
 *   userId: string,
 *   answers: Array<{
 *     questionId: string,
 *     selectedOptionId: string,
 *     timeSpent: number
 *   }>,
 *   duration: number
 * }
 */
app.post('/quiz/:quizId/submit', asyncHandler(async (req: Request, res: Response) => {
  const { quizId } = req.params;
  const { userId, answers, duration } = req.body;

  // Log the incoming request for debugging
  functions.logger.info('Quiz submission request:', {
    quizId,
    userId,
    answersCount: answers ? answers.length : 0,
    duration,
    requestBody: req.body
  });

  // Validation
  if (!quizId) {
    functions.logger.error('Validation failed: Quiz ID missing');
    return sendError(res, 'Quiz ID is required', 400);
  }

  if (!userId) {
    functions.logger.error('Validation failed: User ID missing');
    return sendError(res, 'User ID is required', 400);
  }

  if (!answers || !Array.isArray(answers) || answers.length === 0) {
    functions.logger.error('Validation failed: Invalid answers', { answers });
    return sendError(res, 'Answers are required', 400);
  }

  if (typeof duration !== 'number' || duration < 0) {
    functions.logger.error('Validation failed: Invalid duration', { duration, type: typeof duration });
    return sendError(res, 'Valid duration is required', 400);
  }

  // Validate answer format
  for (const answer of answers) {
    if (!answer.questionId || !answer.selectedOptionId) {
      functions.logger.error('Validation failed: Invalid answer format', { answer });
      return sendError(res, 'Each answer must have questionId and selectedOptionId', 400);
    }
    if (typeof answer.timeSpent !== 'number' || answer.timeSpent < 0) {
      functions.logger.error('Validation failed: Invalid timeSpent', { answer });
      return sendError(res, 'Each answer must have valid timeSpent', 400);
    }
  }

  try {
    // Add basic validation to prevent cheating
    const quiz = await quizService.getQuizById(quizId);
    if (!quiz) {
      return sendError(res, 'Quiz not found', 404);
    }

    // Check if user answered all questions
    if (answers.length !== quiz.questions.length) {
      functions.logger.error('Question count mismatch', { 
        answersProvided: answers.length, 
        questionsInQuiz: quiz.questions.length 
      });
      return sendError(res, `All questions must be answered. Expected ${quiz.questions.length}, got ${answers.length}`, 400);
    }

    // Check for reasonable time limits (prevent too fast submissions)
    const minTimePerQuestion = 5; // 5 seconds minimum per question
    const minTotalTime = quiz.questions.length * minTimePerQuestion;
    if (duration < minTotalTime) {
      functions.logger.error('Submission too fast', { 
        duration, 
        minRequired: minTotalTime, 
        questionsCount: quiz.questions.length 
      });
      return sendError(res, `Submission too fast, please take your time. Minimum ${minTotalTime} seconds required`, 400);
    }

    // Check maximum time limit if set
    if (quiz.timeLimit && duration > quiz.timeLimit * 60) {
      functions.logger.error('Time limit exceeded', { 
        duration, 
        timeLimit: quiz.timeLimit * 60 
      });
      return sendError(res, 'Quiz time limit exceeded', 400);
    }

    // Calculate which answers are correct (server-side validation)
    const validatedAnswers = answers.map(answer => {
      const question = quiz.questions.find(q => q.id === answer.questionId);
      
      // Normalize both values for comparison (remove quotes if present)
      const selectedOption = answer.selectedOptionId?.toString().replace(/['"]/g, '');
      const correctOption = question?.correctAnswer?.toString().replace(/['"]/g, '');
      const isCorrect = question ? selectedOption === correctOption : false;
      
      // Debug logging for answer validation
      functions.logger.info('Answer validation:', {
        questionId: answer.questionId,
        selectedOptionId: answer.selectedOptionId,
        selectedNormalized: selectedOption,
        correctAnswer: question?.correctAnswer,
        correctNormalized: correctOption,
        isCorrect,
        questionFound: !!question
      });
      
      return {
        questionId: answer.questionId,
        selectedOptionId: answer.selectedOptionId,
        isCorrect,
        timeSpent: answer.timeSpent
      };
    });

    const submission = {
      userId,
      quizId,
      answers: validatedAnswers,
      duration
    };

    const result = await quizService.submitQuiz(submission);

    sendSuccess(res, {
      result,
      message: result.passed ? 'Quiz completed successfully!' : 'Quiz completed. Keep studying!',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error submitting quiz:', error);
    sendError(res, 'Failed to submit quiz', 500);
  }
}));

/**
 * GET /user/:userId/history - Get user's quiz history
 * Path params: userId (string)
 * Query params:
 *   - limit (number) - maximum number of results (default: 10)
 */
app.get('/user/:userId/history', asyncHandler(async (req: Request, res: Response) => {
  const { userId } = req.params;
  const limit = parseInt(req.query.limit as string) || 10;

  if (!userId) {
    return sendError(res, 'User ID is required', 400);
  }

  if (limit < 1 || limit > 100) {
    return sendError(res, 'Limit must be between 1 and 100', 400);
  }

  try {
    const history = await quizService.getUserQuizHistory(userId, limit);

    sendSuccess(res, {
      history,
      count: history.length,
      userId,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error fetching user history:', error);
    sendError(res, 'Failed to fetch user quiz history', 500);
  }
}));

/**
 * GET /leaderboard - Get quiz leaderboard
 * Query params:
 *   - quizId (string) - specific quiz ID, or 'all' for overall leaderboard
 *   - limit (number) - maximum number of results (default: 50)
 */
app.get('/leaderboard', asyncHandler(async (req: Request, res: Response) => {
  const quizId = req.query.quizId as string;
  const limit = parseInt(req.query.limit as string) || 50;

  if (limit < 1 || limit > 100) {
    return sendError(res, 'Limit must be between 1 and 100', 400);
  }

  try {
    const leaderboard = await quizService.getQuizLeaderboard(quizId, limit);

    sendSuccess(res, {
      leaderboard,
      count: leaderboard.length,
      quizId: quizId || 'all',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error fetching leaderboard:', error);
    sendError(res, 'Failed to fetch leaderboard', 500);
  }
}));

/**
 * GET /quiz/:quizId/stats - Get quiz statistics
 * Path params: quizId (string)
 */
app.get('/quiz/:quizId/stats', asyncHandler(async (req: Request, res: Response) => {
  const { quizId } = req.params;

  if (!quizId) {
    return sendError(res, 'Quiz ID is required', 400);
  }

  try {
    // This would typically get stats from the scores collection
    // For now, returning a placeholder response
    const stats = {
      quizId,
      totalAttempts: 0,
      averageScore: 0,
      passRate: 0,
      averageTime: 0
    };

    sendSuccess(res, {
      stats,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error fetching quiz stats:', error);
    sendError(res, 'Failed to fetch quiz statistics', 500);
  }
}));

/**
 * POST /quiz/:quizId/validate-answer - Validate a single answer in real-time
 * Path params: quizId (string)
 * Body: {
 *   questionId: string,
 *   selectedOptionId: string
 * }
 */
app.post('/quiz/:quizId/validate-answer', asyncHandler(async (req: Request, res: Response) => {
  const { quizId } = req.params;
  const { questionId, selectedOptionId } = req.body;

  if (!quizId || !questionId || !selectedOptionId) {
    return sendError(res, 'Quiz ID, question ID, and selected option ID are required', 400);
  }

  try {
    // Get the quiz to access question details
    const quiz = await quizService.getQuizById(quizId);
    
    if (!quiz) {
      return sendError(res, 'Quiz not found', 404);
    }

    // Find the specific question
    const question = quiz.questions.find(q => q.id === questionId);
    if (!question) {
      return sendError(res, 'Question not found', 404);
    }

    // Validate the answer using the quiz service
    const validation = await quizService.validateSingleAnswer(questionId, selectedOptionId, quiz);

    sendSuccess(res, {
      isCorrect: validation.isCorrect,
      explanation: validation.explanation,
      points: validation.points,
      correctOptionId: validation.correctOptionId, // For showing the correct answer
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    functions.logger.error('Error validating answer:', error);
    sendError(res, 'Failed to validate answer', 500);
  }
}));

// Export the function
export const quizLawLink = functions.https.onRequest(app);
