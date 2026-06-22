import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'storage_service.dart';

class PdfService {
  final StorageService _storageService = StorageService();

  Future<File> generatePdf(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('No images to convert to PDF');
    }
    final document = pw.Document();
    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.FittedBox(
            fit: pw.BoxFit.fill,
            child: pw.Image(image),
          ),
        ),
      );
    }
    final bytes = await document.save();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String?> saveToDownloads(File pdf) async {
    final saved = await _storageService.saveFileToDownloads(pdf);
    return saved?.path;
  }
}