import 'package:flutter/material.dart';

class TrainingStatCard extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;


  const TrainingStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });


  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),

        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
          )
        ],
      ),

      child: Row(

        children: [

          CircleAvatar(
            backgroundColor: const Color(0xff80CFFF),
            child: Icon(
              icon,
              color: Color(0xff003366),
            ),
          ),


          const SizedBox(width:15),


          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                value,
                style: const TextStyle(
                  fontSize:22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff003366),
                ),
              ),


              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              )

            ],
          )

        ],
      ),
    );
  }
}