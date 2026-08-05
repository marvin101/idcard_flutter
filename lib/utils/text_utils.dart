class TextUtils {
  static String capitalizeWords(String text) {
    if (text.trim().isEmpty) return text;

    return text.split(RegExp(r'(\s+)')).map((part) {
      if (part.trim().isEmpty) return part;

      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();
  }
}
