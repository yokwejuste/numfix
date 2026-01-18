import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/contact_result.dart';
import 'downloads_service.dart';

class PdfExportService {
  static Future<String?> exportToPdf(
    List<ContactResult> results, {
    bool onlyIncludeUpdated = false,
    bool autoOpen = true,
  }) async {
    try {
      if (onlyIncludeUpdated) {
        results = results.where((r) => r.status == 'Updated').toList();
      }

      final bytes = await _generatePdfBytes(results);
      if (bytes == null) {
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'numfyx_report_$timestamp.pdf';

      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = '${appDocDir.path}/$fileName';

      final saved = await _writeAndVerify(appDocPath, bytes);
      if (!saved) {
        return null;
      }

      final publicPath = await _tryCopyToDownloads(appDocPath, fileName, bytes);
      final finalPath = publicPath ?? appDocPath;

      if (autoOpen) {
        try {
          final result = await OpenFilex.open(finalPath);
        } catch (e) {}
      }

      return finalPath;
    } catch (e, st) {
      return null;
    }
  }

  static Future<Uint8List?> _generatePdfBytes(List<ContactResult> results) async {
    try {
      final pdf = pw.Document();

      final succeededResults = results.where((r) => r.status == 'Updated').toList();
      final failedResults = results.where((r) => r.status.startsWith('Failed')).toList();
      final skippedResults = results.where((r) => r.status.startsWith('Skipped')).toList();

      final summaryData = [
        ['Total Processed', '${results.length}'],
        ['Succeeded', '${succeededResults.length}'],
        ['Failed', '${failedResults.length}'],
        ['Skipped', '${skippedResults.length}'],
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            final widgets = <pw.Widget>[];

            widgets.add(
              pw.Header(
                level: 0,
                child: pw.Text(
                  'NumFyx Contact Processing Report',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Text(
                'Generated: ${DateTime.now().toString().substring(0, 19)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            );
            widgets.add(pw.SizedBox(height: 15));

            widgets.add(
              pw.Text(
                'Summary',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            );
            widgets.add(pw.SizedBox(height: 5));
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Count'],
                data: summaryData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
            );
            widgets.add(pw.SizedBox(height: 20));

            if (results.isNotEmpty) {
              widgets.add(
                pw.Text(
                  'Contact Results',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(pw.SizedBox(height: 10));

              final rows = results.map((r) => [
                _sanitize(r.contactName),
                _sanitize(r.originalNumber),
                _sanitize(r.finalNumber),
                _sanitize(r.status),
              ]).toList();

              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Contact', 'Original', 'Final', 'Status'],
                  data: rows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellHeight: 20,
                ),
              );
            }

            return widgets;
          },
        ),
      );

      final bytes = await pdf.save();

      if (bytes.length < 8 || bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
        return null;
      }

      return bytes;
    } catch (e, st) {
      return null;
    }
  }

  static Future<bool> _writeAndVerify(String path, Uint8List bytes) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      if (!await file.exists()) {
        return false;
      }

      final written = await file.readAsBytes();
      if (written.length != bytes.length) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> _tryCopyToDownloads(String sourcePath, String fileName, Uint8List bytes) async {
    if (!Platform.isAndroid) return null;

    final savedPath = await DownloadsService.saveToDownloads(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );

    return savedPath;
  }

  static String _sanitize(String text) {
    return text
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
