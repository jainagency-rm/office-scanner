import 'dart:io';

import 'package:flutter/material.dart';

import '../services/recent_scans_service.dart';
import 'scan_detail_screen.dart';

class RecentScansScreen extends StatefulWidget {
  const RecentScansScreen({super.key});

  @override
  State<RecentScansScreen> createState() => _RecentScansScreenState();
}

class _RecentScansScreenState extends State<RecentScansScreen>
    with AutomaticKeepAliveClientMixin {
  final _service = RecentScansService();
  List<RecentScan> _scans = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _load();
  }

Future<void> _load() async {
    setState(() => _loading = true);
    final scans = await _service.getRecentScans();
    if (mounted) setState(() { _scans = scans; _loading = false; });
  }

  Future<void> _delete(RecentScan scan) async {
    await _service.deleteScan(scan.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Recent Scans'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No scans yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan a document and save it as PDF',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scans.length,
                    itemBuilder: (context, index) {
                      final scan = _scans[index];
                      return _ScanTile(
                        scan: scan,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanDetailScreen(scan: scan),
                            ),
                          );
                          _load();
                        },
                        onDelete: () => _delete(scan),
                      );
                    },
                  ),
                ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final RecentScan scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScanTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: File(scan.thumbnailPath).existsSync()
              ? Image.file(
                  File(scan.thumbnailPath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.picture_as_pdf, color: Colors.grey),
                ),
        ),
        title: Text(
          scan.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          '${scan.createdAt.day}/${scan.createdAt.month}/${scan.createdAt.year}  '
          '${scan.createdAt.hour}:${scan.createdAt.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
