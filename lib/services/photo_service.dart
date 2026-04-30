import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class PhotoService {
  static List<CameraDescription> cameras = [];

  static Future<void> init() async {
    cameras = await availableCameras();
  }

  /// Ajoute un watermark anti-fraude sur la photo
  /// Date + Heure + Coordonnées GPS
  static Future<File?> addWatermark(
    String sourcePath, {
    required double latitude,
    required double longitude,
  }) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Formate les données pour le watermark
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final gpsStr =
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

      // Ajoute le watermark en bas à droite
      // Couleur blanche semi-transparente
      image = _addWatermarkText(
        image,
        dateStr: dateStr,
        timeStr: timeStr,
        gpsStr: gpsStr,
      );

      // Ré-encode en JPEG
      final watermarked = img.encodeJpg(image, quality: 85);

      // Sauvegarde avec préfixe watermark
      final dir = await getApplicationDocumentsDirectory();
      await Directory(p.join(dir.path, 'scans')).create(recursive: true);
      final fileName = 'photo_wm_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outPath = p.join(dir.path, 'scans', fileName);
      final outFile = File(outPath);
      await outFile.writeAsBytes(watermarked);

      return outFile;
    } catch (_) {
      return null;
    }
  }

  /// Ajoute le texte du watermark sur l'image
  static img.Image _addWatermarkText(
    img.Image image, {
    required String dateStr,
    required String timeStr,
    required String gpsStr,
  }) {
    // TODO: Implémenter le watermark avec la bonne bibliothèque image
    // Variables temporaires (non utilisées pour l'instant)
    // final textColor = img.ColorRgba8(255, 255, 255, 200);
    // final padding = 15;
    // final lineHeight = 18;
    // final textY = image.height - (lineHeight * 3) - padding;
    // final lines = [dateStr, timeStr, gpsStr];

    return image;
  }

  /// Compresse une photo à max 800 KB
  static Future<File?> compressPhoto(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize si trop grande
      if (image.width > 1280) {
        image = img.copyResize(image, width: 1280);
      }

      // Compression JPEG qualité 80
      final compressed = img.encodeJpg(image, quality: 80);

      // Sauvegarde
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outPath = p.join(dir.path, 'scans', fileName);
      await Directory(p.join(dir.path, 'scans')).create(recursive: true);
      final outFile = File(outPath);
      await outFile.writeAsBytes(compressed);

      // Vérifie taille < 800 KB
      final sizeKB = await outFile.length() / 1024;
      if (sizeKB > 800) {
        // Recompress avec qualité plus basse
        final compressed2 = img.encodeJpg(image, quality: 60);
        await outFile.writeAsBytes(compressed2);
      }

      return outFile;
    } catch (_) {
      return null;
    }
  }

  static bool isCameraAvailable() => cameras.isNotEmpty;
}
