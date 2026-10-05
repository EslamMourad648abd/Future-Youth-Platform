import 'package:flutter/material.dart';

class OnboardingActivity extends StatelessWidget {
  const OnboardingActivity({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Operational activity and audit history.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(14),
                border: Border.all(
                  color:
                  const Color(0xFFE6EDF3),
                ),
              ),
              child: const Center(
                child: Text(
                  'Activity history will be implemented here.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}