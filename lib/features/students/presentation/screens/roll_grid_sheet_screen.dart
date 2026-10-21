import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/storage/app_file_storage.dart';
import '../../../camera/presentation/screens/camera_screen.dart';

class RollGridSheetScreen extends StatefulWidget {
  final String schoolName;
  final String className;
  final String sectionName;
  final String startRoll;
  final String endRoll;

  const RollGridSheetScreen({
    super.key,
    required this.schoolName,
    required this.className,
    required this.sectionName,
    required this.startRoll,
    required this.endRoll,
  });

  @override
  State<RollGridSheetScreen> createState() => _RollGridSheetScreenState();
}

class _RollGridSheetScreenState extends State<RollGridSheetScreen> {
  String _selectedTab = 'all';
  SectionStats? _stats;
  List<File> _capturedPhotos = [];
  bool _loading = true;

  int get _minRoll => int.tryParse(widget.startRoll) ?? 1;
  int get _maxRoll => int.tryParse(widget.endRoll) ?? 45;
  List<int> get _totalRolls => List.generate(_maxRoll - _minRoll + 1, (i) => _minRoll + i);

  @override
  void initState() {
    super.initState();
    _loadGridData();
  }

  Future<void> _loadGridData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final stats = await AppFileStorage.getSectionStats(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
      startRoll: _minRoll,
      endRoll: _maxRoll,
    );

    final photos = await AppFileStorage.getCapturedPhotos(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
    );

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _capturedPhotos = photos;
      _loading = false;
    });
  }

  List<int> get _filteredRolls {
    if (_stats == null) return _totalRolls;
    if (_selectedTab == 'captured') {
      return _totalRolls.where((r) => _stats!.capturedRolls.contains(r)).toList();
    } else if (_selectedTab == 'skipped') {
      return _totalRolls.where((r) => _stats!.skippedRolls.contains(r)).toList();
    } else if (_selectedTab == 'remaining') {
      return _totalRolls
          .where((r) => !_stats!.capturedRolls.contains(r) && !_stats!.skippedRolls.contains(r))
          .toList();
    }
    return _totalRolls;
  }

  Future<void> _openCameraForRoll(int rollNumber) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          schoolName: widget.schoolName,
          className: widget.className,
          sectionName: widget.sectionName,
          startRoll: rollNumber.toString().padLeft(3, '0'),
          endRoll: widget.endRoll,
        ),
      ),
    );

    if (mounted) {
      await _loadGridData();
    }
  }

  void _openPhotoViewer(int rollNumber) {
    final fileName = AppFileStorage.getPhotoFileName(
      className: widget.className,
      sectionName: widget.sectionName,
      rollNumber: rollNumber,
    );

    File? foundFile;
    for (final photo in _capturedPhotos) {
      if (photo.path.endsWith(fileName)) {
        foundFile = photo;
        break;
      }
    }

    if (foundFile == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('Roll Number: ${rollNumber.toString().padLeft(3, '0')}'),
          ),
          body: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: Image.file(
                    foundFile!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _openCameraForRoll(rollNumber);
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () async {
                          await AppFileStorage.deleteStudentPhoto(foundFile!);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          await _loadGridData();
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportZip() async {
    final rolls = _stats?.capturedRolls.toList() ?? [];
    if (rolls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No captured photos to export.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Building ZIP archive...')),
    );

    await AppFileStorage.exportPhotosToZip(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
      capturedRolls: rolls,
    );
  }

  Future<void> _exportExcel() async {
    final set = _stats?.capturedRolls ?? {};
    if (set.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No captured photos to generate Excel catalog.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Excel catalog...')),
    );

    await AppFileStorage.exportToExcel(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
      totalRolls: _totalRolls,
      capturedSet: set,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Select Roll Number',
          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF072256),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _filterTab('all', 'All (${_totalRolls.length})'),
                  const SizedBox(width: 6),
                  _filterTab('captured', 'Captured (${_stats?.capturedCount ?? 0})'),
                  const SizedBox(width: 6),
                  _filterTab('skipped', 'Skipped (${_stats?.skippedCount ?? 0})'),
                  const SizedBox(width: 6),
                  _filterTab('remaining', 'Remaining (${_stats?.remainingCount ?? 0})'),
                ],
              ),
            ),

            // Legend Bar
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  _LegendDot(color: AppColors.capturedText, label: 'Captured'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.skippedText, label: 'Skipped'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.remainingText, label: 'Remaining'),
                ],
              ),
            ),

            // 5-Column Vertical Grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _filteredRolls.length,
                itemBuilder: (context, index) {
                  final roll = _filteredRolls[index];
                  final isCaptured = _stats?.capturedRolls.contains(roll) ?? false;
                  final isSkipped = _stats?.skippedRolls.contains(roll) ?? false;

                  final boxBg = isCaptured
                      ? AppColors.capturedBg
                      : isSkipped
                      ? AppColors.skippedBg
                      : AppColors.remainingBg;

                  final boxBorder = isCaptured
                      ? AppColors.capturedBorder
                      : isSkipped
                      ? AppColors.skippedBorder
                      : AppColors.remainingBorder;

                  final textColor = isCaptured
                      ? AppColors.capturedText
                      : isSkipped
                      ? AppColors.skippedText
                      : AppColors.textPrimary;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (isCaptured) {
                        _openPhotoViewer(roll);
                      } else {
                        _openCameraForRoll(roll);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: boxBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: boxBorder),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            roll.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isCaptured ? '✓' : isSkipped ? '–' : '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Export Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: const Color(0xFFF8F9FA),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF072256),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exportZip,
                        child: const Text(
                          'Photos ZIP',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF107C41),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _exportExcel,
                        child: const Text(
                          'Excel Sheet',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTab(String key, String label) {
    final isActive = _selectedTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = key),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
