import 'quiz_question_model.dart';


class QuizModel {
  final String id;
  final String courseId;
  final String lessonId;
  final String title;
  final int passingScore;
  final List<QuizQuestionModel> questions;

  const QuizModel({
    required this.id,
    required this.courseId,
    required this.lessonId,
    required this.title,
    required this.passingScore,
    required this.questions,
  });

  // =====================================================
  // FROM FIRESTORE
  // =====================================================

  factory QuizModel.fromMap(
      String id,
      Map<String, dynamic> data,
      List<QuizQuestionModel> questions,
      ) {
    return QuizModel(
      id: id,
      courseId:
      data['courseId'] ?? '',
      lessonId:
      data['lessonId'] ?? '',
      title:
      data['title'] ?? 'Lesson Quiz',
      passingScore:
      data['passingScore'] ?? 70,
      questions:
      questions,
    );
  }

  // =====================================================
  // TO FIRESTORE
  // =====================================================

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'lessonId': lessonId,
      'title': title,
      'passingScore': passingScore,
    };
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  QuizModel copyWith({
    String? id,
    String? courseId,
    String? lessonId,
    String? title,
    int? passingScore,
    List<QuizQuestionModel>? questions,
  }) {
    return QuizModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      passingScore:
      passingScore ?? this.passingScore,
      questions:
      questions ?? this.questions,
    );
  }
}