import 'package:cloud_firestore/cloud_firestore.dart';

import '../../modules/training/models/lesson_model.dart';
import '../../modules/training/models/quiz_model.dart';
import '../../modules/training/models/quiz_question_model.dart';

class TrainingAdminService {
  final FirebaseFirestore firestore;

  TrainingAdminService({
    FirebaseFirestore? firestore,
  }) : firestore =
      firestore ?? FirebaseFirestore.instance;

  // =====================================================
  // COURSES
  // =====================================================

  Future<void> addCourse({
    required String title,
    required String description,
    required String driveFolderId,
    required String driveFolderUrl,
  }) async {
    await firestore
        .collection("training_courses")
        .add({
      "title": title,
      "description": description,
      "driveFolderId": driveFolderId,
      "driveFolderUrl": driveFolderUrl,
      "lessonsCount": 0,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCourse(
      String id,
      Map<String, dynamic> data,
      ) async {
    await firestore
        .collection("training_courses")
        .doc(id)
        .update(data);
  }

  Future<void> deleteCourse(
      String id,
      ) async {
    await firestore
        .collection("training_courses")
        .doc(id)
        .delete();
  }

  // =====================================================
  // LESSONS
  // =====================================================

  CollectionReference<Map<String, dynamic>> _lessons(
      String courseId,
      ) {
    return firestore
        .collection("training_courses")
        .doc(courseId)
        .collection("lessons");
  }

  Future<List<LessonModel>> getLessons(
      String courseId,
      ) async {
    final snapshot = await _lessons(courseId)
        .orderBy(
      "order",
      descending: false,
    )
        .get();

    return snapshot.docs.map((doc) {
      return LessonModel.fromMap(
        doc.data(),
        doc.id,
      );
    }).toList();
  }

  Future<void> addLesson({
    required String courseId,
    required String title,
    required String description,
    required String videoUrl,
    required int duration,
    required int order,
    required bool quizEnabled,
  }) async {
    await _lessons(courseId).add({
      "courseId": courseId,
      "title": title,
      "description": description,
      "videoUrl": videoUrl,
      "duration": duration,
      "order": order,
      "quizEnabled": quizEnabled,
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _updateLessonsCount(courseId);
  }

  Future<void> updateLesson(
      String courseId,
      String lessonId,
      Map<String, dynamic> data,
      ) async {
    await _lessons(courseId)
        .doc(lessonId)
        .update(data);
  }

  Future<void> deleteLesson(
      String courseId,
      String lessonId,
      ) async {
    await _lessons(courseId)
        .doc(lessonId)
        .delete();

    await _updateLessonsCount(courseId);
  }

  Future<void> _updateLessonsCount(
      String courseId,
      ) async {
    final snapshot = await _lessons(courseId).get();

    await firestore
        .collection("training_courses")
        .doc(courseId)
        .update({
      "lessonsCount": snapshot.docs.length,
    });
  }

  // =====================================================
  // QUIZ
  // =====================================================

  /*
   * One lesson can have ONE quiz.
   *
   * Firestore:
   *
   * training_courses
   *   └── courseId
   *       └── lessons
   *           └── lessonId
   *               └── quiz
   *                   └── quiz
   */

  DocumentReference<Map<String, dynamic>> _quiz(
      String courseId,
      String lessonId,
      ) {
    return _lessons(courseId)
        .doc(lessonId)
        .collection("quiz")
        .doc("quiz");
  }

  // =====================================================
  // CREATE QUIZ
  // =====================================================

  Future<void> createQuiz({
    required String courseId,
    required String lessonId,
    required String title,
    int passingScore = 70,
  }) async {
    await _quiz(
      courseId,
      lessonId,
    ).set({
      "courseId": courseId,
      "lessonId": lessonId,
      "title": title,
      "passingScore": passingScore,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // GET QUIZ
  // =====================================================

  Future<QuizModel?> getQuiz({
    required String courseId,
    required String lessonId,
  }) async {
    final quizSnapshot = await _quiz(
      courseId,
      lessonId,
    ).get();

    if (!quizSnapshot.exists) {
      return null;
    }

    final questionsSnapshot = await _quiz(
      courseId,
      lessonId,
    )
        .collection("questions")
        .orderBy("order")
        .get();

    final questions = questionsSnapshot.docs.map((doc) {
      return QuizQuestionModel.fromMap(
        doc.id,
        doc.data(),
      );
    }).toList();

    return QuizModel.fromMap(
      quizSnapshot.id,
      quizSnapshot.data()!,
      questions,
    );
  }

  // =====================================================
  // UPDATE QUIZ
  // =====================================================

  Future<void> updateQuiz({
    required String courseId,
    required String lessonId,
    required Map<String, dynamic> data,
  }) async {
    await _quiz(
      courseId,
      lessonId,
    ).update({
      ...data,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // DELETE QUIZ
  // =====================================================

  Future<void> deleteQuiz({
    required String courseId,
    required String lessonId,
  }) async {
    final quizReference = _quiz(
      courseId,
      lessonId,
    );

    final questionsSnapshot = await quizReference
        .collection("questions")
        .get();

    final batch = firestore.batch();

    for (final question in questionsSnapshot.docs) {
      batch.delete(question.reference);
    }

    batch.delete(quizReference);

    await batch.commit();
  }

  // =====================================================
  // QUESTIONS
  // =====================================================

  CollectionReference<Map<String, dynamic>> _questions(
      String courseId,
      String lessonId,
      ) {
    return _quiz(
      courseId,
      lessonId,
    ).collection("questions");
  }

  // =====================================================
  // ADD QUESTION
  // =====================================================

  Future<String> addQuestion({
    required String courseId,
    required String lessonId,
    required String question,
    required List<String> options,
    required int correctAnswerIndex,
    required int order,
  }) async {
    final questionReference =
    await _questions(
      courseId,
      lessonId,
    ).add({
      "question": question,
      "options": options,
      "correctAnswerIndex": correctAnswerIndex,
      "order": order,
      "createdAt": FieldValue.serverTimestamp(),
    });

    return questionReference.id;
  }

  // =====================================================
  // GET QUESTIONS
  // =====================================================

  Future<List<QuizQuestionModel>> getQuestions({
    required String courseId,
    required String lessonId,
  }) async {
    final snapshot = await _questions(
      courseId,
      lessonId,
    )
        .orderBy("order")
        .get();

    return snapshot.docs.map((doc) {
      return QuizQuestionModel.fromMap(
        doc.id,
        doc.data(),
      );
    }).toList();
  }

  // =====================================================
  // UPDATE QUESTION
  // =====================================================

  Future<void> updateQuestion({
    required String courseId,
    required String lessonId,
    required String questionId,
    required Map<String, dynamic> data,
  }) async {
    await _questions(
      courseId,
      lessonId,
    )
        .doc(questionId)
        .update(data);
  }

  // =====================================================
  // DELETE QUESTION
  // =====================================================

  Future<void> deleteQuestion({
    required String courseId,
    required String lessonId,
    required String questionId,
  }) async {
    await _questions(
      courseId,
      lessonId,
    )
        .doc(questionId)
        .delete();
  }
}