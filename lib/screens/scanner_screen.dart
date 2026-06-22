import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

import 'preview_screen.dart';

class ScannerScreen extends StatefulWidget {
  final List<String> existingImages;
  final bool multiPage;

  const ScannerScreen({
    super.key,
    this.existingImages = const [],
    this.multiPage = false,
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
      final combined = [...widget.existingImages, ...result.images];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PreviewScreen(imagePaths: combined)),
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
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _scan,
                            child: const Text('Retry'),
                          ),
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
