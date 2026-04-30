import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../config/config.dart';
import '../../models/models.dart';
import '../../services/local_db.dart';
import '../../services/gps_service.dart';
import '../../services/photo_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/signature_widget.dart';
import '../../widgets/gps_justification_dialog.dart';
import '../historique_screen.dart';

import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import '../../fiducia_engine/models/gps_fix.dart';
import '../../fiducia_engine/services/geofence_service.dart';

// ════════════════════════════════════════════════
// ÉCRAN PRINCIPAL — FLUX DE SCAN COMPLET
// Étapes : SCAN QR → GPS → PHOTO → MONTANT → SUCCÈS
// ════════════════════════════════════════════════

class ScanFlowScreen extends StatefulWidget {
  final String collectriceId;
  final String collectriceNom;
  const ScanFlowScreen(
      {super.key, required this.collectriceId, required this.collectriceNom});
  @override
  State<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends State<ScanFlowScreen> {
  int _step =
      0; // 0=home, 1=scan, 2=gps, 3=photo, 4=montant, 5=signature, 6=succes
  String? _clientId;
  String? _clientNom;
  String? _photoPath;
  Uint8List? _signature; // Signature digitale du client
  bool _gpsValide = false;
  double? _lat, _lng;
  int _scanCountToday = 0;
  bool _needsPhoto = true;
  int _totalScansToday = 0;
  bool _requiresPhotoProof = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final scans = await LocalDB.getTodayScans(widget.collectriceId);
    if (mounted) setState(() => _totalScansToday = scans.length);
  }

