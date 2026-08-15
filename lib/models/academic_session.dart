class AcademicSession {
  const AcademicSession({
    required this.uuid,
    required this.name,
    this.startDate,
    this.endDate,
    required this.isCurrent,
  });

  final String uuid;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;

  factory AcademicSession.fromJson(Map<String, dynamic> json) => AcademicSession(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        startDate: _parseDate(json['start_date']),
        endDate: _parseDate(json['end_date']),
        isCurrent: json['is_current'] as bool? ?? false,
      );

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
