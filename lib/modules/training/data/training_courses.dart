import '../models/course_model.dart';

class TrainingCourses {

  static const courses = [

    CourseModel(
      id: "1",
      title: "Platform Explanation",
      description: "Introduction to BBC platform concepts.",
      duration: 60,
      driveFolderId: "platform_folder_id",
      driveFolderUrl:
      "https://drive.google.com/platform-folder",
    ),


    CourseModel(
      id: "2",
      title: "Chatbot Explanation",
      description: "How to build a chatbot.",
      duration: 60,
      driveFolderId: "chatbot_folder_id",
      driveFolderUrl:
      "https://drive.google.com/chatbot-folder",
    ),


    CourseModel(
      id: "3",
      title: "Meta FBM Explanation",
      description: "Facebook Business Manager use cases.",
      duration: 60,
      driveFolderId: "meta_folder_id",
      driveFolderUrl:
      "https://drive.google.com/meta-folder",
    ),

    CourseModel(
      id: "4",
      title: "API & HTTP Integration",
      description: "HTTP concepts and API integration.",
      duration: 60,
      driveFolderId: "api_folder_id",
      driveFolderUrl:
      "https://drive.google.com/api-folder",
    ),

    CourseModel(
      id: "5",
      title: "Troubleshooting",
      description: "Root cause analysis and problem solving.",
      duration: 60,
      driveFolderId: "troubleshooting_folder_id",
      driveFolderUrl:
      "https://drive.google.com/troubleshooting-folder",
    ),

  ];


  /// Total number of courses
  static int get totalCourses =>
      courses.length;


  /// Total duration in minutes
  static int get totalDuration =>
      courses.fold(
        0,
            (sum, course) =>
        sum + course.duration,
      );


  /// Temporary until Firebase progress exists
  static double get overallProgress =>
      0;

}