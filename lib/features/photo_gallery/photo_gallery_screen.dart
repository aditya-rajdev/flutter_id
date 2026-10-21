import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/storage/app_file_storage.dart';
import '../camera/presentation/screens/camera_screen.dart';

class CapturedPhotosGalleryScreen extends StatefulWidget {
  final String schoolName;
  final String className;
  final String sectionName;
  final String startRoll;
  final String endRoll;

  const CapturedPhotosGalleryScreen({
    super.key,
    required this.schoolName,
    required this.className,
    required this.sectionName,
    this.startRoll = '1',
    this.endRoll = '45',
  });

  @override
  State<CapturedPhotosGalleryScreen> createState() =>
      _CapturedPhotosGalleryScreenState();
}

class _CapturedPhotosGalleryScreenState
    extends State<CapturedPhotosGalleryScreen> {
  List<File> _photosList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final photos = await AppFileStorage.getCapturedPhotos(
      schoolName: widget.schoolName,
      className: widget.className,
      sectionName: widget.sectionName,
    );

    if (!mounted) return;
    setState(() {
      _photosList = photos;
      _loading = false;
    });
  }

  void _openFullScreenViewer(int initialIndex) {
    if (_photosList.isEmpty) return;

    final controller = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pageIndex = controller.hasClients && controller.page != null
                ? controller.page!.round()
                : initialIndex;

            final file = _photosList.elementAtOrNull(pageIndex);
            final fileName = file?.path.split(Platform.pathSeparator).last ?? '';
            final rollNumStr = fileName.contains('_Roll_')
                ? fileName.substring(fileName.lastIndexOf('_Roll_') + 6, fileName.lastIndexOf('.'))
                : '001';

            final rollInt = int.tryParse(rollNumStr) ?? 1;

            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: controller,
                      itemCount: _photosList.length,
                      onPageChanged: (_) {
                        setModalState(() {});
                      },
                      itemBuilder: (context, index) {
                        return InteractiveViewer(
                          child: Image.file(
                            _photosList[index],
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),

                    // Top control panel
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Roll Number: $rollNumStr (${pageIndex + 1}/${_photosList.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (file == null) return;
                              final stat = file.statSync();
                              final sizeKb = (stat.size / 1024).round();
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Image Metadata Details'),
                                  content: Text(
                                    'File Name: $fileName\n'
                                        'Path: ${file.path}\n'
                                        'Date: ${stat.modified}\n'
                                        'Memory Size: $sizeKb KB',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Bottom controls panel
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CameraScreen(
                                      schoolName: widget.schoolName,
                                      className: widget.className,
                                      sectionName: widget.sectionName,
                                      startRoll: rollInt.toString().padLeft(3, '0'),
                                      endRoll: widget.endRoll,
                                    ),
                                  ),
                                ).then((_) => _loadPhotos());
                              },
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Retake'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                if (file != null) {
                                  await AppFileStorage.deleteStudentPhoto(file);
                                  await _loadPhotos();
                                  if (_photosList.isEmpty && dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  } else {
                                    setModalState(() {});
                                  }
                                }
                              },
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullClassName = '${widget.className} ${widget.sectionName}';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Captured Photos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$fullClassName • ${_photosList.length} Images',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.darkNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _photosList.isEmpty
            ? const Center(
          child: Text(
            'No captured photos found in this section.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadPhotos,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _photosList.length,
            itemBuilder: (context, index) {
              final file = _photosList[index];
              final fileName = file.path.split(Platform.pathSeparator).last;
              final rollStr = fileName.contains('_Roll_')
                  ? fileName.substring(fileName.lastIndexOf('_Roll_') + 6, fileName.lastIndexOf('.'))
                  : '000';

              return Card(
                clipBehavior: Clip.antiAlias,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: InkWell(
                  onTap: () => _openFullScreenViewer(index),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          child: Text(
                            'Roll: $rollStr',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
