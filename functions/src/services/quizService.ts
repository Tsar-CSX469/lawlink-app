import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export interface QuizQuestion {
  id: string;
  question: string;
  options: {
    id: string;
    text: string;
  }[];
  correctAnswer: string;
  explanation: string;
  points: number;
  difficulty: 'easy' | 'medium' | 'hard';
  category: string;
  references?: string[];
}

export interface Quiz {
  id: string;
  title: string;
  description: string;
  category: string;
  questions: QuizQuestion[];
  totalPoints: number;
  timeLimit?: number; // in minutes
  isActive: boolean;
}

export interface QuizSubmission {
  userId: string;
  quizId: string;
  answers: {
    questionId: string;
    selectedOptionId: string;
    isCorrect: boolean;
    timeSpent: number; // in seconds
  }[];
  score: number;
  totalPoints: number;
  completedAt: Timestamp;
  duration: number; // total time taken in seconds
}

export interface QuizResult {
  score: number;
  totalPoints: number;
  percentage: number;
  passed: boolean;
  answers: {
    questionId: string;
    selectedOptionId: string;
    correctOptionId: string;
    isCorrect: boolean;
    explanation: string;
    points: number;
  }[];
}

/**
 * Retrieve a quiz by ID with questions
 */
export async function getQuizById(quizId: string): Promise<Quiz | null> {
  try {
    const quizDoc = await db.collection('quiz').doc(quizId).get();
    
    if (!quizDoc.exists) {
      return null;
    }

    const quizData = quizDoc.data() as any;
    
    // Convert Firestore data to our Quiz interface
    const quiz: Quiz = {
      id: quizDoc.id,
      title: quizData.title || 'Quiz',
      description: quizData.description || '',
      category: quizData.category || 'general',
      questions: (quizData.questions || []).map((q: any, index: number) => ({
        id: q.id || `q_${index}`,
        question: q.question,
        options: q.options || [],
        correctAnswer: q.correctAnswer,
        explanation: q.explanation || '',
        points: q.points || 10,
        difficulty: q.difficulty || 'medium',
        category: q.category || quizData.category || 'general',
        references: q.references || []
      })),
      totalPoints: (quizData.questions || []).reduce((sum: number, q: any) => sum + (q.points || 10), 0),
      timeLimit: quizData.timeLimit,
      isActive: quizData.isActive !== false // default to true
    };

    return quiz;
  } catch (error) {
    console.error('Error fetching quiz:', error);
    throw error;
  }
}

/**
 * Get available quizzes (without questions for listing)
 */
export async function getAvailableQuizzes(): Promise<Omit<Quiz, 'questions'>[]> {
  try {
    const quizzesSnapshot = await db.collection('quiz')
      .where('isActive', '==', true)
      .get();

    const quizzes: Omit<Quiz, 'questions'>[] = [];

    quizzesSnapshot.forEach(doc => {
      const data = doc.data();
      quizzes.push({
        id: doc.id,
        title: data.title || 'Quiz',
        description: data.description || '',
        category: data.category || 'general',
        totalPoints: (data.questions || []).reduce((sum: number, q: any) => sum + (q.points || 10), 0),
        timeLimit: data.timeLimit,
        isActive: data.isActive !== false
      });
    });

    return quizzes;
  } catch (error) {
    console.error('Error fetching available quizzes:', error);
    throw error;
  }
}

/**
 * Submit quiz answers and calculate score
 */
