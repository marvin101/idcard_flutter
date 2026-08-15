class SchoolSection {
  const SchoolSection({required this.uuid, required this.name});

  final String uuid;
  final String name;

  factory SchoolSection.fromJson(Map<String, dynamic> json) => SchoolSection(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
      );
}
