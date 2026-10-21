import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/storage/app_file_storage.dart';
import '../../../dashboard/presentation/screens/project_details_screen.dart';
import '../../../dashboard/presentation/screens/project_setup_screen.dart';
import '../../../projects/data/project_model.dart';

class ClassManagementScreen extends StatefulWidget {
  final String schoolName;
  final ProjectModel? project;

  const ClassManagementScreen({
    super.key,
    required this.schoolName,
    this.project,
  });

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final List<SectionItemFeed> _sectionsFeed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    if (!mounted) return;
    setState(() => _loading = true);

    _sectionsFeed.clear();

    if (widget.project != null && widget.project!.classes.isNotEmpty) {
      for (final classModel in widget.project!.classes) {
        for (final sectionModel in classModel.sections) {
          final start = sectionModel.startRoll;
          final total = sectionModel.totalStudents;
          final end = total > 0 ? start + total - 1 : start;

          final stats = await AppFileStorage.getSectionStats(
            schoolName: widget.schoolName,
            className: classModel.className,
            sectionName: sectionModel.name,
            startRoll: start,
            endRoll: end,
          );

          _sectionsFeed.add(
            SectionItemFeed(
              className: classModel.className,
              sectionName: sectionModel.name,
              startRoll: start,
              endRoll: end,
              capturedCount: stats.capturedCount,
              totalStudents: total,
            ),
          );
        }
      }
    } else {
      // Fallback preview section
      final stats = await AppFileStorage.getSectionStats(
        schoolName: widget.schoolName,
        className: 'Class 10',
        sectionName: 'A',
        startRoll: 1,
        endRoll: 45,
      );

      _sectionsFeed.add(
        SectionItemFeed(
          className: 'Class 10',
          sectionName: 'A',
          startRoll: 1,
          endRoll: 45,
          capturedCount: stats.capturedCount,
          totalStudents: 45,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openAddClass() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ProjectSetupScreen(),
      ),
    );

    if (updated == true && mounted) {
      await _loadSections();
    }
  }

  Future<void> _openSectionDetail(SectionItemFeed item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectionDetailScreen(
          schoolName: widget.schoolName,
          className: item.className,
          sectionName: item.sectionName,
          startRoll: item.startRoll.toString(),
          endRoll: item.endRoll.toString(),
        ),
      ),
    );

    if (mounted) {
      await _loadSections();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddClass,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Class',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadSections,
          child: Column(
            children: [
              // Top Header Gradient Bar
              SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.schoolName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // Overview Summary HUD Float Card
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 80,
                      child: Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                                      widget.schoolName,
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
                                      'Total Sections Added: ${_sectionsFeed.length}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Classes / Sections Feed List Header
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Classes / Sections',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              // Dynamic Feed List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
                  itemCount: _sectionsFeed.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _sectionsFeed[index];
                    final rangeStr = '${item.startRoll} - ${item.endRoll}';

                    return Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openSectionDetail(item),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${item.className} ${item.sectionName}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          ' ($rangeStr)',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Captured: ${item.capturedCount}/${item.totalStudents}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: item.capturedCount > 0
                                            ? AppColors.capturedText
                                            : AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                '›',
                                style: TextStyle(
                                  color: Color(0xFFBBBBBB),
                                  fontSize: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionItemFeed {
  final String className;
  final String sectionName;
  final int startRoll;
  final int endRoll;
  final int capturedCount;
  final int totalStudents;

  SectionItemFeed({
    required this.className,
    required this.sectionName,
    required this.startRoll,
    required this.endRoll,
    required this.capturedCount,
    required this.totalStudents,
  });
}
