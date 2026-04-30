import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'local_db.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ── CLIENTS ──
  static Future<Client?> getClientByQR(String qrData) async {
    try {
      // QR contient l'ID du client
      final data = await _client
          .from('collectrices') // utilise la table clients si elle existe
          .select()
          .eq('id', qrData)
          .eq('actif', true)
          .maybeSingle();
      return data != null ? Client.fromMap(data) : null;
    } catch (_) {
      return null;
    }
  }

  // ── UPLOAD PHOTO ──
  static Future<String?> uploadPhoto(String localPath, String scanId) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final fileName = 'scans/$scanId.jpg';

      await _client.storage.from('photos').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      return _client.storage.from('photos').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // ── SYNC SCAN ──
  static Future<bool> syncScan(ScanRecord scan) async {
    try {
      await _client.from('collectes').insert({
        'collectrice_id': scan.collectriceId,
        'client_nom': scan.clientId,
        'montant_reel': scan.montant,
        'latitude': scan.latitude,
        'longitude': scan.longitude,
        'statut': 'validee',
        'photo_url': scan.photoUrl,
      });
      await LocalDB.markSynced(scan.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── SYNC ALL PENDING ──
  static Future<Map<String, int>> syncAll() async {
    final unsynced = await LocalDB.getUnsynced();
    int success = 0, failed = 0;

    for (final scan in unsynced) {
      // Upload photo si pas encore uploadée
      String? photoUrl = scan.photoUrl;
      if (scan.photoPath != null && photoUrl == null) {
        photoUrl = await uploadPhoto(scan.photoPath!, scan.id);
      }

      final updatedScan = ScanRecord(
        id: scan.id,
        clientId: scan.clientId,
        collectriceId: scan.collectriceId,
        montant: scan.montant,
        photoPath: scan.photoPath,
        photoUrl: photoUrl,
        latitude: scan.latitude,
        longitude: scan.longitude,
        gpsValide: scan.gpsValide,
        scannedAt: scan.scannedAt,
      );

      final ok = await syncScan(updatedScan);
      if (ok) success++; else failed++;
    }
    return {'success': success, 'failed': failed};
  }
}
