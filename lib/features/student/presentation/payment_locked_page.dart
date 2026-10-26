import 'package:flutter/material.dart';

/// Shown to a student whose parent has not paid yet: only a loading screen,
/// until the payment is confirmed (see docs/REQUIREMENTS.md, FR-10).
/// Task T12 makes it react to the subscription status in real time.
class PaymentLockedPage extends StatelessWidget {
  const PaymentLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Your account will open as soon as the payment is confirmed.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