  // Détermine si la photo est obligatoire
  bool _photoRequired(int scanCount) {
    if (scanCount < 3) return true; // 3 premiers = obligatoire
    // Après : aléatoire 1 scan sur 7
    return (scanCount % 7 == 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(anim),
                  child: child)),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _HomeStep(
            key: const ValueKey(0),
            collectriceNom: widget.collectriceNom,
            totalToday: _totalScansToday,
            onScan: () => setState(() => _step = 1),
            onHistorique: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HistoriqueScreen(
                            collectriceId: widget.collectriceId)))
                .then((_) => _loadStats()));
      case 1:
        return _QRStep(
            key: const ValueKey(1),
            onScanned: _onQRScanned,
            onBack: () => setState(() => _step = 0));
      case 2:
        return _GpsStep(
            key: const ValueKey(2),
            clientId: _clientId ?? '',
            clientNom: _clientNom ?? '',
            onValidated: _onGpsValidated,
            onBack: () => setState(() => _step = 1));
      case 3:
        return _PhotoStep(
            key: const ValueKey(3),
            clientNom: _clientNom ?? '',
            onPhotoCaptured: _onPhotoCaptured,
            onSkip: null,
            onBack: () => setState(() => _step = 1),
            latitude: _lat,
            longitude: _lng);
      case 4:
        return _MontantStep(
            key: const ValueKey(4),
            clientNom: _clientNom ?? '',
            photoPath: _photoPath,
            onConfirmed: _onMontantConfirmed,
            onBack: () => setState(() => _step = _requiresPhotoProof ? 3 : 1));
      case 5:
        return SignatureCapture(
            clientName: _clientNom ?? '',
            onSignatureCapture: (sig) {
              setState(() {
                _signature = sig;
                _step = 6;
              });
            });
      case 6:
        return _SuccessStep(
            key: const ValueKey(6),
            clientNom: _clientNom ?? '',
            signature: _signature,
            onNext: _onNextScan);
      default:
        return const SizedBox();
    }
  }

  Future<void> _onQRScanned(String qrData) async {
    // Vérifier si déjà scanné aujourd'hui
    final alreadyScanned = await LocalDB.alreadyScannedToday(qrData);
    if (alreadyScanned) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  backgroundColor: const Color(AppColors.bg2),
                  title: const Text('Client déjà scanné',
                      style: TextStyle(color: Color(AppColors.red))),
                  content: const Text(
                      'Ce client a déjà été scanné aujourd\'hui.',
                      style: TextStyle(color: Color(AppColors.text2))),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _step = 1);
                        },
                        child: const Text('Rescanner'))
                  ],
                ));
      }
      return;
    }

    _clientId = qrData;
    _clientNom = 'Client $qrData'; // Victor/Ayao fourniront le vrai nom
    _scanCountToday = await LocalDB.getScanCount(qrData);
    GeofenceDecision? geofenceDecision;
    try {
      geofenceDecision =
          await GeofenceService.instance.validateLocation(_clientId!);
    } catch (e) {
      debugPrint('🚨 [GEOFENCE] Exception pendant validation: $e');
      if (!mounted) return;
      // Timeout / erreur technique: forcer la preuve visuelle (CAS B).
      setState(() {
        _gpsValide = false;
        _requiresPhotoProof = true;
        _needsPhoto = true;
        _step = 3;
      });
      return;
    }

    if (!mounted) return;

    final fix = geofenceDecision.fix;
    if (fix != null) {
      _lat = fix.latitude;
      _lng = fix.longitude;
    }

    final gpsSignalMissing = geofenceDecision.status == GeofenceStatus.invalidFix ||
        geofenceDecision.status == GeofenceStatus.unsupportedPlatform ||
        geofenceDecision.gpsIssue == GpsIssue.servicesDisabled ||
        geofenceDecision.gpsIssue == GpsIssue.permissionDenied ||
        geofenceDecision.gpsIssue == GpsIssue.permissionDeniedForever ||
        geofenceDecision.gpsIssue == GpsIssue.timeout;

    if (gpsSignalMissing) {
      // GPS introuvable / timeout: forcer la preuve visuelle (CAS B).
      setState(() {
        _gpsValide = false;
        _requiresPhotoProof = true;
        _needsPhoto = true;
        _step = 3;
      });
      return;
    }

    final isAllowed = geofenceDecision.isAllowed;
    _gpsValide = isAllowed;
    _requiresPhotoProof = !isAllowed;

    // CAS A: géofence valide -> accès direct au montant
    if (isAllowed) {
      setState(() {
        _needsPhoto = false;
        _photoPath = null;
        _step = 4;
      });
      return;
    }

    // CAS B: hors zone / alerte / rejet -> passage photo obligatoire avant montant
    setState(() {
      _needsPhoto = true;
      _step = 3;
    });
  }

  Future<void> _onGpsValidated(double lat, double lng, bool valide) async {
    _lat = lat;
    _lng = lng;
    _gpsValide = valide;
    _needsPhoto = _photoRequired(_scanCountToday);
    setState(() => _step = 3);
  }

  void _onPhotoCaptured(String? path) {
    _photoPath = path;
    setState(() => _step = 4);
  }

  Future<void> _onMontantConfirmed(double montant) async {
    final scan = ScanRecord(
      id: const Uuid().v4(),
      clientId: _clientId!,
      collectriceId: widget.collectriceId,
      montant: montant,
      photoPath: _photoPath,
      latitude: _lat,
      longitude: _lng,
      gpsValide: _gpsValide,
      scannedAt: DateTime.now(),
    );

    await LocalDB.insertScan(scan);
    await LocalDB.incrementScanCount(_clientId!);

    // Tenter sync immédiat
    SupabaseService.syncAll();

    setState(() {
      _step = 5;
      _totalScansToday++;
    });
  }

  void _onNextScan() {
    _clientId = null;
    _clientNom = null;
    _photoPath = null;
    _gpsValide = false;
    _lat = null;
    _lng = null;
    _requiresPhotoProof = false;
    setState(() => _step = 0);
  }
}

// ── STEP 0 : HOME ──
class _HomeStep extends StatelessWidget {
  final String collectriceNom;
  final int totalToday;
  final VoidCallback onScan;
  final VoidCallback onHistorique;
  const _HomeStep(
      {super.key,
      required this.collectriceNom,
      required this.totalToday,
      required this.onScan,
      required this.onHistorique});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bonjour, ${collectriceNom.split(' ').first} 👋',
                style: const TextStyle(
                    color: Color(AppColors.blue),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(
                DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(DateTime.now()),
                style: const TextStyle(
                    color: Color(AppColors.text3), fontSize: 11)),
          ]),
          const Spacer(),
          const LiveBadge(),
        ]).animate().fadeIn(),

        const SizedBox(height: 28),

        // Stats du jour
        DarkCard(
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('$totalToday', 'Scans\naujourd\'hui',
                const Color(AppColors.blue)),
            Container(
                width: 1, height: 40, color: const Color(AppColors.border)),
            _stat('✓', 'Système\nactif', const Color(AppColors.green)),
            Container(
                width: 1, height: 40, color: const Color(AppColors.border)),
            _stat('🔒', 'Données\nsécurisées', const Color(AppColors.orange)),
          ]),
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 32),

        // Bouton scanner géant
        GestureDetector(
          onTap: onScan,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(AppColors.blue), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: const Color(AppColors.blue).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 64),
              const SizedBox(height: 12),
              const Text('SCANNER UN CLIENT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('Appuyez pour ouvrir la caméra',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ]),
          ),
        )
            .animate()
            .fadeIn(delay: 300.ms)
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

        const SizedBox(height: 16),

        // Bouton historique
        GestureDetector(
          onTap: onHistorique,
          child: DarkCard(
            child: Row(children: [
              const Icon(Icons.history_rounded,
                  color: Color(AppColors.text2), size: 22),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Historique du jour',
                        style: TextStyle(
                            color: Color(AppColors.text1),
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text('Voir toutes mes collectes',
                        style: TextStyle(
                            color: Color(AppColors.text3), fontSize: 11)),
                  ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(AppColors.text3), size: 14),
            ]),
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) => Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Color(AppColors.text3), fontSize: 10),
            textAlign: TextAlign.center),
      ]);
}

