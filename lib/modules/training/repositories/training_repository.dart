import '../models/course_model.dart';


abstract class TrainingRepository {


  Future<List<CourseModel>> getCourses();


}