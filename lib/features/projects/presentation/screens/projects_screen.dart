import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/project_repository.dart';
import '../../../classes/presentation/screens/classes_screen.dart';
import '../../../dashboard/presentation/screens/project_setup_screen.dart';
import '../../data/project_model.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectRepository _repository = ProjectRepository();

  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final projects = await _repository.getAllProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openCreateProject() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ProjectSetupScreen(),
      ),
    );

    if (created == true && mounted) {
      await _loadProjects();
    }
  }

  Future<void> _openClassManagement(ProjectModel project) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ClassManagementScreen(
          schoolName: project.schoolName.isNotEmpty ? project.schoolName : project.name,
          project: project,
        ),
      ),
    );

    if (mounted) {
      await _loadProjects();
    }
  }

  void _showContextMenu(ProjectModel project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Workspace Options: ${project.schoolName.isNotEmpty ? project.schoolName : project.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F2F7),
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  _showRenameDialog(project);
                },
                icon: const Text('✏️', style: TextStyle(fontSize: 18)),
                label: const Text(
                  'Edit / Rename School',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE5E5),
                  foregroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  _deleteProject(project);
                },
                icon: const Text('🗑️', style: TextStyle(fontSize: 18)),
                label: const Text(
                  'Delete Project',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(bottomSheetContext),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(ProjectModel project) async {
    final controller = TextEditingController(
      text: project.schoolName.isNotEmpty ? project.schoolName : project.name,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Rename School',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter new school name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await _repository.renameProject(id: project.id, newName: newName);
      await _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School renamed successfully.')),
        );
      }
    }
  }

  Future<void> _deleteProject(ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project?'),
          content: Text('Delete "${project.schoolName.isNotEmpty ? project.schoolName : project.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _repository.deleteProject(project.id);
      await _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProjects,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP DYNAMIC BLUE HEADER BLOCK
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primaryDark, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID Camera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Smart School ID Solution',
                        style: TextStyle(
                          color: AppColors.textOnPrimaryMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. "NEW PROJECT" FLOATING CARD LAYER
                Transform.translate(
                  offset: const Offset(0, -45),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      color: AppColors.primary,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _openCreateProject,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'New Project',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Create new class / batch',
                                      style: TextStyle(
                                        color: AppColors.textOnPrimaryMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                '›',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Header Labels Section
                Transform.translate(
                  offset: const Offset(0, -25),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Recent Projects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 3. RECENT PROJECTS FEED LIST
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_projects.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: _projects.map((project) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            color: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openClassManagement(project),
                              onLongPress: () => _showContextMenu(project),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSecondary,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text('🎓', style: TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project.schoolName.isNotEmpty
                                                ? project.schoolName
                                                : project.name,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${project.classes.length} Classes Added',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Total Students: ${project.totalStudents}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: AppColors.iconMuted,
                                      ),
                                      onPressed: () => _showContextMenu(project),
                                    ),
                                    const Text(
                                      '›',
                                      style: TextStyle(
                                        color: AppColors.iconMuted,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'No projects active at the moment.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Click on "New Project" above to build a custom list setup.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
