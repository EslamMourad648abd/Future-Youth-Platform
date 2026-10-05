// lib/data/postman_loader.dart

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/api_preset.dart';
import '../models/api_prest_group.dart';

class PostmanLoader {
  static Future<List<ApiPresetGroup>> loadFromAssets(
      String path,
      ) async {
    try {
      final jsonStr = await rootBundle.loadString(path);

      final Map<String, dynamic> data =
      jsonDecode(jsonStr) as Map<String, dynamic>;

      final rawItems = data['item'];

      if (rawItems is! List) {
        return [];
      }

      final List<ApiPresetGroup> groups = [];

      for (final rawGroup in rawItems) {
        if (rawGroup is! Map) {
          continue;
        }

        final group = Map<String, dynamic>.from(rawGroup);

        final groupName =
        group['name']?.toString().trim().isNotEmpty == true
            ? group['name'].toString()
            : 'General';

        final rawRequests = group['item'];

        // ==========================================================
        // FOLDER
        // ==========================================================

        if (rawRequests is List) {
          final List<ApiPreset> presets = [];

          for (final rawRequest in rawRequests) {
            if (rawRequest is! Map) {
              continue;
            }

            final request = Map<String, dynamic>.from(rawRequest);

            // Ignore folders nested inside folders.
            if (request['request'] is! Map) {
              continue;
            }

            try {
              presets.add(
                ApiPreset.fromPostman(request),
              );
            } catch (e, s) {
              print(
                '❌ Error parsing Postman request '
                    '"${request['name']}": $e',
              );
              print(s);
            }
          }

          if (presets.isNotEmpty) {
            groups.add(
              ApiPresetGroup(
                name: groupName,
                presets: presets,
              ),
            );
          }

          continue;
        }

        // ==========================================================
        // DIRECT REQUEST
        // ==========================================================
        //
        // Supports collections where a request exists directly
        // under the root instead of inside a folder.
        //

        if (group['request'] is Map) {
          try {
            final preset = ApiPreset.fromPostman(group);

            groups.add(
              ApiPresetGroup(
                name: groupName,
                presets: [preset],
              ),
            );
          } catch (e, s) {
            print(
              '❌ Error parsing Postman request '
                  '"$groupName": $e',
            );
            print(s);
          }
        }
      }

      return groups;
    } catch (e, s) {
      print('❌ Error loading Postman file: $e');
      print(s);

      return [];
    }
  }
}