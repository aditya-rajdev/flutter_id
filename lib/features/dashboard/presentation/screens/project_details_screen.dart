import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/storage/app_file_storage.dart';
import '../../../camera/presentation/screens/camera_screen.dart';
import '../../../photo_gallery/photo_gallery_screen.dart';
import '../../../students/presentation/screens/roll_grid_sheet_screen.dart';

class SectionDetailScreen extends StatefulWidget {
  final String schoolName;
  final String className;
  final String sectionName;
  final String startRoll;
  final String endRoll;

  const SectionDetailScreen({
    super.key,
    required this.schoolName,
    required this.className,
    required this.sectionName,
    this.startRoll = '1',
    this.endRoll = '45',
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  SectionStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final sRoll = int.tryParse(widget.startRoll) ?? 1;
    final eRoll = int.tryParse(widget.endRoll) ?? 45;

    final stats = await AppFileStorage.getSectionStats(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
      startRoll: sRoll,
      endRoll: eRoll,
    );

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _openCamera({int? specificRoll}) async {
    final sRoll = specificRoll ?? (int.tryParse(_stats?.nextRollToCapture ?? widget.startRoll) ?? 1);
    final eRoll = int.tryParse(widget.endRoll) ?? 45;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          schoolName: widget.schoolName,
          className: widget.className,
          sectionName: widget.sectionName,
          startRoll: sRoll.toString().padLeft(3, '0'),
          endRoll: eRoll.toString(),
        ),
      ),
    );

    if (mounted) {
      await _loadStats();
    }
  }

  Future<void> _openGallery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CapturedPhotosGalleryScreen(
          schoolName: widget.schoolName,
          className: widget.className,
          sectionName: widget.sectionName,
          startRoll: widget.startRoll,
          endRoll: widget.endRoll,
        ),
      ),
    );

    if (mounted) {
      await _loadStats();
    }
  }

  Future<void> _openRollGrid() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RollGridSheetScreen(
          schoolName: widget.schoolName,
          className: widget.className,
          sectionName: widget.sectionName,
          startRoll: widget.startRoll,
          endRoll: widget.endRoll,
        ),
      ),
    );

    if (mounted) {
      await _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullClassName = '${widget.className} ${widget.sectionName}';
    final rangeStr = 'Roll ${widget.startRoll} - ${widget.endRoll}';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          '$fullClassName (${widget.startRoll} - ${widget.endRoll})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.darkNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 2. OVERVIEW SUMMARY HUD CARD
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8EAF6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('👥', style: TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullClassName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.schoolName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF777777),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _stats?.progressPercentage == 100
                                    ? 'Completed'
                                    : 'In Progress',
                                style: const TextStyle(
                                  color: Color(0xFF137333),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rangeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. QUAD STATISTICS COUNTERS MATRIX
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        onTap: _openGallery,
                        icon: '📷',
                        label: 'Captured',
                        count: '${_stats?.capturedCount ?? 0}',
                        countColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: '🔀',
                        label: 'Skipped',
                        count: '${_stats?.skippedCount ?? 0}',
                        countColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: '👤',
                        label: 'Remaining',
                        count: '${_stats?.remainingCount ?? 0}',
                        countColor: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: '👥',
                        label: 'Total',
                        count: '${_stats?.totalStudents ?? 0}',
                        countColor: const Color(0xFF222222),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. PERFORMANCE TRACK BAR INFOGRAPHIC
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openGallery,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progress (Click to view images)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              Text(
                                '${_stats?.progressPercentage ?? 0}%',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_stats?.progressPercentage ?? 0) / 100,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text(
                                  'Last: ${_stats?.lastPhotoName ?? "None"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF777777),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Next Roll: ${_stats?.nextRollToCapture ?? widget.startRoll}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF777777),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 5. BIG NATIVE CAMERA NAVIGATION LAUNCH TRIGGER
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cameraGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: () => _openCamera(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('📷', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start Camera',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Continue with roll ${_stats?.nextRollToCapture ?? widget.startRoll}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Text(
                          '➔',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Jump Action Trigger Secondary Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _openRollGrid,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('🔢', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 14),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Go To Roll Number',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                Text(
                                  'Jump to any roll number',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '›',
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFFBBBBBB),
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

class _StatCard extends StatelessWidget {
  final VoidCallback? onTap;
  final String icon;
  final String label;
  final String count;
  final Color countColor;

  const _StatCard({
    this.onTap,
    required this.icon,
    required this.label,
    required this.count,
    required this.countColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF777777),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
