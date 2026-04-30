import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/config.dart';
import '../models/models.dart';
import '../services/local_db.dart';
import '../services/supabase_service.dart';
import '../widgets/widgets.dart';

class HistoriqueScreen extends StatefulWidget {
  final String collectriceId;
  const HistoriqueScreen({super.key, required this.collectriceId});
  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  List<ScanRecord> _scans = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await LocalDB.getTodayScans(widget.collectriceId);
    if (mounted)
      setState(() {
        _scans = data;
        _loading = false;
      });
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
    });
    final result = await SupabaseService.syncAll();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Sync: ${result['success']} réussies, ${result['failed']} échouées'),
        backgroundColor: result['failed'] == 0
            ? const Color(AppColors.green)
            : const Color(AppColors.orange),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _scans.fold<double>(0, (s, c) => s + c.montant);
    final fmt = NumberFormat('#,###', 'fr_FR');
    final unsynced = _scans.where((s) => !s.synced).length;

    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      appBar: AppBar(
        backgroundColor: const Color(AppColors.bg2),
        elevation: 0,
        title: const Text('Historique du jour',
            style: TextStyle(
                color: Color(AppColors.text1),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(AppColors.text2)),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (unsynced > 0)
            TextButton.icon(
              onPressed: _syncing ? null : _sync,
              icon: _syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Color(AppColors.blue), strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded,
                      size: 16, color: Color(AppColors.blue)),
              label: Text('$unsynced non sync',
                  style: const TextStyle(
                      color: Color(AppColors.blue), fontSize: 11)),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(AppColors.blue)))
          : Column(children: [
              // Total
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(AppColors.blue).withOpacity(0.2),
                    const Color(AppColors.blue).withOpacity(0.05)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(AppColors.blue).withOpacity(0.3)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL DU JOUR',
                                style: TextStyle(
                                    color: Color(AppColors.text3),
                                    fontSize: 10,
                                    letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                                '${_scans.length} collecte${_scans.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                    color: Color(AppColors.text2),
                                    fontSize: 12)),
                          ]),
                      Text('${fmt.format(total)} F',
                          style: const TextStyle(
                              color: Color(AppColors.blue),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace')),
                    ]),
              ),

              // Liste
              Expanded(
                child: _scans.isEmpty
                    ? const Center(
                        child: Text('Aucune collecte aujourd\'hui',
                            style: TextStyle(color: Color(AppColors.text3))))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(AppColors.blue),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _scans.length,
                          itemBuilder: (_, i) {
                            final s = _scans[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(AppColors.bg2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: s.synced
                                        ? const Color(AppColors.green)
                                            .withOpacity(0.2)
                                        : const Color(AppColors.orange)
                                            .withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                // Photo thumbnail
                                if (s.photoPath != null)
                                  Container(
                                    width: 48,
                                    height: 48,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(AppColors.bg3)),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(File(s.photoPath!),
                                            fit: BoxFit.cover)),
                                  )
                                else
                                  Container(
                                    width: 48,
                                    height: 48,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(AppColors.bg3)),
                                    child: const Icon(Icons.person_rounded,
                                        color: Color(AppColors.text3),
                                        size: 24),
                                  ),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          'Client ${s.clientId.substring(0, 8)}...',
                                          style: const TextStyle(
                                              color: Color(AppColors.text1),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(
                                          DateFormat('HH:mm')
                                              .format(s.scannedAt),
                                          style: const TextStyle(
                                              color: Color(AppColors.text3),
                                              fontSize: 11)),
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        if (s.photoPath != null)
                                          StatusBadge(
                                              label: '📷',
                                              color:
                                                  const Color(AppColors.blue)),
                                        if (s.photoPath != null)
                                          const SizedBox(width: 4),
                                        StatusBadge(
                                            label: s.gpsValide
                                                ? '📍 GPS'
                                                : '⚠️ GPS',
                                            color: s.gpsValide
                                                ? const Color(AppColors.green)
                                                : const Color(
                                                    AppColors.orange)),
                                      ]),
                                    ])),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                          '${NumberFormat('#,###', 'fr_FR').format(s.montant)} F',
                                          style: const TextStyle(
                                              color: Color(AppColors.text1),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              fontFamily: 'monospace')),
                                      const SizedBox(height: 4),
                                      StatusBadge(
                                          label:
                                              s.synced ? '✓ sync' : '⏳ local',
                                          color: s.synced
                                              ? const Color(AppColors.green)
                                              : const Color(AppColors.orange)),
                                    ]),
                              ]),
                            );
                          },
                        ),
                      ),
              ),
            ]),
    );
  }
}
