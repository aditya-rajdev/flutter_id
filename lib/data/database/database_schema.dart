
class DatabaseSchema {
  DatabaseSchema._();

  static const int version = 1;

  static const String projectsTable = 'projects';
  static const String classesTable = 'school_classes';
  static const String studentsTable = 'students';
  static const String templatesTable = 'templates';
  static const String settingsTable = 'app_settings';

  static const String createProjectsTable = '''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      school_name TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const String createClassesTable = '''
    CREATE TABLE school_classes (
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      name TEXT NOT NULL,
      section TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY (project_id)
        REFERENCES projects (id)
        ON DELETE CASCADE
    )
  ''';

  static const String createStudentsTable = '''
    CREATE TABLE students (
      id TEXT PRIMARY KEY,
      class_id TEXT NOT NULL,
      name TEXT NOT NULL,
      roll_number TEXT NOT NULL DEFAULT '',
      photo_path TEXT NOT NULL DEFAULT '',
      details_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (class_id)
        REFERENCES school_classes (id)
        ON DELETE CASCADE
    )
  ''';

  static const String createTemplatesTable = '''
    CREATE TABLE templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      template_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const String createSettingsTable = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const List<String> createStatements = [
    createProjectsTable,
    createClassesTable,
    createStudentsTable,
    createTemplatesTable,
    createSettingsTable,
  ];

  static const List<String> createIndexes = [
    'CREATE INDEX idx_classes_project_id ON school_classes(project_id)',
    'CREATE INDEX idx_students_class_id ON students(class_id)',
    'CREATE INDEX idx_students_name ON students(name)',
  ];
}
