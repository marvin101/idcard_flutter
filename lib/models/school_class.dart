class SchoolClass {
  const SchoolClass({
    required this.uuid,
    required this.name,
    this.sortOrder = 0,
  });

  final String uuid;
  final String name;
  final int sortOrder;

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}
