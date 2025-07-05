import * as admin from 'firebase-admin';
import * as quizService from '../services/quizService';

// Initialize Firebase Admin for testing
if (!admin.apps.length) {
  admin.initializeApp();
}

// Test data
const testQuizId = 'consumer_affairs_quiz';
const testUserId = 'test_user_123';

async function runTests() {
  console.log('🧪 Running Quiz Service Tests...\n');

  try {
    // Test 1: Get Available Quizzes
    console.log('1️⃣ Testing getAvailableQuizzes...');
    const quizzes = await quizService.getAvailableQuizzes();
    console.log(`✅ Found ${quizzes.length} available quizzes`);
    if (quizzes.length > 0) {
      console.log(`   First quiz: ${quizzes[0].title} (${quizzes[0].id})`);
    }
    console.log('');

    // Test 2: Get Specific Quiz
    console.log('2️⃣ Testing getQuizById...');
    const quiz = await quizService.getQuizById(testQuizId);
    if (quiz) {
      console.log(`✅ Quiz loaded: ${quiz.title}`);
      console.log(`   Questions: ${quiz.questions.length}`);
      console.log(`   Total Points: ${quiz.totalPoints}`);
      console.log(`   Category: ${quiz.category}`);
    } else {
      console.log(`❌ Quiz not found: ${testQuizId}`);
      console.log('   Make sure the quiz exists in Firestore');
      return;
    }
    console.log('');

    // Test 3: Submit Quiz (if quiz exists)
    if (quiz && quiz.questions.length > 0) {
      console.log('3️⃣ Testing submitQuiz...');
      
      // Create test answers (answer first option for all questions)
      const testAnswers = quiz.questions.map((question, index) => ({
        questionId: question.id,
        selectedOptionId: question.options[0].id,
        isCorrect: question.options[0].id === question.correctAnswer,
        timeSpent: 10 + index * 5 // Simulate different time spent per question
      }));

      const testSubmission = {
        userId: testUserId,
        quizId: testQuizId,
        answers: testAnswers,
        duration: 300 // 5 minutes
      };

      const result = await quizService.submitQuiz(testSubmission);
      console.log(`✅ Quiz submitted successfully`);
      console.log(`   Score: ${result.score}/${result.totalPoints}`);
      console.log(`   Percentage: ${result.percentage}%`);
      console.log(`   Passed: ${result.passed}`);
      console.log(`   Correct Answers: ${result.answers.filter(a => a.isCorrect).length}`);
      console.log('');
    }

    // Test 4: Get User History
    console.log('4️⃣ Testing getUserQuizHistory...');
    const history = await quizService.getUserQuizHistory(testUserId, 5);
    console.log(`✅ Found ${history.length} quiz attempts for user`);
    if (history.length > 0) {
      const latest = history[0];
      console.log(`   Latest: ${latest.quizId} - ${latest.score}/${latest.total} (${Math.round((latest.score/latest.total)*100)}%)`);
    }
    console.log('');

    // Test 5: Get Leaderboard
    console.log('5️⃣ Testing getQuizLeaderboard...');
    const leaderboard = await quizService.getQuizLeaderboard(testQuizId, 10);
    console.log(`✅ Leaderboard has ${leaderboard.length} entries`);
    if (leaderboard.length > 0) {
      const top = leaderboard[0];
      console.log(`   Top score: ${top.score}/${top.total} (${top.percentage}%) by ${top.userId}`);
    }
    console.log('');

    // Test 6: Get Overall Leaderboard
    console.log('6️⃣ Testing getQuizLeaderboard (all quizzes)...');
    const overallLeaderboard = await quizService.getQuizLeaderboard('all', 10);
    console.log(`✅ Overall leaderboard has ${overallLeaderboard.length} entries`);
    console.log('');

    console.log('🎉 All tests completed successfully!');
    console.log('');
    console.log('📝 Test Summary:');
    console.log('   ✅ Quiz retrieval');
    console.log('   ✅ Quiz submission');
    console.log('   ✅ User history');
    console.log('   ✅ Leaderboards');
    console.log('');
    console.log('🚀 Your Firebase functions are ready to use!');

  } catch (error) {
    console.error('❌ Test failed:', error);
    console.error('');
    console.error('🔧 Troubleshooting tips:');
    console.error('   1. Make sure Firebase Admin is properly initialized');
    console.error('   2. Check that the quiz collection exists in Firestore');
    console.error('   3. Verify your Firestore security rules allow the operations');
    console.error('   4. Ensure the quiz document has the correct structure');
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runTests().then(() => {
    process.exit(0);
  }).catch((error) => {
    console.error('Test execution failed:', error);
    process.exit(1);
  });
}

export { runTests };
