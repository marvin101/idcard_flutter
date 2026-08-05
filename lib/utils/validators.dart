class Validators {
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return "$fieldName is required";
    }
    return null;
  }

  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Mobile number is required";
    }

    if (value.length != 10) {
      return "Enter a valid 10-digit mobile number";
    }

    return null;
  }

  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    if (value.length != 12) {
      return "Aadhaar must contain 12 digits";
    }

    return null;
  }

  static String? session(String? value) {
    if (value == null || value.isEmpty) return null;

    final regex = RegExp(r'^\d{4}-\d{4}$');

    if (!regex.hasMatch(value)) {
      return "Example: 2026-2027";
    }

    return null;
  }
}