// ── STEP 1 : QR SCAN ──
class _QRStep extends StatefulWidget {
  final Future<void> Function(String) onScanned;
  final VoidCallback onBack;
  const _QRStep({super.key, required this.onScanned, required this.onBack});
  @override
  State<_QRStep> createState() => _QRStepState();
}

class _QRStepState extends State<_QRStep> with WidgetsBindingObserver {
  bool _scanned = false;
  bool _isProcessing = false;
  late final MobileScannerController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.all],
    );
    WidgetsBinding.instance.addObserver(this);
    // Démarrage explicite pour éviter un contrôleur inactif selon le cycle de vie.
    _ctrl.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed && !_scanned) {
      _ctrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: const Color(AppColors.bg2),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(AppColors.text2)),
              onPressed: widget.onBack),
          const Expanded(
              child: Text('Scanner le carnet',
                  style: TextStyle(
                      color: Color(AppColors.text1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center)),
          TextButton(
            onPressed: () async {
              if (_scanned || _isProcessing) return;
              setState(() {
                _scanned = true;
                _isProcessing = true;
              });
              await widget
                  .onScanned('TEST_CLIENT_${DateTime.now().millisecondsSinceEpoch}');
              if (!mounted) return;
              setState(() => _isProcessing = false);
            },
            child: const Text(
              'Test',
              style: TextStyle(
                  color: Color(AppColors.orange),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),

      // Steps
      Padding(
        padding: const EdgeInsets.all(16),
        child: StepIndicator(
            current: 0,
            total: 4,
            labels: const ['QR Code', 'GPS', 'Photo', 'Montant']),
      ),

      // Camera
      Expanded(
        child: Stack(children: [
          MobileScanner(
            controller: _ctrl,
            fit: BoxFit.cover,
            onDetect: (capture) async {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return; // Sécurité vitale

              final String code = barcodes.first.rawValue ?? 'QR_EMPTY_PAYLOAD';
              debugPrint('🚨 [DEBUG SCANNER] LECTURE BRUTE : $code');

              if (_scanned || _isProcessing) return;
              setState(() {
                _scanned = true;
                _isProcessing = true;
              });

              // Appelle la fonction pour passer à l'étape suivante
              await widget.onScanned(code);
              if (!mounted) return;
              setState(() => _isProcessing = false);
            },
          ),
          // Overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(AppColors.blue), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                _corner(0, 0),
                _corner(1, 0),
                _corner(0, 1),
                _corner(1, 1),
              ]),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Text('Pointez le QR Code du carnet client',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 13),
                        textAlign: TextAlign.center)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppColors.red),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (_scanned || _isProcessing) return;
                    setState(() {
                      _scanned = true;
                      _isProcessing = true;
                    });
                    await widget.onScanned('TEST_CLIENT_123');
                    if (!mounted) return;
                    setState(() => _isProcessing = false);
                  },
                  child: const Text('FORCER LE SCAN (TEST)'),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Vérification de sécurité en cours...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _corner(int h, int v) {
    return Positioned(
      left: h == 0 ? -1 : null,
      right: h == 1 ? -1 : null,
      top: v == 0 ? -1 : null,
      bottom: v == 1 ? -1 : null,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            left: h == 0
                ? const BorderSide(color: Color(AppColors.blue), width: 3)
                : BorderSide.none,
            right: h == 1
                ? const BorderSide(color: Color(AppColors.blue), width: 3)
                : BorderSide.none,
            top: v == 0
                ? const BorderSide(color: Color(AppColors.blue), width: 3)
                : BorderSide.none,
            bottom: v == 1
                ? const BorderSide(color: Color(AppColors.blue), width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ── STEP 2 : GPS ──
class _GpsStep extends StatefulWidget {
  final String clientId;
  final String clientNom;
  final Function(double, double, bool) onValidated;
  final VoidCallback onBack;
  const _GpsStep(
      {super.key,
      required this.clientId,
      required this.clientNom,
      required this.onValidated,
      required this.onBack});
  @override
  State<_GpsStep> createState() => _GpsStepState();
}

class _GpsStepState extends State<_GpsStep> {
  bool _loading = true;
  String _status = 'Vérification GPS en cours...';
  bool _valide = false;
  double _lat = 0, _lng = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final decision = await GeofenceService.instance.validateLocation(widget.clientId);
    if (!mounted) return;

    final fix = decision.fix;
    if (fix != null) {
      _lat = fix.latitude;
      _lng = fix.longitude;
    }

    final gpsSignalMissing = decision.status == GeofenceStatus.invalidFix ||
        decision.status == GeofenceStatus.unsupportedPlatform ||
        decision.gpsIssue == GpsIssue.servicesDisabled ||
        decision.gpsIssue == GpsIssue.permissionDenied ||
        decision.gpsIssue == GpsIssue.permissionDeniedForever ||
        decision.gpsIssue == GpsIssue.timeout;

    setState(() {
      _loading = false;
      _valide = decision.isAllowed;
      _status = gpsSignalMissing
          ? 'Signal GPS requis pour valider cette collecte. Veuillez activer votre localisation.'
          : decision.isAllowed
              ? 'Position GPS validée.'
              : 'Position hors zone: preuve photo requise.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(AppColors.text2)),
              onPressed: widget.onBack),
          const Expanded(
              child: Text('Vérification GPS',
                  style: TextStyle(
                      color: Color(AppColors.text1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 48),
        ]),
        const SizedBox(height: 8),
        StepIndicator(
            current: 1,
            total: 4,
            labels: const ['QR Code', 'GPS', 'Photo', 'Montant']),
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _loading
                ? const Color(AppColors.blue).withOpacity(0.15)
                : _valide
                    ? const Color(AppColors.green).withOpacity(0.15)
                    : const Color(AppColors.orange).withOpacity(0.15),
            border: Border.all(
                color: _loading
                    ? const Color(AppColors.blue)
                    : _valide
                        ? const Color(AppColors.green)
                        : const Color(AppColors.orange),
                width: 2),
          ),
          child: _loading
              ? const CircularProgressIndicator(
                  color: Color(AppColors.blue), strokeWidth: 2)
              : Icon(
                  _valide
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: _valide
                      ? const Color(AppColors.green)
                      : const Color(AppColors.orange),
                  size: 48),
        ).animate().scale(duration: 400.ms),
        const SizedBox(height: 20),
        Text(_status,
            style: TextStyle(
                color: _valide
                    ? const Color(AppColors.green)
                    : const Color(AppColors.text2),
                fontSize: 15,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        if (!_loading && !_valide) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(AppColors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(AppColors.orange).withOpacity(0.3))),
            child: const Text(
                'Signal GPS requis pour valider cette collecte. Veuillez activer votre localisation.',
                style: TextStyle(color: Color(AppColors.text2), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
        const Spacer(),
        if (!_loading && _valide)
          PrimaryButton(
            label: 'CONTINUER',
            color: const Color(AppColors.green),
            icon: Icons.arrow_forward_rounded,
            onTap: () => widget.onValidated(_lat, _lng, _valide),
          ),
      ]),
    );
  }
}

// ── STEP 3 : PHOTO ──
class _PhotoStep extends StatefulWidget {
  final String clientNom;
  final Function(String?) onPhotoCaptured;
  final VoidCallback? onSkip;
  final VoidCallback onBack;
  final double? latitude;
  final double? longitude;

  const _PhotoStep(
      {super.key,
      required this.clientNom,
      required this.onPhotoCaptured,
      this.onSkip,
      required this.onBack,
      this.latitude,
      this.longitude});
  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  CameraController? _camCtrl;
  String? _preview;
  bool _capturing = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (PhotoService.cameras.isEmpty) await PhotoService.init();
    if (PhotoService.cameras.isEmpty) {
      setState(() => _ready = false);
      return;
    }
    _camCtrl = CameraController(
        PhotoService.cameras.first, ResolutionPreset.medium,
        enableAudio: false);
    await _camCtrl!.initialize();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_camCtrl == null || !_ready) return;
    setState(() => _capturing = true);
    try {
      final xfile = await _camCtrl!.takePicture();

      // Ajoute watermark anti-fraude si GPS disponible
      File? processedPhoto;
      if (widget.latitude != null && widget.longitude != null) {
        processedPhoto = await PhotoService.addWatermark(
          xfile.path,
          latitude: widget.latitude!,
          longitude: widget.longitude!,
        );
      } else {
        // Fallback: compression simple
        processedPhoto = await PhotoService.compressPhoto(xfile.path);
      }

      if (mounted) {
        setState(() {
          _preview = processedPhoto?.path ?? xfile.path;
          _capturing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: const Color(AppColors.bg2),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(AppColors.text2)),
              onPressed: widget.onBack),
          const Expanded(
              child: Text('Capture photo',
                  style: TextStyle(
                      color: Color(AppColors.text1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 48),
        ]),
      ),
      Padding(
          padding: const EdgeInsets.all(16),
          child: StepIndicator(
              current: 2,
              total: 4,
              labels: const ['QR Code', 'GPS', 'Photo', 'Montant'])),
      Expanded(
        child: _preview != null
            // Aperçu photo
            ? Column(children: [
                Expanded(
                    child: Image.file(File(_preview!),
                        fit: BoxFit.cover, width: double.infinity)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => setState(() => _preview = null),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(AppColors.text2),
                          side:
                              const BorderSide(color: Color(AppColors.border2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Reprendre'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                      onPressed: () => widget.onPhotoCaptured(_preview),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppColors.green),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Utiliser',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
                  ]),
                ),
              ])
            : _ready
                // Caméra live
                ? Column(children: [
                    Expanded(child: CameraPreview(_camCtrl!)),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text('Photo obligatoire pour ${widget.clientNom}',
                            style: const TextStyle(
                                color: Color(AppColors.text2), fontSize: 12),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.onSkip != null) ...[
                                OutlinedButton(
                                  onPressed: widget.onSkip,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          const Color(AppColors.text3),
                                      side: const BorderSide(
                                          color: Color(AppColors.border2))),
                                  child: const Text('Ignorer'),
                                ),
                                const SizedBox(width: 16),
                              ],
                              GestureDetector(
                                onTap: _capturing ? null : _capture,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(AppColors.blue),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(AppColors.blue)
                                              .withOpacity(0.4),
                                          blurRadius: 16)
                                    ],
                                  ),
                                  child: _capturing
                                      ? const CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2)
                                      : const Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 34),
                                ),
                              ),
                            ]),
                      ]),
                    ),
                  ])
                // Caméra non disponible
                : Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: Color(AppColors.text3), size: 60),
                        const SizedBox(height: 16),
                        const Text('Caméra non disponible',
                            style: TextStyle(color: Color(AppColors.text2))),
                        const SizedBox(height: 24),
                        PrimaryButton(
                            label: 'CONTINUER SANS PHOTO',
                            onTap: () => widget.onPhotoCaptured(null),
                            color: const Color(AppColors.orange)),
                      ])),
      ),
    ]);
  }
}

