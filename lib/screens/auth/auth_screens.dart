import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../config/locale_manager.dart';
import '../../services/gps_service.dart';
import '../../widgets/widgets.dart';
import '../scanner/scan_flow_screen.dart';

// ── SPLASH ──
class SplashScreen extends StatefulWidget {
  final LocaleManager? localeManager;

  const SplashScreen({super.key, this.localeManager});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('collectrice_id');
      if (saved != null && saved.isNotEmpty) {
        // DÉMARRER TRACKING GPS PASSIF
        await GpsService.startPassiveTracking(saved);
        print('GPS: Tracking passif démarré pour collectrice $saved');

        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => ScanFlowScreen(
                    collectriceId: saved,
                    collectriceNom: prefs.getString('collectrice_nom') ?? '')));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(AppColors.blue), Color(AppColors.green)]),
              boxShadow: [
                BoxShadow(
                    color: const Color(AppColors.blue).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5)
              ],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 50),
          ).animate().scale(duration: 700.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          Text('FI-DUCIA',
                  style: const TextStyle(
                      color: Color(AppColors.blue),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3))
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 6),
          Text('Collecte sécurisée • Togo',
                  style: const TextStyle(
                      color: Color(AppColors.text3),
                      fontSize: 12,
                      letterSpacing: 1))
              .animate()
              .fadeIn(delay: 700.ms),
          const SizedBox(height: 60),
          SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                      backgroundColor: const Color(AppColors.border),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(AppColors.blue))))
              .animate()
              .fadeIn(delay: 1000.ms),
        ]),
      ),
    );
  }
}

// ── LOGIN ──
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (_nomCtrl.text.trim().isEmpty || _telCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final prefs = await SharedPreferences.getInstance();
    // ID collectrice = téléphone pour la démo
    final id = _telCtrl.text.trim().replaceAll(' ', '');
    await prefs.setString('collectrice_id', id);
    await prefs.setString('collectrice_nom', _nomCtrl.text.trim());

    if (mounted) {
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ScanFlowScreen(
                collectriceId: id, collectriceNom: _nomCtrl.text.trim()),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bg),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const SizedBox(height: 50),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(AppColors.blue).withOpacity(0.15),
                border: Border.all(
                    color: const Color(AppColors.blue).withOpacity(0.4),
                    width: 2),
                boxShadow: [
                  BoxShadow(
                      color: const Color(AppColors.blue).withOpacity(0.3),
                      blurRadius: 20)
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Color(AppColors.blue), size: 38),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 22),
            Text('FI-DUCIA',
                    style: const TextStyle(
                        color: Color(AppColors.blue),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2))
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 6),
            Text('Connectez-vous pour commencer la collecte',
                    style: const TextStyle(
                        color: Color(AppColors.text3), fontSize: 12),
                    textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 40),
            _field(
                label: 'Votre nom complet',
                ctrl: _nomCtrl,
                icon: Icons.person_rounded,
                hint: 'Ex: Afi Agbeko'),
            const SizedBox(height: 14),
            _field(
                label: 'Numéro de téléphone',
                ctrl: _telCtrl,
                icon: Icons.phone_rounded,
                hint: '+228 XX XX XX XX',
                keyboard: TextInputType.phone),
            const SizedBox(height: 32),
            PrimaryButton(
                    label: 'COMMENCER LA COLLECTE',
                    onTap: _login,
                    loading: _loading,
                    icon: Icons.arrow_forward_rounded)
                .animate()
                .fadeIn(delay: 500.ms),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(AppColors.bg2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.border))),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.info_outline_rounded,
                          color: Color(AppColors.text3), size: 14),
                      SizedBox(width: 6),
                      Text('Comptes de test',
                          style: TextStyle(
                              color: Color(AppColors.text2),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                const SizedBox(height: 8),
                ...['Afi Agbeko / +22890000001', 'Akua Dosseh / +22890000002']
                    .map((n) {
                  final parts = n.split(' / ');
                  return GestureDetector(
                    onTap: () {
                      _nomCtrl.text = parts[0];
                      _telCtrl.text = parts[1];
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(n,
                          style: const TextStyle(
                              color: Color(AppColors.blue),
                              fontSize: 11,
                              fontFamily: 'monospace')),
                    ),
                  );
                }),
              ]),
            ).animate().fadeIn(delay: 700.ms),
          ]),
        ),
      ),
    );
  }

  Widget _field(
      {required String label,
      required TextEditingController ctrl,
      required IconData icon,
      required String hint,
      TextInputType keyboard = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Color(AppColors.text2),
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
            color: const Color(AppColors.bg2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(AppColors.border2))),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: Color(AppColors.text1), fontSize: 15),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(AppColors.text3)),
              prefixIcon:
                  Icon(icon, color: const Color(AppColors.blue), size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 8)),
        ),
      ),
    ]);
  }
}
