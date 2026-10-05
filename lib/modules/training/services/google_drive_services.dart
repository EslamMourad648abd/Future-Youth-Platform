import '../models/lesson_model.dart';

class GoogleDriveService {
  // ============================================================
  // GOOGLE DRIVE URL HELPERS
  // ============================================================

  /// Creates a Google Drive preview URL.
  ///
  /// Example:
  /// https://drive.google.com/file/d/FILE_ID/preview
  static String previewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/preview';
  }

  /// Creates a Google Drive view URL.
  ///
  /// Example:
  /// https://drive.google.com/file/d/FILE_ID/view
  static String viewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  /// Creates a direct Google Drive download URL.
  ///
  /// This is mainly useful for downloadable files.
  static String downloadUrl(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  // ============================================================
  // GET LESSONS
  // ============================================================

  Future<List<LessonModel>> getLessonsFromFolder(
      String folderId,
      ) async {
    /*
      Temporary mock data.

      Later this will become:

      Flutter
          |
          ↓
      Backend / API
          |
          ↓
      Google Drive API
          |
          ↓
      Files inside folder
          |
          ↓
      File ID + metadata
          |
          ↓
      Flutter

      IMPORTANT:
      The videoUrl should contain the REAL Google Drive
      file ID returned by the backend.

      Example:

      final fileId = '1AbCdEfGhIjKlMnOp';

      videoUrl:
          GoogleDriveService.previewUrl(fileId)

      Result:

      https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/preview
    */

    return [
      LessonModel(
        id: '1',
        title: 'Introduction to BBC',

        videoUrl: previewUrl(
          'REPLACE_WITH_REAL_DRIVE_FILE_ID_1',
        ),

        description: '',
        order: 1,
        courseId: '',
        quizEnabled: true,
        duration: 1,
      ),

      LessonModel(
        id: '2',
        title: 'Platform Navigation',

        videoUrl: previewUrl(
          'REPLACE_WITH_REAL_DRIVE_FILE_ID_2',
        ),

        description: '',
        order: 2,
        courseId: '',
        quizEnabled: true,
        duration: 1,
      ),

      LessonModel(
        id: '3',
        title: 'Customer Journey',

        videoUrl: previewUrl(
          'REPLACE_WITH_REAL_DRIVE_FILE_ID_3',
        ),

        description: '',
        order: 3,
        courseId: '',
        quizEnabled: true,
        duration: 1,
      ),
    ];
  }
}