import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingProgressService {

  final FirebaseFirestore firestore;


  TrainingProgressService({
    FirebaseFirestore? firestore,
  }) :
        firestore =
            firestore ?? FirebaseFirestore.instance;



  // =====================================================
  // LESSON PROGRESS REFERENCE
  // =====================================================

  DocumentReference<Map<String,dynamic>> _lessonProgress({

    required String userId,

    required String courseId,

    required String lessonId,

  }) {


    return firestore

        .collection("users")

        .doc(userId)

        .collection("training_progress")

        .doc(courseId)

        .collection("lessons")

        .doc(lessonId);

  }





  // =====================================================
  // CHECK LESSON COMPLETION
  // =====================================================

  Future<bool> isLessonCompleted({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {


    final snapshot =
    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    ).get();



    return snapshot.exists &&
        snapshot.data()?["completed"] == true;

  }





  // =====================================================
  // COMPLETE LESSON
  // =====================================================

  Future<void> completeLesson({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {


    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    )
        .set({

      "completed":true,


      "completedAt":
      FieldValue.serverTimestamp(),


    },

        SetOptions(
          merge:true,
        ));

  }





  // =====================================================
  // CHECK QUIZ SUBMISSION
  // =====================================================

  Future<bool> isQuizSubmitted({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {


    final snapshot =
    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    ).get();



    return snapshot.exists &&

        snapshot.data()?["quizSubmitted"] == true;

  }





  // =====================================================
  // SAVE QUIZ RESULT
  // =====================================================

  Future<void> submitQuiz({

    required String userId,

    required String courseId,

    required String lessonId,

    required int score,

    required bool passed,

    required List<Map<String,dynamic>> answers,

  }) async {



    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    )
        .set({

      "quizSubmitted":true,


      "score":score,


      "passed":passed,


      "answers":answers,


      "submittedAt":
      FieldValue.serverTimestamp(),



      // Quiz submission completes lesson
      "completed":true,


      "completedAt":
      FieldValue.serverTimestamp(),


    },

        SetOptions(
          merge:true,
        ));

  }


// =====================================================
// CHECK VIDEO COMPLETION
// =====================================================

  Future<bool> isVideoCompleted({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {


    final snapshot =
    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    ).get();



    return snapshot.exists &&
        snapshot.data()?["videoCompleted"] == true;

  }





// =====================================================
// COMPLETE VIDEO
// =====================================================

  Future<void> completeVideo({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {


    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    )
        .set({

      "videoCompleted":true,


      "videoCompletedAt":
      FieldValue.serverTimestamp(),


    },

        SetOptions(
          merge:true,
        ));

  }


  // =====================================================
  // GET QUIZ RESULT
  // =====================================================

  Future<Map<String,dynamic>?> getQuizResult({

    required String userId,

    required String courseId,

    required String lessonId,

  }) async {



    final snapshot =
    await _lessonProgress(

      userId:userId,

      courseId:courseId,

      lessonId:lessonId,

    ).get();



    if(!snapshot.exists){

      return null;

    }



    final data =
    snapshot.data();



    if(data?["quizSubmitted"] != true){

      return null;

    }



    return data;

  }


}