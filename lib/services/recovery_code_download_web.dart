// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

Future<bool> downloadRecoveryCodes(
  String contents, {
  String username = 'campusid',
}) async {
  final safeUsername = username
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_.-]+|[_.-]+$'), '');
  final fileName = safeUsername.isEmpty
      ? 'campusid_recovery_codes.txt'
      : '${safeUsername}_recovery_codes.txt';

  final blob = html.Blob([utf8.encode(contents)], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