export async function submitQuiz(submission: {
  userId: string;
  quizId: string;
  answers: {
    questionId: string;
    selectedOptionId: string;
    isCorrect: boolean;
    timeSpent: number;
  }[];
  duration: number;
}): Promise<QuizResult> {
  try {
    // Get the quiz to validate answers
    const quiz = await getQuizById(submission.quizId);
    if (!quiz) {
      throw new Error('Quiz not found');
    }

    // Calculate score and prepare result
    let totalScore = 0;
    const resultAnswers: QuizResult['answers'] = [];

    submission.answers.forEach(answer => {
      const question = quiz.questions.find(q => q.id === answer.questionId);
      if (!question) {
        console.log('Question not found for ID:', answer.questionId);
        return; // Skip invalid questions
      }

      // Normalize both values for comparison (remove quotes if present)
      const selectedOption = answer.selectedOptionId?.toString().replace(/['"]/g, '');
      const correctOption = question.correctAnswer?.toString().replace(/['"]/g, '');
      const isCorrect = selectedOption === correctOption;

      // Debug logging for answer validation
      console.log('Validating answer:', {
        questionId: answer.questionId,
        selectedOptionId: answer.selectedOptionId,
        selectedNormalized: selectedOption,
        correctAnswer: question.correctAnswer,
        correctNormalized: correctOption,
        selectedType: typeof answer.selectedOptionId,
        correctType: typeof question.correctAnswer,
        isCorrect
      });

      const pointsEarned = isCorrect ? question.points : 0; // Points actually earned
      totalScore += pointsEarned;

      console.log('Answer result:', {
        questionId: answer.questionId,
        isCorrect,
        pointsEarned,
        totalScoreSoFar: totalScore
      });

      resultAnswers.push({
        questionId: answer.questionId,
        selectedOptionId: answer.selectedOptionId,
        correctOptionId: question.correctAnswer,
        isCorrect,
        explanation: question.explanation,
        points: pointsEarned // Show points actually earned, not total possible points
      });
    });

    const percentage = Math.round((totalScore / quiz.totalPoints) * 100);
    const passed = percentage >= 70; // 70% passing threshold

    const result: QuizResult = {
      score: totalScore,
      totalPoints: quiz.totalPoints,
      percentage,
      passed,
      answers: resultAnswers
    };

    // Save the submission to scores collection
    const scoreDoc = {
      userId: submission.userId,
      quizId: submission.quizId,
      score: totalScore,
      total: quiz.totalPoints,
      percentage,
      passed,
      completedAt: Timestamp.now(),
      duration: submission.duration,
      answers: submission.answers
    };

    await db.collection('scores').add(scoreDoc);

    return result;
  } catch (error) {
    console.error('Error submitting quiz:', error);
    throw error;
  }
}

/**
 * Get user's quiz history
 */
export async function getUserQuizHistory(userId: string, limit: number = 10): Promise<any[]> {
  try {
    const scoresSnapshot = await db.collection('scores')
      .where('userId', '==', userId)
      .orderBy('completedAt', 'desc')
      .limit(limit)
      .get();

    const history: any[] = [];
    scoresSnapshot.forEach(doc => {
      const data = doc.data();
      history.push({
        id: doc.id,
        quizId: data.quizId,
        score: data.score,
        total: data.total,
        percentage: data.percentage,
        passed: data.passed,
        completedAt: data.completedAt.toDate(),
        duration: data.duration
      });
    });

    return history;
  } catch (error) {
    console.error('Error fetching user quiz history:', error);
    throw error;
  }
}

/**
 * Get leaderboard for a specific quiz
 */
export async function getQuizLeaderboard(quizId?: string, limit: number = 50): Promise<any[]> {
  try {
    let query = db.collection('scores')
      .orderBy('score', 'desc')
      .orderBy('completedAt', 'asc');

    if (quizId && quizId !== 'all') {
      query = query.where('quizId', '==', quizId) as any;
    }

    const leaderboardSnapshot = await query.limit(limit).get();

    const leaderboard: any[] = [];
    const userBestScores = new Map<string, any>();

    leaderboardSnapshot.forEach(doc => {
      const data = doc.data();
      const key = quizId === 'all' ? `${data.userId}_${data.quizId}` : data.userId;
      
      // Keep only the best score for each user (per quiz if quizId is 'all')
      if (!userBestScores.has(key) || 
          (data.score / data.total) > (userBestScores.get(key).score / userBestScores.get(key).total)) {
        userBestScores.set(key, {
          userId: data.userId,
          quizId: data.quizId,
          score: data.score,
          total: data.total,
          percentage: Math.round((data.score / data.total) * 100),
          completedAt: data.completedAt.toDate()
        });
      }
    });

    // Convert to array and sort by percentage, then by completion time
    Array.from(userBestScores.values()).forEach(entry => {
      leaderboard.push(entry);
    });

    leaderboard.sort((a, b) => {
      const percentageA = (a.score / a.total) * 100;
      const percentageB = (b.score / b.total) * 100;
      
      if (percentageA !== percentageB) {
        return percentageB - percentageA; // Higher percentage first
      }
      
      return a.completedAt.getTime() - b.completedAt.getTime(); // Earlier completion first for same percentage
    });

    return leaderboard.slice(0, limit);
  } catch (error) {
    console.error('Error fetching quiz leaderboard:', error);
    throw error;
  }
}

/**
 * Validate a single answer in real-time
 */
export async function validateSingleAnswer(
  questionId: string, 
  selectedOptionId: string, 
  quiz: Quiz
): Promise<{
  isCorrect: boolean;
  explanation: string;
  points: number;
  correctOptionId: string;
}> {
  try {
    // Find the question in the quiz
    const question = quiz.questions.find(q => q.id === questionId);
    
    if (!question) {
      throw new Error(`Question with id ${questionId} not found`);
    }

    // Check if the selected option exists
    const selectedOption = question.options.find(opt => opt.id === selectedOptionId);
    if (!selectedOption) {
      throw new Error(`Option with id ${selectedOptionId} not found`);
    }

    // Determine if the answer is correct
    // Compare the selected option ID with the correct answer ID
    const isCorrect = selectedOptionId === question.correctAnswer;

    console.log('Answer validation debug:', {
      questionId,
      selectedOptionId,
      selectedText: selectedOption.text,
      correctAnswer: question.correctAnswer,
      isCorrect,
      correctOptionId: question.correctAnswer
    });

    return {
      isCorrect,
      explanation: question.explanation,
      points: isCorrect ? question.points : 0,
      correctOptionId: question.correctAnswer
    };
  } catch (error) {
    console.error('Error validating single answer:', error);
    throw error;
  }
}
