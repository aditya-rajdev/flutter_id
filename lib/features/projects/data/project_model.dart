class SectionConfigModel {
  final String id;
  final String name;
  int startRoll;
  int totalStudents;

  SectionConfigModel({
    required this.id,
    required this.name,
    this.startRoll = 1,
    this.totalStudents = 45,
  });

  factory SectionConfigModel.fromJson(Map<String, dynamic> json) {
    return SectionConfigModel(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'A',
      startRoll: (json['startRoll'] as num?)?.toInt() ?? 1,
      totalStudents: (json['students'] as num?)?.toInt() ??
          (json['totalStudents'] as num?)?.toInt() ??
          45,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startRoll': startRoll,
    'students': totalStudents,
    'totalStudents': totalStudents,
  };
}

class ClassConfigModel {
  final String id;
  final String className;
  final List<SectionConfigModel> sections;
  bool isExpanded;

  ClassConfigModel({
    required this.id,
    required this.className,
    required this.sections,
    this.isExpanded = true,
  });

  factory ClassConfigModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    return ClassConfigModel(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      className: json['name']?.toString() ??
          json['className']?.toString() ??
          'Class 1',
      sections: rawSections
          .whereType<Map>()
          .map((item) =>
          SectionConfigModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      isExpanded: json['isExpanded'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': className,
    'className': className,
    'isExpanded': isExpanded,
    'sections': sections.map((s) => s.toJson()).toList(),
  };
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.schoolName,
    required this.createdAt,
    required this.updatedAt,
    this.classes = const [],
  });

  final String id;
  final String name;
  final String schoolName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ClassConfigModel> classes;

  int get totalStudents => classes.fold(
    0,
        (sum, c) => sum + c.sections.fold(0, (sSum, s) => sSum + s.totalStudents),
  );

  int get totalSections => classes.fold(
    0,
        (sum, c) => sum + c.sections.length,
  );

  factory ProjectModel.fromMap(Map<String, Object?> map) {
    return ProjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      schoolName: map['school_name'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'school_name': schoolName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProjectModel copyWith({
    String? name,
    String? schoolName,
    DateTime? updatedAt,
    List<ClassConfigModel>? classes,
  }) {
    return ProjectModel(
      id: id,
      name: name ?? this.name,
      schoolName: schoolName ?? this.schoolName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      classes: classes ?? this.classes,
    );
  }
}
