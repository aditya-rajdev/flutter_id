import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/projects/data/project_model.dart';
import '../database/app_database.dart';

class ProjectRepository {
  ProjectRepository({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;
  static const String _prefsKey = 'ID_CAMERA_PROJECTS';

  Future<List<ProjectModel>> getAllProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_prefsKey);

    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        final list = <ProjectModel>[];

        for (final item in decoded) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);

          final rawClasses = map['classes'] as List<dynamic>? ?? [];
          final classesList = rawClasses
              .whereType<Map>()
              .map((c) => ClassConfigModel.fromJson(Map<String, dynamic>.from(c)))
              .toList();

          list.add(
            ProjectModel(
              id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
              name: map['name']?.toString() ?? map['schoolName']?.toString() ?? 'School',
              schoolName: map['schoolName']?.toString() ?? map['name']?.toString() ?? '',
              createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
              updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
              classes: classesList,
            ),
          );
        }
        if (list.isNotEmpty) return list;
      } catch (e) {
        // Fallback to SQLite
      }
    }

    // Fallback to SQLite DB
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      'projects',
      orderBy: 'updated_at DESC',
    );

    return rows.map(ProjectModel.fromMap).toList();
  }

  Future<ProjectModel> createProject({
    required String name,
    String schoolName = '',
    List<ClassConfigModel> classes = const [],
  }) async {
    final String trimmedName = name.trim();
    final String trimmedSchoolName = schoolName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Project name cannot be empty.');
    }

    final DateTime now = DateTime.now();
    final String id = '${now.microsecondsSinceEpoch}';

    final ProjectModel project = ProjectModel(
      id: id,
      name: trimmedName,
      schoolName: trimmedSchoolName.isNotEmpty ? trimmedSchoolName : trimmedName,
      createdAt: now,
      updatedAt: now,
      classes: classes,
    );

    final Database db = await _appDatabase.database;
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save to SharedPreferences as JSON list
    final all = await getAllProjects();
    final updatedList = [project, ...all.where((p) => p.id != id)];
    await _saveToPrefs(updatedList);

    return project;
  }

  Future<void> renameProject({
    required String id,
    required String newName,
  }) async {
    final String trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Project name cannot be empty.');
    }

    final Database db = await _appDatabase.database;
    await db.update(
      'projects',
      {'name': trimmedName, 'school_name': trimmedName, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    final all = await getAllProjects();
    final updatedList = all.map((p) {
      if (p.id == id) {
        return p.copyWith(name: trimmedName, schoolName: trimmedName, updatedAt: DateTime.now());
      }
      return p;
    }).toList();

    await _saveToPrefs(updatedList);
  }

  Future<void> deleteProject(String id) async {
    final Database db = await _appDatabase.database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);

    final all = await getAllProjects();
    final updatedList = all.where((p) => p.id != id).toList();
    await _saveToPrefs(updatedList);
  }

  Future<void> _saveToPrefs(List<ProjectModel> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = projects.map((p) {
      return {
        'id': p.id,
        'name': p.name,
        'schoolName': p.schoolName,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
        'classes': p.classes.map((c) => c.toJson()).toList(),
      };
    }).toList();

    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }
}
