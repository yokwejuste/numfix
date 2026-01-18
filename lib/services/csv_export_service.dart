import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contact_result.dart';
import 'downloads_service.dart';

class CsvExportService {
  static Future<String?> exportToCsv(
    List<ContactResult> results, {
    bool autoOpen = true,
  }) async {
    try {
      final csvContent = _generateCsvContent(results);
      if (csvContent.isEmpty) {
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'numfyx_report_$timestamp.csv';

      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = '${appDocDir.path}/$fileName';

      final saved = await _writeAndVerify(appDocPath, csvContent);
      if (!saved) {
        return null;
      }

      final csvBytes = Uint8List.fromList(csvContent.codeUnits);
      final publicPath = await _tryCopyToDownloads(fileName, csvBytes);
      final finalPath = publicPath ?? appDocPath;

      if (autoOpen) {
        try {
          await OpenFilex.open(finalPath);
        } catch (e) {}
      }

      return finalPath;
    } catch (e, st) {
      debugPrint('CsvExportService: Export failed: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  static String _generateCsvContent(List<ContactResult> results) {
    final sb = StringBuffer();
    sb.writeln('Contact,Original,Final,Status');

    for (final r in results) {
      final contact = _escapeCsv(r.contactName);
      final original = _escapeCsv(r.originalNumber);
      final final_ = _escapeCsv(r.finalNumber);
      final status = _escapeCsv(r.status);
      sb.writeln('$contact,$original,$final_,$status');
    }

    return sb.toString();
  }

  static String _escapeCsv(String value) {
    var clean = value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.contains(',') || clean.contains('"') || clean.contains('\n')) {
      clean = clean.replaceAll('"', '""');
      return '"$clean"';
    }

    return clean;
  }

  static Future<bool> _writeAndVerify(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);

      if (!await file.exists()) {
        return false;
      }

      final written = await file.readAsString();
      if (written.length != content.length) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _tryCopyToDownloads(String fileName, Uint8List bytes) async {
    if (!Platform.isAndroid) return null;

    final savedPath = await DownloadsService.saveToDownloads(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
    );

    return savedPath;
  }
}
