import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/api_preset.dart';
import '../services/localization_service.dart';

class RequestEditor extends StatefulWidget {
  final ApiPreset preset;
  const RequestEditor({super.key, required this.preset});

  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  late TextEditingController bodyController;
  late TextEditingController tokenController;
  late List<Map<String, String>> headers;
  late List<Map<String, String>> params;
  final Map<String, TextEditingController> _urlControllers = {};
  String responseText = '';
  int? statusCode;
  bool loading = false;
  String editableBody = '';
  final Map<String, String> _bodyInputs = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    headers = widget.preset.headers.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
    params = widget.preset.params.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
    editableBody = widget.preset.body ?? '';
    bodyController = TextEditingController(text: editableBody);
    tokenController = TextEditingController();
    if (widget.preset.authToken != null && widget.preset.authToken!.isNotEmpty && widget.preset.authToken != '[TOKEN]') {
      tokenController.text = widget.preset.authToken!;
    }
    for (var v in widget.preset.urlVariables) { _urlControllers[v] = TextEditingController(); }
  }

  @override
  void didUpdateWidget(covariant RequestEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.preset, oldWidget.preset)) {
      bodyController.dispose();
      tokenController.dispose();
      _urlControllers.forEach((_, c) => c.dispose());
      _urlControllers.clear();
      setState(() { _initControllers(); responseText = ''; statusCode = null; });
    }
  }

  String _buildFinalUrl() {
    String url = widget.preset.url;
    _urlControllers.forEach((key, controller) { url = url.replaceAll('[$key]', controller.text.trim()); });
    return url;
  }

  Map<String, String> _buildFinalHeaders() {
    final Map<String, String> result = {};
    for (var h in headers) {
      final key = h['key'] ?? '';
      var value = h['value'] ?? '';
      if (value.contains('[TOKEN]')) { value = value.replaceAll('[TOKEN]', tokenController.text.trim()); }
      result[key] = value;
    }
    if (widget.preset.authType == 'bearer' && tokenController.text.isNotEmpty) { result['Authorization'] = 'Bearer ${tokenController.text.trim()}'; }
    result['Content-Type'] = 'application/json';
    return result;
  }

  String _buildFinalBody() {
    String updated = editableBody;
    _bodyInputs.forEach((p, v) { updated = updated.replaceAll(RegExp(r'\[\s*' + RegExp.escape(p) + r'\s*\]'), v); });
    try { return jsonEncode(jsonDecode(updated)); } catch (_) { return updated; }
  }

  Future<void> sendRequest() async {
    setState(() { loading = true; responseText = ''; statusCode = null; });
    try {
      final proxyUri = Uri.parse("https://us-central1-bbc-api-tool.cloudfunctions.net/bevatelProxy");
      final payload = {
        "url": _buildFinalUrl(),
        "method": widget.preset.method.toUpperCase(),
        "headers": _buildFinalHeaders(),
        if (widget.preset.body != null) "body": jsonDecode(_buildFinalBody()),
      };
      final resp = await http.post(proxyUri, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
      if (mounted) setState(() { loading = false; statusCode = resp.statusCode; responseText = _prettyJson(resp.body); });
    } catch (e) { if (mounted) setState(() { loading = false; responseText = "Error: $e"; }); }
  }

  String _prettyJson(String raw) { try { return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw)); } catch (_) { return raw; } }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Center(child: ElevatedButton.icon(onPressed: sendRequest, icon: const Icon(Icons.send), label: Text(l10n?.translate('send') ?? 'Send'), style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary))),
        const SizedBox(height: 16),
        Expanded(child: ListView(children: [
          if (widget.preset.requiresToken || widget.preset.authType == 'bearer') _Section(title: l10n?.translate('authorization') ?? "Authorization", child: TextField(controller: tokenController, decoration: InputDecoration(labelText: l10n?.translate('bearer_token') ?? "Bearer Token", border: const OutlineInputBorder()))),
          if (widget.preset.urlVariables.isNotEmpty) _Section(title: l10n?.translate('url_variables') ?? "URL Variables", child: Column(children: widget.preset.urlVariables.map((v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: TextField(controller: _urlControllers[v], decoration: InputDecoration(labelText: v, border: const OutlineInputBorder())))).toList())),
          _keyValueEditor(l10n?.translate('headers') ?? "Headers", headers, context),
          if (widget.preset.body != null && widget.preset.body!.contains('[')) _Section(title: l10n?.translate('body_placeholders') ?? "Body Placeholders", child: Column(children: RegExp(r'\[(.*?)\]').allMatches(widget.preset.body!).map((m) {
            final p = m.group(1)!.trim();
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextFormField(decoration: InputDecoration(labelText: p, border: const OutlineInputBorder()), onChanged: (v) => _bodyInputs[p] = v));
          }).toList())),
          const SizedBox(height: 20),
          if (loading) const Center(child: CircularProgressIndicator())
          else if (responseText.isNotEmpty) _Section(title: l10n?.translate('response') ?? "Response", trailing: statusCode != null ? _StatusBadge(code: statusCode!) : null, child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)), child: Directionality(textDirection: TextDirection.ltr, child: SelectableText(responseText, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: theme.colorScheme.onSurface))))),
        ])),
      ]),
    );
  }

  Widget _keyValueEditor(String title, List<Map<String, String>> list, BuildContext context) {
    return _Section(title: title, child: Column(children: [
      for (var item in list) if (item['value']!.contains('[')) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        Expanded(child: TextField(controller: TextEditingController(text: item['key']), readOnly: true, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: TextEditingController(text: item['value']), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onChanged: (v) => item['value'] = v)),
      ])),
    ]));
  }
}

class _Section extends StatelessWidget {
  final String title; final Widget child; final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (trailing != null) ...[const SizedBox(width: 12), trailing!]]),
      const SizedBox(height: 12), child,
    ])));
  }
}

class _StatusBadge extends StatelessWidget {
  final int code; const _StatusBadge({required this.code});
  @override Widget build(BuildContext context) {
    final ok = code >= 200 && code < 300;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ok ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(10)), child: Text("$code", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)));
  }
}
