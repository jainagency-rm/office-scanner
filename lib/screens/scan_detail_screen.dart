import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';
import '../services/recent_scans_service.dart';
import '../services/storage_service.dart';
import '../screens/scanner_screen.dart';
import '../widgets/loading_overlay.dart';

class ScanDetailScreen extends StatefulWidget {
  final RecentScan scan;

  const ScanDetailScreen({super.key, required this.scan});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  final _pdfService = PdfService();
  final _storageService = StorageService();
  final _recentScansService = RecentScansService();
  bool _busy = false;
  String _busyMessage = '';

  Future<void> _withBusy(String message, Future<void> Function() action) async {
    setState(() { _busy = true; _busyMessage = message; });
    try {
      await action();
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _addPages() async {
    final countBefore = (await _recentScansService.getRecentScans()).length;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
        existingImages: [widget.scan.thumbnailPath],
        multiPage: true,
      ),
      ),
    );

    // If user saved a new combined scan, the old entry is now a duplicate — remove it.
    final scansAfter = await _recentScansService.getRecentScans();
    if (scansAfter.length > countBefore) {
      await _recentScansService.deleteScan(widget.scan.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _savePdf() => _withBusy('Saving PDF...', () async {
    final pdf = File(widget.scan.pdfPath);
    if (!pdf.existsSync()) {
      _showMessage('PDF file not found', isError: true);
      return;
    }
    final saved = await _storageService.saveFileToDownloads(pdf);
    if (saved != null) {
      _showMessage('PDF saved');
    } else {
      _showMessage('Could not save PDF', isError: true);
    }
  });

  Future<void> _sharePdf() => _withBusy('Preparing PDF...', () async {
    final pdf = File(widget.scan.pdfPath);
    if (!pdf.existsSync()) {
      _showMessage('PDF file not found', isError: true);
      return;
    }
    final bytes = await pdf.readAsBytes();
    await Printing.sharePdf(bytes: bytes, filename: 'scan.pdf');
  });

  Future<void> _saveAsJpg() => _withBusy('Saving image...', () async {
    final saved = await _storageService.saveImageToGallery(widget.scan.thumbnailPath);
    if (saved) {
      _showMessage('Image saved');
    } else {
      _showMessage('Could not save image', isError: true);
    }
  });

  Future<void> _shareJpg() => _withBusy('Preparing images...', () async {
    await Share.shareXFiles(
      [XFile(widget.scan.thumbnailPath)],
      text: 'Scanned document',
    );
  });

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text('Are you sure you want to delete this scan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _recentScansService.deleteScan(widget.scan.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${widget.scan.pageCount} Page${widget.scan.pageCount > 1 ? 's' : ''}'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: Column(
          children: [
Expanded(
              child: widget.scan.imagePaths.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Preview not available', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : PageView.builder(
                      itemCount: widget.scan.imagePaths.length,
                      itemBuilder: (context, index) {
                        final path = widget.scan.imagePaths[index];
                        return File(path).existsSync()
                            ? Image.file(File(path), fit: BoxFit.contain)
                            : Center(
                                child: Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400),
                              );
                      },
                    ),
            ),            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _addPages,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add More Pages'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _savePdf,
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                          label: const Text('Save PDF', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _sharePdf,
                          icon: const Icon(Icons.share),
                          label: const Text('Share PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _saveAsJpg,
                          icon: const Icon(Icons.image, color: Colors.white),
                          label: const Text('Save JPG', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _shareJpg,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Share as Image'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
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
