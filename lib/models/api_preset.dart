import 'dart:convert';

class ApiPreset {
  final String id;
  final String name;
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> params;
  final String? body;
  final Map<String, bool> editableFields;
  final List<String> urlVariables;

  // ============================================================
  // AUTH
  // ============================================================

  final String? authType;
  final String? authToken;

  bool get requiresToken =>
      headers.values.any((v) => v.contains('[TOKEN]')) ||
          (authToken?.contains('[') ?? false);

  ApiPreset({
    required this.id,
    required this.name,
    required this.method,
    required this.url,
    required this.headers,
    required this.params,
    this.body,
    required this.editableFields,
    required this.urlVariables,
    this.authType,
    this.authToken,
  });

  // ============================================================
  // PLACEHOLDER
  // ============================================================

  static bool _hasPlaceholder(String value) {
    final regex = RegExp(r'\[(.*?)\]');
    return regex.hasMatch(value);
  }

  static Map<String, bool> _extractEditableMap(
      Map<String, String> fields,
      ) {
    final map = <String, bool>{};

    for (final entry in fields.entries) {
      map[entry.key] = _hasPlaceholder(entry.value);
    }

    return map;
  }

  // ============================================================
  // AUTH EXTRACTION
  // ============================================================

  static Map<String, dynamic> _extractAuth(
      Map<String, dynamic>? auth,
      ) {
    if (auth == null) {
      return {};
    }

    final type = auth['type']?.toString();

    if (type == 'bearer' && auth['bearer'] is List) {
      final bearerList = auth['bearer'] as List;

      for (final item in bearerList) {
        if (item is Map) {
          final value = item['value'];

          if (value != null) {
            return {
              'type': type,
              'token': value.toString(),
            };
          }
        }
      }
    }

    return {};
  }

  // ============================================================
  // POSTMAN PARSER
  // ============================================================

  factory ApiPreset.fromPostman(
      Map<String, dynamic> json,
      ) {
    final request =
    json['request'] is Map<String, dynamic>
        ? json['request'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawUrl = request['url'];

    // ==========================================================
    // HEADERS
    // ==========================================================

    final rawHeaders =
        (request['header'] as List?)
            ?.map(
              (h) => MapEntry(
            (h['key'] ?? '').toString(),
            (h['value'] ?? '').toString(),
          ),
        )
            .where(
              (entry) => entry.key.isNotEmpty,
        )
            .toList() ??
            [];

    final headers =
    Map<String, String>.fromEntries(rawHeaders);

    // ==========================================================
    // QUERY PARAMS
    // ==========================================================

    final params = <String, String>{};

    if (rawUrl is Map &&
        rawUrl['query'] is List) {
      for (final q in rawUrl['query']) {
        if (q is Map) {
          final key =
          (q['key'] ?? '').toString();

          final value =
          (q['value'] ?? '').toString();

          if (key.isNotEmpty) {
            params[key] = value;
          }
        }
      }
    }

    // ==========================================================
    // BODY
    // ==========================================================

    String? body;

    final rawBody = request['body'];

    if (rawBody is Map &&
        rawBody['raw'] != null) {
      body = rawBody['raw'].toString();
    }

    // ==========================================================
    // URL
    // ==========================================================

    final urlRaw =
        (rawUrl is Map
            ? rawUrl['raw']
            : rawUrl)
            ?.toString() ??
            '';

    // ==========================================================
    // URL VARIABLES
    // ==========================================================

    final urlVariables =
    RegExp(r'\[(.*?)\]')
        .allMatches(urlRaw)
        .map(
          (match) =>
      match.group(1) ?? '',
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toList();

    // ==========================================================
    // EDITABLE FIELDS
    // ==========================================================

    final editableMap = {
      ..._extractEditableMap(headers),
      ..._extractEditableMap(params),
      if (body != null)
        'body': _hasPlaceholder(body),
    };

    // ==========================================================
    // AUTH
    // ==========================================================

    final authData =
    _extractAuth(
      request['auth']
      is Map<String, dynamic>
          ? request['auth']
      as Map<String, dynamic>
          : null,
    );

    // ==========================================================
    // RETURN
    // ==========================================================

    return ApiPreset(
      id:
      json['id']?.toString() ??
          DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

      name:
      json['name']?.toString() ??
          'Unnamed',

      method:
      request['method']
          ?.toString()
          .toUpperCase() ??
          'GET',

      url:
      urlRaw,

      headers:
      headers,

      params:
      params,

      body:
      body,

      editableFields:
      editableMap,

      urlVariables:
      urlVariables,

      authType:
      authData['type']?.toString(),

      authToken:
      authData['token']?.toString(),
    );
  }

  // ============================================================
  // VALUE CLEANING
  // ============================================================

  static String cleanValue(
      String value,
      ) {
    return value.replaceAll(
      RegExp(r'[\[\]]'),
      '',
    );
  }

  // ============================================================
  // RESOLVE PLACEHOLDER
  // ============================================================
  //
  // This is intentionally centralized so every request uses
  // exactly the same placeholder replacement behavior.
  //
  // Example:
  //
  // [ACCESS_TOKEN]
  // [Access Token]
  // [ PHONE_NUMBER_ID ]
  //
  // ============================================================

  static String resolvePlaceholders(
      String value,
      Map<String, String> variables,
      ) {
    return value.replaceAllMapped(
      RegExp(r'\[(.*?)\]'),
          (match) {
        final rawKey =
            match.group(1)?.trim() ?? '';

        if (rawKey.isEmpty) {
          return match.group(0) ?? '';
        }

        // Exact match first.
        if (variables.containsKey(rawKey)) {
          return variables[rawKey] ?? '';
        }

        // Case-insensitive fallback.
        for (final entry in variables.entries) {
          if (entry.key.trim().toLowerCase() ==
              rawKey.toLowerCase()) {
            return entry.value;
          }
        }

        // Keep unresolved placeholder.
        return match.group(0) ?? '';
      },
    );
  }

  // ============================================================
  // SPECIAL WHATSAPP SETTINGS BODY
  // ============================================================
  //
  // Meta's /settings endpoint expects:
  //
  // {
  //   "messaging_product": "whatsapp",
  //   "storage_configuration": {
  //     ...
  //   }
  // }
  //
  // Keep this helper here so the request editor can use the
  // exact JSON structure when this request is executed.
  //
  // ============================================================

  String resolvedBody(
      Map<String, String> variables,
      ) {
    var resolved =
    body == null
        ? ''
        : resolvePlaceholders(
      body!,
      variables,
    );

    // ----------------------------------------------------------
    // Reigon / WhatsApp settings request
    // ----------------------------------------------------------
    //
    // The Postman collection may contain an older body without
    // messaging_product. Meta's WhatsApp settings endpoint
    // requires it.
    //
    if (_isWhatsAppSettingsRequest()) {
      try {
        final decoded =
        jsonDecode(resolved);

        if (decoded is Map<String, dynamic>) {
          decoded.putIfAbsent(
            'messaging_product',
                () => 'whatsapp',
          );

          resolved =
              const JsonEncoder.withIndent(
                '  ',
              ).convert(decoded);
        }
      } catch (_) {
        // Keep original body if it is not valid JSON.
      }
    }

    return resolved;
  }

  // ============================================================
  // WHATSAPP SETTINGS DETECTION
  // ============================================================

  bool _isWhatsAppSettingsRequest() {
    final normalizedUrl =
    url.toLowerCase();

    return method.toUpperCase() == 'POST' &&
        normalizedUrl.contains(
          '/settings',
        ) &&
        normalizedUrl.contains(
          'graph.facebook.com',
        );
  }
}