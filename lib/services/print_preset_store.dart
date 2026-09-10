import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/print_sheet.dart';

class PrintPresetStore {
  const PrintPresetStore();

  String _key(String schoolUuid) => 'campusid.print-presets.v1.$schoolUuid';

  Future<List<PrintPreset>> load(String schoolUuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_key(schoolUuid));
      if (encoded == null || encoded.isEmpty) return const [];
      final values = jsonDecode(encoded) as List;
      return values
          .map(
            (value) =>
                PrintPreset.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return const [];
    }
  }

  Future<PrintPreset> save({
    required String schoolUuid,
    required String name,
    required PrintSheetSettings settings,
    String? id,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 60) {
      throw ArgumentError('Preset name must contain 1–60 characters.');
    }
    final presets = (await load(schoolUuid)).toList();
    final caseInsensitiveMatch = presets.indexWhere(
      (preset) => preset.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    final resolvedId =
        id ??
        (caseInsensitiveMatch < 0
            ? DateTime.now().microsecondsSinceEpoch.toString()
            : presets[caseInsensitiveMatch].id);
    final preset = PrintPreset(
      id: resolvedId,
      name: normalizedName,
      settings: settings,
    );
    presets.removeWhere(
      (candidate) =>
          candidate.id == resolvedId ||
          candidate.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    presets.add(preset);
    await _write(schoolUuid, presets);
    return preset;
  }

  Future<void> delete(String schoolUuid, String id) async {
    final presets = (await load(schoolUuid)).toList();
    presets.removeWhere((preset) => preset.id == id);
    await _write(schoolUuid, presets);
  }

  Future<void> _write(String schoolUuid, List<PrintPreset> presets) async {
    presets.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(schoolUuid),
      jsonEncode(presets.map((preset) => preset.toJson()).toList()),
    );
  }
}
