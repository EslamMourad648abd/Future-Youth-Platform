import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_model.dart';
import '../models/lesson_model.dart';
import 'training_repository.dart';

class FirebaseTrainingRepository
    implements TrainingRepository {

  final FirebaseFirestore firestore;

  FirebaseTrainingRepository({
    FirebaseFirestore? firestore,
  }) : firestore =
      firestore ?? FirebaseFirestore.instance;

  // =====================================================
  // COURSES
  // =====================================================

  @override
  Future<List<CourseModel>> getCourses() async {
    final snapshot = await firestore
        .collection("training_courses")
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return CourseModel(
        id: doc.id,
        title: data["title"] ?? "",
        description: data["description"] ?? "",
        duration: data["duration"] ?? 0,
        driveFolderId:
        data["driveFolderId"] ?? "",
        driveFolderUrl:
        data["driveFolderUrl"] ?? "",
        lessonsCount:
        data["lessonsCount"] ?? 0,
      );
    }).toList();
  }

  // =====================================================
  // LESSONS
  // =====================================================

  Future<List<LessonModel>> getLessons(
      String courseId,
      ) async {
    final snapshot = await firestore
        .collection("training_courses")
        .doc(courseId)
        .collection("lessons")
        .orderBy("order")
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return LessonModel(
        id: doc.id,
        courseId:
        data["courseId"] ?? courseId,
        title:
        data["title"] ?? "",
        description:
        data["description"] ?? "",
        videoUrl:
        data["videoUrl"] ?? "",
        duration:
        data["duration"] ?? 0,
        order:
        data["order"] ?? 0,
        quizEnabled:
        data["quizEnabled"] ?? false,
      );
    }).toList();
  }

  Future<void> addLesson(
      String courseId,
      LessonModel lesson,
      ) async {
    await firestore
        .collection("training_courses")
        .doc(courseId)
        .collection("lessons")
        .doc(lesson.id)
        .set({
      "courseId": lesson.courseId,
      "title": lesson.title,
      "description": lesson.description,
      "videoUrl": lesson.videoUrl,
      "duration": lesson.duration,
      "order": lesson.order,
      "quizEnabled": lesson.quizEnabled,
    });
  }

  Future<void> deleteLesson(
      String courseId,
      String lessonId,
      ) async {
    await firestore
        .collection("training_courses")
        .doc(courseId)
        .collection("lessons")
        .doc(lessonId)
        .delete();
  }
}