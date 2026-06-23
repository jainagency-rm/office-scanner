import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../services/pdf_service.dart';
import '../services/recent_scans_service.dart';
import '../widgets/loading_overlay.dart';
import 'scanner_screen.dart';

enum ScanFilter {
  noShadow('No Shadow'),
  original('Original'),
  lighten('Lighten'),
  magicColor('Magic Color'),
  grayscale('Grayscale'),
  blackAndWhite('B&W');

  final String label;
  const ScanFilter(this.label);
}

img.Image _applyFilter(img.Image image, ScanFilter filter) {
  switch (filter) {
    case ScanFilter.noShadow:
      return img.adjustColor(image, brightness: 1.25, contrast: 1.3);
    case ScanFilter.lighten:
      return img.adjustColor(image, brightness: 1.3);
    case ScanFilter.magicColor:
      final normalized = img.normalize(image, min: 0, max: 255);
      return img.adjustColor(normalized, contrast: 1.2, saturation: 1.3);
    case ScanFilter.grayscale:
      return img.grayscale(image);
    case ScanFilter.blackAndWhite:
      final gray = img.grayscale(image);
      return img.adjustColor(gray, contrast: 2.5);
    case ScanFilter.original:
      return image;
  }
}

/// Runs rotation/filter off the UI isolate. Always re-derives from the
/// original bytes so repeated filter changes don't compound.
Uint8List _processImage(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final rotation = args['rotation'] as int;
  final filter = ScanFilter.values.byName(args['filter'] as String);
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode image');
  }
  if (rotation != 0) {
    image = img.copyRotate(image, angle: rotation);
  }
  image = _applyFilter(image, filter);
  return img.encodeJpg(image, quality: 90);
}

class _ScanPage {
  String path;
  Uint8List? originalBytes;
  int rotation = 0;
  ScanFilter filter = ScanFilter.original;
  Uint8List? displayBytes;

  _ScanPage(this.path);
}

class PreviewScreen extends StatefulWidget {
  final List<String> imagePaths;

  const PreviewScreen({super.key, required this.imagePaths});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late List<_ScanPage> _pages;
  final _pageController = PageController();
  final _pdfService = PdfService();
  final _recentScansService = RecentScansService();
  int _currentIndex = 0;
  bool _busy = false;
  String _busyMessage = '';

  @override
  void initState() {
    super.initState();
    _pages = widget.imagePaths.map((p) => _ScanPage(p)).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  _ScanPage get _current => _pages[_currentIndex];

  Future<Uint8List> _loadOriginalBytes(_ScanPage page) async {
    return page.originalBytes ??= await File(page.path).readAsBytes();
  }

  Future<void> _recompute(_ScanPage page) async {
    if (page.rotation == 0 && page.filter == ScanFilter.original) {
      page.displayBytes = null;
      return;
    }
    final bytes = await _loadOriginalBytes(page);
    page.displayBytes = await compute(_processImage, {
      'bytes': bytes,
      'rotation': page.rotation,
      'filter': page.filter.name,
    });
  }

  Future<void> _rotate() async {
    final page = _current;
    final previousRotation = page.rotation;
    setState(() {
      _busy = true;
      _busyMessage = 'Rotating...';
    });
    try {
      page.rotation = (page.rotation + 90) % 360;
      await _recompute(page);
    } catch (e) {
      page.rotation = previousRotation;
      _showError('Could not rotate image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectFilter(ScanFilter filter) async {
    final page = _current;
    final previous = page.filter;
    setState(() {
      _busy = true;
      _busyMessage = 'Applying filter...';
    });
    try {
      page.filter = filter;
      await _recompute(page);
    } catch (e) {
      page.filter = previous;
      _showError('Could not apply filter: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _deleteCurrentPage() {
    if (_pages.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pages.removeAt(_currentIndex);
      if (_currentIndex >= _pages.length) {
        _currentIndex = _pages.length - 1;
      }
    });
    _pageController.jumpToPage(_currentIndex);
  }

  /// Bakes any pending rotation/brightness edits into new files on disk and
  /// returns the up-to-date path list. Needed before handing pages off to
  /// the scanner (add more) or the result screen, since neither knows about
  /// in-memory edits.
  Future<List<String>> _commitEditsAndGetPaths() async {
    final tempDir = await getTemporaryDirectory();
    final paths = <String>[];
    for (final page in _pages) {
      if (page.rotation != 0 || page.filter != ScanFilter.original) {
        if (page.displayBytes == null) {
          await _recompute(page);
        }
        final file = File(
          '${tempDir.path}/edited_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(page.displayBytes!, flush: true);
        page.path = file.path;
        page.rotation = 0;
        page.filter = ScanFilter.original;
        page.originalBytes = null;
        page.displayBytes = null;
      }
      paths.add(page.path);
    }
    return paths;
  }

  Future<void> _addMore() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Saving edits...';
    });
    try {
      final paths = await _commitEditsAndGetPaths();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ScannerScreen(existingImages: paths),
        ),
      );
    } catch (e) {
      _showError('Could not prepare pages: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _done() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Saving...';
    });
    try {
      final paths = await _commitEditsAndGetPaths();
      if (!mounted) return;
      final pdf = await _pdfService.generatePdf(paths);
      final savedPath = await _pdfService.saveToDownloads(pdf);
      if (savedPath == null) {
        _showError('Could not save PDF. Check storage permissions.');
        setState(() => _busy = false);
        return;
      }
      await _recentScansService.addScan(
        pdfPath: savedPath,
        thumbnailPath: paths.first,
        imagePaths: paths,
        pageCount: paths.length,
      );
      if (!mounted) return;
      shellTabIndex.value = 1;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showError('Could not save: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(body: Center(child: Text('No pages to preview')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Page ${_currentIndex + 1} of ${_pages.length}'),
        actions: [],
      ),
      body: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final page = _pages[index];
            return Center(
              child: page.displayBytes != null
                  ? Image.memory(page.displayBytes!)
                  : Image.file(File(page.path)),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: ScanFilter.values.map((f) {
                    final selected = _current.filter == f;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: _busy ? null : () => _selectFilter(f),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selected ? Colors.teal : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: selected ? Border.all(color: Colors.teal, width: 2) : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.teal : Colors.grey.shade700,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _busy ? null : _rotate,
                    icon: const Icon(Icons.rotate_right),
                    tooltip: 'Rotate',
                  ),
                  IconButton(
                    onPressed: _busy ? null : _deleteCurrentPage,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete page',
                  ),
                  IconButton(
                    onPressed: _busy ? null : _addMore,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    tooltip: 'Add more',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _done,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Done — Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
