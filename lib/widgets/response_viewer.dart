import 'dart:convert';
import 'package:flutter/material.dart';

class ResponseViewer extends StatelessWidget {
  final int? statusCode;
  final String body;
  final Map<String, String> headers;
  final bool loading;

  const ResponseViewer({
    super.key,
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.loading,
  });

  String _prettyJson(String input) {
    try {
      final jsonObj = jsonDecode(input);
      return const JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (_) {
      return input;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (statusCode != null)
        Text('Status: $statusCode', style: TextStyle(color: statusCode! >= 200 && statusCode! < 300 ? Colors.green : Colors.red)),
      const SizedBox(height: 8),
      const Text('Response:'),
      Expanded(
        child: SingleChildScrollView(
          child: SelectableText(_prettyJson(body), style: const TextStyle(fontFamily: 'monospace')),
        ),
      ),
    ]);
  }
}
