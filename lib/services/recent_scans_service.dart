import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentScan {
  final String id;
  final String pdfPath;
  final String thumbnailPath;
  final List<String> imagePaths;
  final int pageCount;
  final DateTime createdAt;

  RecentScan({
    required this.id,
    required this.pdfPath,
    required this.thumbnailPath,
    required this.imagePaths,
    required this.pageCount,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pdfPath': pdfPath,
        'thumbnailPath': thumbnailPath,
        'imagePaths': imagePaths,
        'pageCount': pageCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecentScan.fromJson(Map<String, dynamic> json) => RecentScan(
        id: json['id'],
        pdfPath: json['pdfPath'],
        thumbnailPath: json['thumbnailPath'],
        imagePaths: List<String>.from(json['imagePaths'] ?? [json['thumbnailPath']]),
        pageCount: json['pageCount'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class RecentScansService {
  static const _key = 'recent_scans';
  static const _maxScans = 20;

  Future<List<RecentScan>> getRecentScans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList
        .map((s) => RecentScan.fromJson(jsonDecode(s)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> addScan({
    required String pdfPath,
    required String thumbnailPath,
    required List<String> imagePaths,
    required int pageCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final scan = RecentScan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pdfPath: pdfPath,
      thumbnailPath: thumbnailPath,
      imagePaths: imagePaths,
      pageCount: pageCount,
      createdAt: DateTime.now(),
    );
    existing.add(jsonEncode(scan.toJson()));
    if (existing.length > _maxScans) {
      existing.removeAt(0);
    }
    await prefs.setStringList(_key, existing);
  }

  Future<void> deleteScan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_key, existing);
  }
}
