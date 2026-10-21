class Project {
  const Project({
    required this.id,
    required this.name,
    required this.schoolName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String schoolName;
  final DateTime createdAt;
  final DateTime updatedAt;
}
