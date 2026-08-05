import 'package:flutter/services.dart';

class AppFormatters {
  static final digitsOnly = [FilteringTextInputFormatter.digitsOnly];

  static final mobile = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static final aadhaar = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(12),
  ];

  static final alphabetOnly = [
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z ]")),
  ];
}
