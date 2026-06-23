import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import '../services/recent_scans_service.dart';
import '../services/storage_service.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  final List<String> existingImages;
  final bool multiPage;
  final String? existingScanId;

  const ScannerScreen({
    super.key,
    this.existingImages = const [],
    this.multiPage = false,
    this.existingScanId,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() => _error = null);
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: widget.multiPage ? 100 : 1,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      if (!mounted) return;
      if (result.images.isEmpty) {
        Navigator.pop(context);
        return;
      }
      final storageService = StorageService();
      final permanentNewImages = <String>[];
      for (final path in result.images) {
        final permanent = await storageService.saveImagePermanently(path);
        permanentNewImages.add(permanent ?? path);
      }

      final combined = [...widget.existingImages, ...permanentNewImages];
      if (widget.existingScanId != null) {
        final recentScansService = RecentScansService();
        await recentScansService.updateScan(
          id: widget.existingScanId!,
          imagePaths: combined,
          pageCount: combined.length,
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(imagePaths: combined)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Scan failed: $e');
    } finally {
      await scanner.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                          const SizedBox(width: 16),
                          ElevatedButton(onPressed: _scan, child: const Text('Retry')),
                        ],
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
