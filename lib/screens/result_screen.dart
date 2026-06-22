import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../widgets/loading_overlay.dart';

class ResultScreen extends StatefulWidget {
  final List<String> imagePaths;

  const ResultScreen({super.key, required this.imagePaths});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _pdfService = PdfService();
  final _storageService = StorageService();
  bool _busy = false;
  String _busyMessage = '';

  Future<void> _withBusy(String message, Future<void> Function() action) async {
    setState(() { _busy = true; _busyMessage = message; });
    try {
      await action();
    } catch (e) {
      _showMessage('Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAsPdf() => _withBusy('Generating PDF...', () async {
    final pdf = await _pdfService.generatePdf(widget.imagePaths);
    final savedPath = await _pdfService.saveToDownloads(pdf);
    if (savedPath != null) {
      _showMessage('PDF saved to Downloads');
    } else {
      _showMessage('Could not save PDF', isError: true);
    }
  });

  Future<void> _saveAsJpg() => _withBusy('Saving images...', () async {
    var saved = 0;
    for (final path in widget.imagePaths) {
      if (await _storageService.saveImageToGallery(path)) saved++;
    }
    final total = widget.imagePaths.length;
    if (saved == total) {
      _showMessage('Saved $saved image(s) to gallery');
    } else {
      _showMessage('Saved $saved of $total images', isError: true);
    }
  });

  Future<void> _sharePdf() => _withBusy('Preparing PDF...', () async {
    final pdf = await _pdfService.generatePdf(widget.imagePaths);
    final bytes = await pdf.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: 'scan.pdf');
  });

  Future<void> _shareJpg() => _withBusy('Preparing images...', () async {
    await Share.shareXFiles(
      widget.imagePaths.map((p) => XFile(p)).toList(),
      text: 'Scanned document',
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${widget.imagePaths.length} Page${widget.imagePaths.length > 1 ? 's' : ''}'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: widget.imagePaths.isEmpty
            ? const Center(child: Text('No pages to show'))
            : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: widget.imagePaths.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(widget.imagePaths[index]),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ResultButton(
                                onTap: _busy ? null : _saveAsPdf,
                                icon: Icons.picture_as_pdf,
                                label: 'Save PDF',
                                color: const Color(0xFF1565C0),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ResultButton(
                                onTap: _busy ? null : _saveAsJpg,
                                icon: Icons.image,
                                label: 'Save JPG',
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ResultButton(
                                onTap: _busy ? null : _sharePdf,
                                icon: Icons.share,
                                label: 'Share PDF',
                                color: const Color(0xFFE65100),
                                outlined: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ResultButton(
                                onTap: _busy ? null : _shareJpg,
                                icon: Icons.share,
                                label: 'Share JPG',
                                color: const Color(0xFF6A1B9A),
                                outlined: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;

  const _ResultButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
