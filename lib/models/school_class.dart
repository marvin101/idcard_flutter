class SchoolClass {
  const SchoolClass({required this.uuid, required this.name});

  final String uuid;
  final String name;

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
      );
}
