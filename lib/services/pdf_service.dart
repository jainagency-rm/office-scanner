import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'storage_service.dart';

class PdfService {
  final StorageService _storageService = StorageService();

  /// Builds a one-page-per-image PDF from [imagePaths] and writes it to a
  /// temp file. Throws if [imagePaths] is empty or an image can't be read.
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
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
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

  /// Copies [pdf] into the shared Downloads folder. Returns the saved path,
  /// or null if the save failed (e.g. scoped storage denial).
  Future<String?> saveToDownloads(File pdf) async {
    final saved = await _storageService.saveFileToDownloads(pdf);
    return saved?.path;
  }
}
