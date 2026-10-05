class QuizQuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final int order;

  const QuizQuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.order,
  });

  // =====================================================
  // FROM FIRESTORE
  // =====================================================

  factory QuizQuestionModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return QuizQuestionModel(
      id: id,
      question: data['question'] ?? '',
      options: List<String>.from(
        data['options'] ?? [],
      ),
      correctAnswerIndex:
      data['correctAnswerIndex'] ?? 0,
      order:
      data['order'] ?? 0,
    );
  }

  // =====================================================
  // TO FIRESTORE
  // =====================================================

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'order': order,
    };
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  QuizQuestionModel copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    int? order,
  }) {
    return QuizQuestionModel(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswerIndex:
      correctAnswerIndex ?? this.correctAnswerIndex,
      order: order ?? this.order,
    );
  }
}