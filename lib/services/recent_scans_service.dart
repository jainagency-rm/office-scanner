import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatScanName(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = _monthAbbreviations[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return 'Scan $day-$month-${dt.year} $hour:$minute';
}

class RecentScan {
  final String id;
  final String name;
  final String pdfPath;
  final String thumbnailPath;
  final List<String> imagePaths;
  final int pageCount;
  final DateTime createdAt;

  RecentScan({
    required this.id,
    required this.name,
    required this.pdfPath,
    required this.thumbnailPath,
    required this.imagePaths,
    required this.pageCount,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pdfPath': pdfPath,
        'thumbnailPath': thumbnailPath,
        'imagePaths': imagePaths,
        'pageCount': pageCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecentScan.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt']);
    return RecentScan(
      id: json['id'],
      name: json['name'] ?? formatScanName(createdAt),
      pdfPath: json['pdfPath'],
      thumbnailPath: json['thumbnailPath'],
      imagePaths: List<String>.from(json['imagePaths'] ?? [json['thumbnailPath']]),
      pageCount: json['pageCount'],
      createdAt: createdAt,
    );
  }
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

  Future<String> addScan({
    required String pdfPath,
    required String thumbnailPath,
    required List<String> imagePaths,
    required int pageCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final createdAt = DateTime.now();
    final scan = RecentScan(
      id: createdAt.millisecondsSinceEpoch.toString(),
      name: formatScanName(createdAt),
      pdfPath: pdfPath,
      thumbnailPath: thumbnailPath,
      imagePaths: imagePaths,
      pageCount: pageCount,
      createdAt: createdAt,
    );
    existing.add(jsonEncode(scan.toJson()));
    if (existing.length > _maxScans) {
      existing.removeAt(0);
    }
    await prefs.setStringList(_key, existing);
    return scan.id;
  }

  Future<void> updateScan({
    required String id,
    required List<String> imagePaths,
    required int pageCount,
    String? pdfPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final updated = existing.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      if (map['id'] == id) {
        map['imagePaths'] = imagePaths;
        map['pageCount'] = pageCount;
        if (pdfPath != null) map['pdfPath'] = pdfPath;
        return jsonEncode(map);
      }
      return s;
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  Future<void> renameScan(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final updated = existing.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      if (map['id'] == id) {
        map['name'] = newName;
        return jsonEncode(map);
      }
      return s;
    }).toList();
    await prefs.setStringList(_key, updated);
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
