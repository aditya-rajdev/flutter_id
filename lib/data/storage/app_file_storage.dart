import 'dart:convert';
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
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final picturesPath = '${extDir.path.split('/Android/data')[0]}/Pictures';
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
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_$cleanSection';
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
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_$cleanSection';
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
    final key = 'SKIPPED_SET_${cleanSchool}_${cleanClass}_$cleanSection';
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

  /// Advanced Excel Export: Builds XLSX workbook with Roll Numbers, Photo Filenames,
  /// Status, and embedded JPEG image drawings matching Apache POI XSSFWorkbook.
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
      TextCellValue('Actual Photo / File Name'),
      TextCellValue('Status'),
    ]);

    final dir = await getSectionDirectory(
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
    );

    final imageFiles = <int, File>{};

    for (var i = 0; i < totalRolls.length; i++) {
      final roll = totalRolls[i];
      final rollStr = roll.toString().padLeft(3, '0');
      final fileName = getPhotoFileName(
        className: className,
        sectionName: sectionName,
        rollNumber: roll,
      );
      final isCaptured = capturedSet.contains(roll);
      final file = File('${dir.path}/$fileName');

      if (isCaptured && file.existsSync()) {
        imageFiles[i + 1] = file; // row index (1-based, after header at row 0)
        sheet.setRowHeight(i + 1, 60.0); // Set tall row height for image cell
      }

      sheet.appendRow([
        TextCellValue(rollStr),
        TextCellValue(isCaptured && file.existsSync() ? fileName : 'Missing'),
        TextCellValue(isCaptured && file.existsSync() ? 'Captured' : 'Pending'),
      ]);
    }

    sheet.setColumnWidth(0, 16.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 16.0);

    final baseExcelBytes = excel.encode();
    if (baseExcelBytes == null) return;

    // Inject Drawing Objects & JPEG Media into XLSX ZIP Archive (Apache POI equivalent)
    final archive = ZipDecoder().decodeBytes(baseExcelBytes);
    final updatedArchive = Archive();

    // Copy existing ZIP files
    for (final archiveFile in archive.files) {
      if (archiveFile.name != '[Content_Types].xml' &&
          archiveFile.name != 'xl/worksheets/sheet1.xml' &&
          archiveFile.name != 'xl/worksheets/_rels/sheet1.xml.rels') {
        updatedArchive.addFile(archiveFile);
      }
    }

    final drawingRelsXml = StringBuffer();
    drawingRelsXml.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    drawingRelsXml.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    final drawingXml = StringBuffer();
    drawingXml.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    drawingXml.writeln('<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');

    var imgIdx = 1;
    imageFiles.forEach((rowIndex, file) {
      final bytes = file.readAsBytesSync();
      final mediaPath = 'xl/media/image$imgIdx.jpeg';
      updatedArchive.addFile(ArchiveFile(mediaPath, bytes.length, bytes));

      drawingRelsXml.writeln('<Relationship Id="rId$imgIdx" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$imgIdx.jpeg"/>');

      drawingXml.writeln('<xdr:twoCellAnchor editAs="oneCell">');
      drawingXml.writeln('<xdr:from><xdr:col>1</xdr:col><xdr:colOff>10000</xdr:colOff><xdr:row>$rowIndex</xdr:row><xdr:rowOff>10000</xdr:rowOff></xdr:from>');
      drawingXml.writeln('<xdr:to><xdr:col>2</xdr:col><xdr:colOff>-10000</xdr:colOff><xdr:row>${rowIndex + 1}</xdr:row><xdr:rowOff>-10000</xdr:rowOff></xdr:to>');
      drawingXml.writeln('<xdr:pic>');
      drawingXml.writeln('<xdr:nvPicPr><xdr:cNvPr id="$imgIdx" name="Picture $imgIdx"/><xdr:cNvPicPr/></xdr:nvPicPr>');
      drawingXml.writeln('<xdr:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId$imgIdx"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>');
      drawingXml.writeln('<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>');
      drawingXml.writeln('</xdr:pic>');
      drawingXml.writeln('<xdr:clientData/>');
      drawingXml.writeln('</xdr:twoCellAnchor>');

      imgIdx++;
    });

    drawingRelsXml.writeln('</Relationships>');
    drawingXml.writeln('</xdr:wsDr>');

    if (imageFiles.isNotEmpty) {
      final drawingXmlStr = drawingXml.toString();
      final drawingRelsXmlStr = drawingRelsXml.toString();

      updatedArchive.addFile(ArchiveFile('xl/drawings/drawing1.xml', drawingXmlStr.length, utf8.encode(drawingXmlStr)));
      updatedArchive.addFile(ArchiveFile('xl/drawings/_rels/drawing1.xml.rels', drawingRelsXmlStr.length, utf8.encode(drawingRelsXmlStr)));

      final sheetRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>';
      updatedArchive.addFile(ArchiveFile('xl/worksheets/_rels/sheet1.xml.rels', sheetRelsXml.length, utf8.encode(sheetRelsXml)));

      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile != null) {
        var sheetStr = utf8.decode(sheetFile.content as List<int>);
        sheetStr = sheetStr.replaceFirst('</worksheet>', '<drawing r:id="rId1"/></worksheet>');
        updatedArchive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetStr.length, utf8.encode(sheetStr)));
      }

      final contentTypesFile = archive.findFile('[Content_Types].xml');
      if (contentTypesFile != null) {
        var ctStr = utf8.decode(contentTypesFile.content as List<int>);
        if (!ctStr.contains('Extension="jpeg"')) {
          ctStr = ctStr.replaceFirst('</Types>', '<Default Extension="jpeg" ContentType="image/jpeg"/><Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>');
        }
        updatedArchive.addFile(ArchiveFile('[Content_Types].xml', ctStr.length, utf8.encode(ctStr)));
      }
    } else {
      // Re-add original sheet and content types if no images
      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
      if (sheetFile != null) updatedArchive.addFile(sheetFile);
      final ctFile = archive.findFile('[Content_Types].xml');
      if (ctFile != null) updatedArchive.addFile(ctFile);
    }

    final finalExcelData = ZipEncoder().encode(updatedArchive);
    if (finalExcelData == null) return;

    final tempDir = await getTemporaryDirectory();
    final cleanClass = sanitize(className);
    final cleanSection = sanitize(sectionName);
    final excelFile = File('${tempDir.path}/Catalog_${cleanClass}_$cleanSection.xlsx');
    await excelFile.writeAsBytes(finalExcelData);

    await Share.shareXFiles(
      [XFile(excelFile.path)],
      text: 'Excel Photo Catalog for $className $sectionName ($schoolName)',
    );
  }
}
