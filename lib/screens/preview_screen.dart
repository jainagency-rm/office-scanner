import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../widgets/loading_overlay.dart';
import 'result_screen.dart';
import 'scanner_screen.dart';

/// Runs rotation/brightness off the UI isolate. Always re-derives from the
/// original bytes so repeated brightness adjustments don't compound.
Uint8List _processImage(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final rotation = args['rotation'] as int;
  final brightness = args['brightness'] as double;
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Unable to decode image');
  }
  if (rotation != 0) {
    image = img.copyRotate(image, angle: rotation);
  }
  if (brightness != 0) {
    image = img.adjustColor(image, brightness: 1.0 + brightness);
  }
  return img.encodeJpg(image, quality: 90);
}

class _ScanPage {
  String path;
  Uint8List? originalBytes;
  int rotation = 0;
  double brightness = 0.0;
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
    if (page.rotation == 0 && page.brightness == 0) {
      page.displayBytes = null;
      return;
    }
    final bytes = await _loadOriginalBytes(page);
    page.displayBytes = await compute(_processImage, {
      'bytes': bytes,
      'rotation': page.rotation,
      'brightness': page.brightness,
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

  Future<void> _commitBrightness(double value) async {
    final page = _current;
    final previous = page.brightness;
    setState(() {
      _busy = true;
      _busyMessage = 'Adjusting brightness...';
    });
    try {
      page.brightness = value;
      await _recompute(page);
    } catch (e) {
      page.brightness = previous;
      _showError('Could not adjust brightness: $e');
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
      if (page.rotation != 0 || page.brightness != 0) {
        if (page.displayBytes == null) {
          await _recompute(page);
        }
        final file = File(
          '${tempDir.path}/edited_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await file.writeAsBytes(page.displayBytes!, flush: true);
        page.path = file.path;
        page.rotation = 0;
        page.brightness = 0;
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
      _busyMessage = 'Finishing up...';
    });
    try {
      final paths = await _commitEditsAndGetPaths();
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(imagePaths: paths)),
      );
    } catch (e) {
      _showError('Could not finish: $e');
    } finally {
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
              Row(
                children: [
                  const Icon(Icons.brightness_6),
                  Expanded(
                    child: Slider(
                      value: _current.brightness,
                      min: -1.0,
                      max: 1.0,
                      onChanged: (v) => setState(() => _current.brightness = v),
                      onChangeEnd: _busy ? null : _commitBrightness,
                    ),
                  ),
                ],
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
                  label: const Text('Done — Save & Share'),
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
