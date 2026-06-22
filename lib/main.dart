import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Camera scan via ML Kit
  Future<void> scanDocument(BuildContext context) async {
    try {
      final scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          pageLimit: 10,
        ),
      );
      final result = await scanner.scanDocument();
      if (result != null && result.images.isNotEmpty) {
        debugPrint("Scanned: ${result.images}");
        // TODO: Navigate to preview screen
      }
    } catch (e) {
      _showError(context, "Scan failed: $e");
    }
  }

  // Gallery se multiple images pick karo
  Future<void> pickFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        debugPrint("Selected ${images.length} images");
        // TODO: Navigate to preview screen
      }
    } catch (e) {
      _showError(context, "Gallery error: $e");
    }
  }

  // Kisi bhi app se file pick karo (Files, Drive, WhatsApp, etc.)
  Future<void> pickFromFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        debugPrint("Picked ${result.files.length} files");
        // TODO: Navigate to preview screen
      }
    } catch (e) {
      _showError(context, "File picker error: $e");
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Document Scanner"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => scanDocument(context),
                icon: const Icon(Icons.document_scanner),
                label: const Text("Scan Document"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => pickFromGallery(context),
                icon: const Icon(Icons.photo_library),
                label: const Text("Import from Gallery"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => pickFromFiles(context),
                icon: const Icon(Icons.folder_open),
                label: const Text("Import from Files / Apps"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}