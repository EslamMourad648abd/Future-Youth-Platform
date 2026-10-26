import 'package:flutter/material.dart';

/// Temporary screen used by every page that is not built yet.
/// Each one names the task in docs/AGENT_TASKS.md that replaces it.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.taskId});

  final String title;
  final String? taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (taskId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Not built yet. See docs/AGENT_TASKS.md, task $taskId.',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
