import 'package:flutter/material.dart';

import '../../modules/training/models/quiz_question_model.dart';
import '../services/training_admin_service.dart';



class QuizFormDialog extends StatefulWidget {

  final String courseId;
  final String lessonId;


  const QuizFormDialog({
    super.key,
    required this.courseId,
    required this.lessonId,
  });



  @override
  State<QuizFormDialog> createState() =>
      _QuizFormDialogState();

}





class _QuizFormDialogState
    extends State<QuizFormDialog> {


  final TrainingAdminService adminService =
  TrainingAdminService();



  final quizTitleController =
  TextEditingController();


  final passingScoreController =
  TextEditingController(
    text: "70",
  );



  final questionController =
  TextEditingController();


  final optionAController =
  TextEditingController();


  final optionBController =
  TextEditingController();


  final optionCController =
  TextEditingController();


  final optionDController =
  TextEditingController();



  bool loading = true;

  bool saving = false;

  bool quizExists = false;



  int correctAnswerIndex = 0;



  List<QuizQuestionModel> questions = [];



  QuizQuestionModel? editingQuestion;






  @override
  void initState() {

    super.initState();

    _loadQuiz();

  }





  @override
  void dispose() {

    quizTitleController.dispose();

    passingScoreController.dispose();

    questionController.dispose();

    optionAController.dispose();

    optionBController.dispose();

    optionCController.dispose();

    optionDController.dispose();


    super.dispose();

  }






  Future _loadQuiz() async {


    final quiz =
    await adminService.getQuiz(

      courseId:
      widget.courseId,

      lessonId:
      widget.lessonId,

    );



    if (!mounted) return;



    if (quiz != null) {


      quizExists = true;


      quizTitleController.text =
          quiz.title;


      passingScoreController.text =
          quiz.passingScore.toString();



      questions =
          quiz.questions;


    }



    setState(() {

      loading = false;

    });


  }








  Future _saveQuiz() async {


    if (quizTitleController.text
        .trim()
        .isEmpty) {

      return;

    }



    setState(() {

      saving = true;

    });



    if (!quizExists) {


      await adminService.createQuiz(

        courseId:
        widget.courseId,

        lessonId:
        widget.lessonId,

        title:
        quizTitleController.text.trim(),

        passingScore:
        int.tryParse(
          passingScoreController.text,
        ) ??
            70,

      );


    }




    for(final question in questions){


      if(question.id.isEmpty){


        await adminService.addQuestion(

          courseId:
          widget.courseId,

          lessonId:
          widget.lessonId,

          question:
          question.question,

          options:
          question.options,

          correctAnswerIndex:
          question.correctAnswerIndex,

          order:
          question.order,

        );


      }

    }





    if(!mounted) return;



    setState(() {

      saving = false;

      quizExists = true;

    });



    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(

        content:
        Text(
          "Quiz saved successfully",
        ),

      ),

    );



  }









  Future _updateQuestion(
      QuizQuestionModel question,
      ) async {



    if(question.id.isEmpty){

      return;

    }



    await adminService.updateQuestion(

      courseId:
      widget.courseId,

      lessonId:
      widget.lessonId,

      questionId:
      question.id,

      data: {


        "question":
        questionController.text.trim(),


        "options":[

          optionAController.text.trim(),

          optionBController.text.trim(),

          optionCController.text.trim(),

          optionDController.text.trim(),

        ],


        "correctAnswerIndex":
        correctAnswerIndex,


      },

    );





    final index =
    questions.indexWhere(
          (q) =>
      q.id == question.id,
    );



    if(index != -1){


      questions[index] =
          question.copyWith(

            question:
            questionController.text.trim(),

            options:[

              optionAController.text.trim(),

              optionBController.text.trim(),

              optionCController.text.trim(),

              optionDController.text.trim(),

            ],


            correctAnswerIndex:
            correctAnswerIndex,

          );


    }




    _clearQuestionForm();



    setState(() {

      editingQuestion = null;

    });



  }








  void _editQuestion(
      QuizQuestionModel question,
      ) {


    setState(() {


      editingQuestion =
          question;



      questionController.text =
          question.question;



      optionAController.text =
      question.options[0];


      optionBController.text =
      question.options[1];


      optionCController.text =
      question.options[2];


      optionDController.text =
      question.options[3];



      correctAnswerIndex =
          question.correctAnswerIndex;



    });


  }







  void _saveQuestion() {


    if(questionController.text
        .trim()
        .isEmpty){

      return;

    }




    if(editingQuestion != null){


      _updateQuestion(
          editingQuestion!
      );


      return;

    }






    setState(() {


      questions.add(

        QuizQuestionModel(

          id:"",

          question:
          questionController.text.trim(),


          options:[

            optionAController.text.trim(),

            optionBController.text.trim(),

            optionCController.text.trim(),

            optionDController.text.trim(),

          ],


          correctAnswerIndex:
          correctAnswerIndex,


          order:
          questions.length + 1,

        ),

      );


    });



    _clearQuestionForm();


  }







  void _clearQuestionForm(){

    questionController.clear();

    optionAController.clear();

    optionBController.clear();

    optionCController.clear();

    optionDController.clear();


    correctAnswerIndex = 0;


  }









  InputDecoration _decoration(
      String label,
      ){

    return InputDecoration(

      labelText:
      label,


      border:
      OutlineInputBorder(

        borderRadius:
        BorderRadius.circular(12),

      ),

    );

  }









  Widget _questionForm(){


    return Column(

      mainAxisSize:
      MainAxisSize.min,


      children:[


        TextField(

          controller:
          questionController,

          maxLines:
          2,

          decoration:
          _decoration(
              "Question"
          ),

        ),



        const SizedBox(
          height:12,
        ),



        TextField(

          controller:
          optionAController,

          decoration:
          _decoration(
              "Option A"
          ),

        ),



        const SizedBox(
          height:12,
        ),



        TextField(

          controller:
          optionBController,

          decoration:
          _decoration(
              "Option B"
          ),

        ),



        const SizedBox(
          height:12,
        ),



        TextField(

          controller:
          optionCController,

          decoration:
          _decoration(
              "Option C"
          ),

        ),



        const SizedBox(
          height:12,
        ),



        TextField(

          controller:
          optionDController,

          decoration:
          _decoration(
              "Option D"
          ),

        ),




        const SizedBox(
          height:12,
        ),




        DropdownButtonFormField<int>(


          initialValue:
          correctAnswerIndex,


          decoration:
          _decoration(
              "Correct Answer"
          ),


          items:

          const [

            DropdownMenuItem(
              value:0,
              child:Text("Option A"),
            ),

            DropdownMenuItem(
              value:1,
              child:Text("Option B"),
            ),

            DropdownMenuItem(
              value:2,
              child:Text("Option C"),
            ),

            DropdownMenuItem(
              value:3,
              child:Text("Option D"),
            ),

          ],


          onChanged:(value){

            setState(() {

              correctAnswerIndex =
                  value ?? 0;

            });

          },


        ),




        const SizedBox(
          height:20,
        ),




        ElevatedButton.icon(

          onPressed:
          _saveQuestion,


          icon:
          Icon(

            editingQuestion == null
                ? Icons.add
                : Icons.edit,

          ),


          label:
          Text(

            editingQuestion == null
                ? "Add Question"
                : "Update Question",

          ),


        ),





        if(editingQuestion != null)


          TextButton(

            onPressed:(){

              setState(() {

                editingQuestion = null;

              });


              _clearQuestionForm();

            },


            child:
            const Text(
                "Cancel Edit"
            ),

          ),






        const SizedBox(
          height:20,
        ),





        ...questions.map(

              (q)=>Card(

            child:ListTile(


              title:
              Text(
                  q.question
              ),



              subtitle:
              Text(

                "Correct: ${q.options[q.correctAnswerIndex]}",

              ),




              trailing:
              Row(

                mainAxisSize:
                MainAxisSize.min,


                children:[


                  IconButton(

                    icon:
                    const Icon(
                        Icons.edit,
                        color:
                        Colors.blue
                    ),


                    onPressed:(){

                      _editQuestion(q);

                    },

                  ),




                  IconButton(

                    icon:
                    const Icon(
                        Icons.delete,
                        color:
                        Colors.red
                    ),


                    onPressed:(){

                      setState(() {

                        questions.remove(q);

                      });


                    },

                  ),


                ],

              ),


            ),

          ),

        ),


      ],

    );


  }







  @override
  Widget build(BuildContext context){
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      surfaceTintColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      title:
      Text(
          "Quiz Manager",
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),


      content:

      SizedBox(

        width:450,


        child:

        loading

            ?

        Center(
          child:
          CircularProgressIndicator(color: theme.colorScheme.primary),
        )


            :

        SingleChildScrollView(

          child:

          Column(

            mainAxisSize:
            MainAxisSize.min,


            children:[


              TextField(

                controller:
                quizTitleController,


                decoration:
                _decoration(
                    "Quiz Title"
                ),

              ),



              const SizedBox(
                height:12,
              ),



              TextField(

                controller:
                passingScoreController,


                keyboardType:
                TextInputType.number,


                decoration:
                _decoration(
                    "Passing Score"
                ),

              ),



              const SizedBox(
                height:20,
              ),



              _questionForm(),



            ],

          ),

        ),

      ),





      actions:[


        TextButton(

          onPressed:(){

            Navigator.pop(context);

          },

          child:
          Text(
              "Close",
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),

        ),





        ElevatedButton(

          onPressed:
          saving
              ? null
              : _saveQuiz,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),

          child:
          saving

              ?

          const SizedBox(

            width:18,

            height:18,

            child:
            CircularProgressIndicator(
              strokeWidth:2,
              color: Colors.white,
            ),

          )


              :

          const Text(
              "Save Quiz"
          ),


        ),


      ],


    );


  }


}