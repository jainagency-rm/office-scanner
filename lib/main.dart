import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'screens/preview_screen.dart';
import 'screens/scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _imageExtensions = {'jpg', 'jpeg', 'png'};
  bool _busy = false;

  Future<void> _scanDocument() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            imagePaths: images.map((x) => x.path).toList(),
          ),
        ),
      );
    } catch (e) {
      _showError("Gallery error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromFiles() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final imagePaths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .where((p) => _imageExtensions.contains(p.split('.').last.toLowerCase()))
          .toList();
      if (imagePaths.isEmpty) {
        _showError('No valid image files selected.');
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PreviewScreen(imagePaths: imagePaths)),
      );
    } catch (e) {
      _showError("File picker error: $e");
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
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.document_scanner, size: 72, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'Office Scanner',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan, edit and share documents',
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 48),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                child: Column(
                  children: [
                    _ActionButton(
                      onTap: _busy ? null : _scanDocument,
                      icon: Icons.camera_alt,
                      label: 'Scan Document',
                      subtitle: 'Use camera with auto edge detection',
                      color: const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 16),
                    _ActionButton(
                      onTap: _busy ? null : _pickFromGallery,
                      icon: Icons.photo_library,
                      label: 'Import from Gallery',
                      subtitle: 'Select images from your gallery',
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 16),
                    _ActionButton(
                      onTap: _busy ? null : _pickFromFiles,
                      icon: Icons.folder_open,
                      label: 'Import from Files',
                      subtitle: 'Pick from Files, Drive, WhatsApp etc.',
                      color: const Color(0xFFE65100),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}