// ── STEP 4 : MONTANT ──
class _MontantStep extends StatefulWidget {
  final String clientNom;
  final String? photoPath;
  final Function(double) onConfirmed;
  final VoidCallback onBack;
  const _MontantStep(
      {super.key,
      required this.clientNom,
      this.photoPath,
      required this.onConfirmed,
      required this.onBack});
  @override
  State<_MontantStep> createState() => _MontantStepState();
}

class _MontantStepState extends State<_MontantStep> {
  final _montantCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsetsBottom),
      child: Column(children: [
        Row(children: [
          IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(AppColors.text2)),
              onPressed: widget.onBack),
          const Expanded(
              child: Text('Saisir le montant',
                  style: TextStyle(
                      color: Color(AppColors.text1),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 48),
        ]),
        const SizedBox(height: 8),
        StepIndicator(
            current: 3,
            total: 4,
            labels: const ['QR Code', 'GPS', 'Photo', 'Montant']),
        const SizedBox(height: 32),

        // Résumé
        DarkCard(
          child: Column(children: [
            Row(children: [
              const Icon(Icons.person_rounded,
                  color: Color(AppColors.blue), size: 18),
              const SizedBox(width: 8),
              Text(widget.clientNom,
                  style: const TextStyle(
                      color: Color(AppColors.text1),
                      fontWeight: FontWeight.w600)),
            ]),
            if (widget.photoPath != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.camera_alt_rounded,
                    color: Color(AppColors.green), size: 16),
                const SizedBox(width: 8),
                const Text('Photo capturée ✓',
                    style:
                        TextStyle(color: Color(AppColors.green), fontSize: 12)),
              ]),
            ],
          ]),
        ),

        const SizedBox(height: 24),

        // Champ montant grand
        Container(
          decoration: BoxDecoration(
              color: const Color(AppColors.bg2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(AppColors.blue).withOpacity(0.4),
                  width: 2)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            const Text('FCFA',
                style: TextStyle(
                    color: Color(AppColors.text3),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                  color: Color(AppColors.text1),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'),
              decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle:
                      TextStyle(color: Color(AppColors.text3), fontSize: 28),
                  border: InputBorder.none),
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // Montants rapides
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2000, 5000, 10000, 15000, 20000]
                .map((v) => GestureDetector(
                      onTap: () =>
                          setState(() => _montantCtrl.text = v.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: const Color(AppColors.bg3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(AppColors.border2))),
                        child: Text('$v F',
                            style: const TextStyle(
                                color: Color(AppColors.text2),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList()),
        const SizedBox(height: 24),

        PrimaryButton(
          label: 'CONFIRMER LA COLLECTE',
          loading: _loading,
          icon: Icons.check_circle_rounded,
          color: const Color(AppColors.green),
          onTap: () {
            final val = double.tryParse(_montantCtrl.text.replaceAll(' ', ''));
            if (val == null || val <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Montant invalide'),
                  backgroundColor: Color(AppColors.red)));
              return;
            }
            setState(() => _loading = true);
            Future.delayed(const Duration(milliseconds: 600),
                () => widget.onConfirmed(val));
          },
        ),
      ]),
    );
  }
}

