import 'package:flutter/material.dart';


class CourseFormDialog extends StatefulWidget {


  final Function(Map<String,dynamic>) onSave;


  final Map<String,dynamic>? initialData;



  const CourseFormDialog({

    super.key,

    required this.onSave,

    this.initialData,

  });



  @override
  State<CourseFormDialog> createState() =>
      _CourseFormDialogState();

}




class _CourseFormDialogState
    extends State<CourseFormDialog>{


  late TextEditingController titleController;

  late TextEditingController descriptionController;

  late TextEditingController folderIdController;

  late TextEditingController folderUrlController;




  @override
  void initState(){

    super.initState();


    titleController =
        TextEditingController(
          text:
          widget.initialData?["title"] ?? "",
        );


    descriptionController =
        TextEditingController(
          text:
          widget.initialData?["description"] ?? "",
        );



    folderIdController =
        TextEditingController(
          text:
          widget.initialData?["driveFolderId"]
              ??
              "",
        );


    folderUrlController =
        TextEditingController(
          text:
          widget.initialData?["driveFolderUrl"]
              ??
              "",
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

        widget.initialData == null

            ?

        "Add Course"

            :

        "Edit Course",
        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),



      content:

      SingleChildScrollView(

        child:Column(

          mainAxisSize:
          MainAxisSize.min,


          children:[


            TextField(

              controller:titleController,

              decoration:
              const InputDecoration(
                labelText:"Course Title",
              ),

            ),



            TextField(

              controller:
              descriptionController,

              decoration:
              const InputDecoration(
                labelText:"Description",
              ),

            ),





            TextField(

              controller:
              folderIdController,

              decoration:
              const InputDecoration(
                labelText:"Google Drive Folder ID",
              ),

            ),



            TextField(

              controller:
              folderUrlController,

              decoration:
              const InputDecoration(
                labelText:"Google Drive Folder URL",
              ),

            ),


          ],

        ),

      ),



      actions:[


        TextButton(

          onPressed:
              ()=>Navigator.pop(context),

          child:
          Text(
            "Cancel",
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),

        ),



        ElevatedButton(


          onPressed:(){


            widget.onSave({


              "title":
              titleController.text.trim(),



              "description":
              descriptionController.text.trim(),





              "driveFolderId":
              folderIdController.text.trim(),



              "driveFolderUrl":
              folderUrlController.text.trim(),



            });



          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child:
          const Text(
            "Save",
          ),

        ),



      ],


    );


  }



}