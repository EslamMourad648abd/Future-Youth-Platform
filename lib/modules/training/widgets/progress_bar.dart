import 'package:flutter/material.dart';


class ProgressBar extends StatelessWidget {

  final double value;


  const ProgressBar({
    super.key,
    required this.value,
  });


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        LinearProgressIndicator(
          value:value,
          minHeight:8,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          color: theme.colorScheme.primary,
        ),


        const SizedBox(height:5),


        Text(
          "${(value*100).round()}%",
          style: TextStyle(
            fontSize:12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        )

      ],
    );
  }
}