// ── STEP 5 : SUCCÈS ──
class _SuccessStep extends StatefulWidget {
  final String clientNom;
  final VoidCallback onNext;
  final Uint8List? signature;

  const _SuccessStep(
      {super.key,
      required this.clientNom,
      required this.onNext,
      this.signature});
  @override
  State<_SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends State<_SuccessStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _confettiCtrl.play();
    _triggerVibration();
  }

  Future<void> _triggerVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 500);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ConfettiWidget(
          confettiController: _confettiCtrl,
          blastDirectionality: BlastDirectionality.explosive,
          particleDrag: 0.05,
          emissionFrequency: 0.05,
          numberOfParticles: 50,
          gravity: 0.1,
          shouldLoop: false,
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Checkmark avec animation
            ScaleTransition(
              scale: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(AppColors.green).withOpacity(0.2),
                      const Color(AppColors.green).withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(AppColors.green),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(AppColors.green).withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(AppColors.green),
                  size: 80,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Titre avec fade-in
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.3, 1),
              )),
              child: const Text(
                '✨ COLLECTE VALIDÉE ! ✨',
                style: TextStyle(
                  color: Color(AppColors.green),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.4, 1),
              )),
              child: Text(
                '${widget.clientNom} — Synchronisé ✓',
                style: const TextStyle(
                  color: Color(AppColors.text2),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // Résumé des étapes
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.5, 1),
              )),
              child: DarkCard(
                borderColor: const Color(AppColors.green).withOpacity(0.3),
                child: Column(
                  children: [
                    _row(Icons.qr_code_rounded, 'QR Code scanné', '✓',
                        const Color(AppColors.green)),
                    const SizedBox(height: 8),
                    _row(Icons.location_on_rounded, 'GPS enregistré', '✓',
                        const Color(AppColors.green)),
                    const SizedBox(height: 8),
                    _row(Icons.cloud_upload_rounded, 'Données envoyées', '✓',
                        const Color(AppColors.blue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.6, 1),
              )),
              child: PrimaryButton(
                label: 'SCANNER UN AUTRE CLIENT',
                onTap: widget.onNext,
                icon: Icons.qr_code_scanner_rounded,
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(AppColors.text2), fontSize: 13))),
        StatusBadge(label: value, color: color),
      ]);
}
