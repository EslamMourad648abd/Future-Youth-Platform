import 'lesson_model.dart';

class CourseModel {

  final String id;
  final String title;
  final String description;

  final int duration;

  final String driveFolderId;
  final String driveFolderUrl;
  final int lessonsCount;



  const CourseModel({

    required this.id,
    required this.title,
    required this.description,

    required this.duration,

    required this.driveFolderId,
    required this.driveFolderUrl,
    this.lessonsCount = 0,

  });
  factory CourseModel.fromMap(
      Map<String, dynamic> data,
      String id,
      ) {


    return CourseModel(

      id: id,

      title:
      data["title"] ?? "",


      description:
      data["description"] ?? "",


      duration:
      data["duration"] ?? "",


      driveFolderId:
      data["driveFolderId"] ?? "",


      driveFolderUrl:
      data["driveFolderUrl"] ?? "",


      lessonsCount:
      data["lessonsCount"] ?? 0,

    );

  }



  Map<String,dynamic> toMap(){


    return {

      "title": title,

      "description": description,

      "duration": duration,

      "driveFolderId": driveFolderId,

      "driveFolderUrl": driveFolderUrl,

      "lessonsCount": lessonsCount,

    };

  }


}