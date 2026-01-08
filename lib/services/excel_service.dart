import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/contact_result.dart';

class ExcelService {
  static String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String?> exportResults(List<ContactResult> results) async {
    try {
      final pdf = pw.Document();

      final updatedResults = results
          .where((r) => r.status == 'Updated')
          .toList();
      final failedResults = results
          .where((r) => r.status == 'Failed (invalid)')
          .toList();
      final skippedResults = results
          .where((r) => r.status.startsWith('Skipped'))
          .toList();

      final summaryData = [
        ['Total Processed', '${results.length}'],
        ['Updated', '${updatedResults.length}'],
        ['Failed', '${failedResults.length}'],
        ['Skipped', '${skippedResults.length}'],
      ];

      List<pw.Widget> buildPage(List<ContactResult> pageResults, String title) {
        return [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Contact', 'Original', 'Final', 'Status'],
            data: pageResults
                .map(
                  (result) => [
                    _sanitizeText(result.contactName),
                    _sanitizeText(result.originalNumber),
                    _sanitizeText(result.finalNumber),
                    _sanitizeText(result.status),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 20,
          ),
        ];
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'NumFyx Contact Processing Report',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated: ${DateTime.now().toString().substring(0, 19)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Summary',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Count'],
                data: summaryData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
              ),
              pw.SizedBox(height: 20),
              if (updatedResults.isNotEmpty) ...[
                ...buildPage(
                  updatedResults.take(100).toList(),
                  'Updated Numbers (first 100)',
                ),
                pw.SizedBox(height: 20),
              ],
              if (failedResults.isNotEmpty) ...[
                ...buildPage(failedResults, 'Failed Numbers'),
                pw.SizedBox(height: 20),
              ],
            ];
          },
        ),
      );

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      directory ??= await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/numfyx_report_$timestamp.pdf';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      return filePath;
    } catch (e) {
      return null;
    }
  }
}
