import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SectionStats {
  final int capturedCount;
  final int skippedCount;
  final int remainingCount;
  final int totalStudents;
  final int progressPercentage;
  final String lastPhotoName;
  final String nextRollToCapture;
  final Set<int> capturedRolls;
  final Set<int> skippedRolls;

  SectionStats({
    required this.capturedCount,
    required this.skippedCount,
    required this.remainingCount,
    required this.totalStudents,
    required this.progressPercentage,
    required this.lastPhotoName,
    required this.nextRollToCapture,
    required this.capturedRolls,
    required this.skippedRolls,
  });
}

class AppFileStorage {
  static const String prefsName = 'ID_CAMERA_PREFS';

  static String sanitize(String text) {
    return text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  static Future<Directory> getSectionDirectory({
    required String schoolName,
    required String className,
    required String sectionName,
  }) async {
    final cleanSchool = sanitize(schoolName);
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);

    Directory? baseDir;
    if (kIsWeb) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
      // Use Pictures directory or external storage
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        // Pictures/ID_Camera/...
        final picturesPath = extDir.path.split('/Android/data')[0] + '/Pictures';
        baseDir = Directory(picturesPath);
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final targetDir = Directory(
      '${baseDir.path}/ID_Camera/$cleanSchool/$cleanClass/$cleanSection',
    );

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return targetDir;
  }

  static Future<Set<int>> getSkippedRolls({
    required String schoolName,
    required String className,
    required String sectionName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSchool = sanitize(schoolName);
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_${cleanSection}';
    final list = prefs.getStringList(key) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
  }

  static Future<void> addSkippedRoll({
    required String schoolName,
    required String className,
    required String sectionName,
    required int rollNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSchool = sanitize(schoolName);
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_${cleanSection}';
    final current = (prefs.getStringList(key) ?? []).toSet();
    current.add(rollNumber.toString());
    await prefs.setStringList(key, current.toList());
  }

  static Future<void> removeSkippedRoll({
    required String schoolName,
    required String className,
    required String sectionName,
    required int rollNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSchool = sanitize(schoolName);
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_${cleanSection}';
    final current = (prefs.getStringList(key) ?? []).toSet();
    current.remove(rollNumber.toString());
    await prefs.setStringList(key, current.toList());
  }

  static Future<SectionStats> getSectionStats({
    required String schoolName,
    required String className,
    required String sectionName,
    required int startRoll,
    required int endRoll,
  }) async {
    final totalStudents = (endRoll - startRoll + 1).clamp(0, 9999);
    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final capturedRolls = <int>{};
    File? latestFile;
    DateTime? latestTime;

    if (await dir.exists()) {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File &&
            (entity.path.toLowerCase().endsWith('.jpg') ||
                entity.path.toLowerCase().endsWith('.jpeg'))) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          final rollPart = nameWithoutExt.split('_Roll_').last;
          final rollNum = int.tryParse(rollPart);
          if (rollNum != null) {
            capturedRolls.add(rollNum);
          }

          final stat = entity.statSync();
          if (latestTime == null || stat.modified.isAfter(latestTime)) {
            latestTime = stat.modified;
            latestFile = entity;
          }
        }
      }
    }

    final skippedRolls = await getSkippedRolls(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final capturedCount = capturedRolls.length;
    final skippedCount = skippedRolls.length;
    final remainingCount = (totalStudents - capturedCount - skippedCount).clamp(0, totalStudents);
    final progressPercentage = totalStudents > 0
        ? ((capturedCount / totalStudents) * 100).toInt().clamp(0, 100)
        : 0;

    String lastPhotoName = 'No photos captured yet';
    if (latestFile != null) {
      lastPhotoName = latestFile.path.split(Platform.pathSeparator).last;
    }

    String nextRollToCapture = '001';
    int foundNext = startRoll;
    while (foundNext <= endRoll) {
      if (!capturedRolls.contains(foundNext) && !skippedRolls.contains(foundNext)) {
        break;
      }
      foundNext++;
    }

    if (foundNext <= endRoll) {
      nextRollToCapture = foundNext.toString().padLeft(3, '0');
    } else {
      nextRollToCapture = 'Done';
    }

    return SectionStats(
      capturedCount: capturedCount,
      skippedCount: skippedCount,
      remainingCount: remainingCount,
      totalStudents: totalStudents,
      progressPercentage: progressPercentage,
      lastPhotoName: lastPhotoName,
      nextRollToCapture: nextRollToCapture,
      capturedRolls: capturedRolls,
      skippedRolls: skippedRolls,
    );
  }

  static Future<List<File>> getCapturedPhotos({
    required String schoolName,
    required String className,
    required String sectionName,
  }) async {
    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final photos = <File>[];
    if (await dir.exists()) {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File &&
            (entity.path.toLowerCase().endsWith('.jpg') ||
                entity.path.toLowerCase().endsWith('.jpeg'))) {
          photos.add(entity);
        }
      }
      photos.sort((a, b) => a.path.compareTo(b.path));
    }
    return photos;
  }

  static String getPhotoFileName({
    required String className,
    required String sectionName,
    required int rollNumber,
  }) {
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final rollStr = rollNumber.toString().padLeft(3, '0');
    return '${cleanClass}_${cleanSection}_Roll_$rollStr.jpg';
  }

  static Future<File> saveStudentPhoto({
    required String schoolName,
    required String className,
    required String sectionName,
    required int rollNumber,
    required List<int> imageBytes,
  }) async {
    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final fileName = getPhotoFileName(
      className: className,
      sectionName: sectionName,
      rollNumber: rollNumber,
    );

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(imageBytes);

    // If it was skipped earlier, remove from skipped set
    await removeSkippedRoll(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
      rollNumber: rollNumber,
    );

    return file;
  }

  static Future<bool> deleteStudentPhoto(File file) async {
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  static Future<void> exportPhotosToZip({
    required String schoolName,
    required String className,
    required String sectionName,
    required List<int> capturedRolls,
  }) async {
    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final archive = Archive();
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);

    for (final roll in capturedRolls) {
      final fileName = getPhotoFileName(
        className: className,
        sectionName: sectionName,
        rollNumber: roll,
      );
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }
    }

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    if (zipData == null) return;

    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}/Photos_${cleanClass}_$cleanSection.zip');
    await zipFile.writeAsBytes(zipData);

    await Share.shareXFiles(
      [XFile(zipFile.path)],
      text: 'Exported Photos ZIP for $className $sectionName ($schoolName)',
    );
  }

  static Future<void> exportToExcel({
    required String schoolName,
    required String className,
    required String sectionName,
    required List<int> totalRolls,
    required Set<int> capturedSet,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Photo Catalog';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    // Header Row
    sheet.appendRow([
      TextCellValue('Roll Number'),
      TextCellValue('Status'),
      TextCellValue('Photo File Name'),
    ]);

    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    for (final roll in totalRolls) {
      final rollStr = roll.toString().padLeft(3, '0');
      final fileName = getPhotoFileName(
        className: className,
        sectionName: sectionName,
        rollNumber: roll,
      );
      final isCaptured = capturedSet.contains(roll);
      final file = File('${dir.path}/$fileName');

      sheet.appendRow([
        TextCellValue(rollStr),
        TextCellValue(isCaptured && file.existsSync() ? 'Captured' : 'Missing'),
        TextCellValue(isCaptured && file.existsSync() ? fileName : 'N/A'),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final excelFile = File('${tempDir.path}/Catalog_${cleanClass}_$cleanSection.xlsx');
    await excelFile.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(excelFile.path)],
      text: 'Excel Photo Catalog for $className $sectionName ($schoolName)',
    );
  }
}
