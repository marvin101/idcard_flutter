import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrintBasketStore {
  PrintBasketStore();

  Future<void> _writeQueue = Future<void>.value();

  String _key({required String schoolUuid, required String identityType}) =>
      'campusid.print-basket.v1.$schoolUuid.$identityType';

  Future<List<String>> load({
    required String schoolUuid,
    required String identityType,
  }) async {
    try {
      await _writeQueue;
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(
        _key(schoolUuid: schoolUuid, identityType: identityType),
      );
      if (encoded == null || encoded.isEmpty) return const [];

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];

      final uniqueIds = <String>{};
      for (final value in decoded) {
        if (value is! String) continue;
        final id = value.trim();
        if (id.isEmpty) continue;
        uniqueIds.add(id);
      }
      return uniqueIds.toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save({
    required String schoolUuid,
    required String identityType,
    required Iterable<String> recordUuids,
  }) {
    final uniqueIds = <String>{};
    for (final value in recordUuids) {
      final id = value.trim();
      if (id.isEmpty) continue;
      uniqueIds.add(id);
    }

    final key = _key(schoolUuid: schoolUuid, identityType: identityType);
    final values = uniqueIds.toList(growable: false);
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (values.isEmpty) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, jsonEncode(values));
      }
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }
}
