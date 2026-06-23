import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'app_state.dart';
import 'screens/recent_scans_screen.dart';
import 'screens/result_screen.dart';
import 'screens/scanner_screen.dart';

int globalCurrentTab = 0;
void Function(int)? globalSwitchTab;

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
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static void switchToRecentScans(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?.switchTab(1);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    shellTabIndex.addListener(_onTabChange);
    globalSwitchTab = (index) => setState(() => _currentIndex = index);
  }

  void _onTabChange() => switchTab(shellTabIndex.value);

  @override
  void dispose() {
    shellTabIndex.removeListener(_onTabChange);
    super.dispose();
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? const HomeTab()
          : const RecentScansScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Recent Scans',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const _imageExtensions = {'jpg', 'jpeg', 'png'};
  bool _busy = false;

  Future<void> _scanSingle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(multiPage: false),
      ),
    );
  }

  Future<void> _scanMultiple() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(multiPage: true),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(imagePaths: imagePaths)),
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
            const SizedBox(height: 24),
            const Icon(Icons.document_scanner, size: 56, color: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'Office Scanner',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  children: [
                    _ActionButton(
                      onTap: _busy ? null : _scanSingle,
                      icon: Icons.document_scanner,
                      label: 'Scan Single Page',
                      subtitle: 'Scan one document at a time',
                      color: const Color(0xFF1565C0),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      onTap: _busy ? null : _scanMultiple,
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan Multiple Pages',
                      subtitle: 'Scan multiple pages in one go',
                      color: const Color(0xFF6A1B9A),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      onTap: _busy ? null : _pickFromGallery,
                      icon: Icons.photo_library,
                      label: 'Import from Gallery',
                      subtitle: 'Select images from your gallery',
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 12),
                    _ActionButton(
                      onTap: _busy ? null : _pickFromFiles,
                      icon: Icons.folder_open,
                      label: 'Import from Files',
                      subtitle: 'Pick from Files, Drive, WhatsApp etc.',
                      color: const Color(0xFFE65100),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
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
