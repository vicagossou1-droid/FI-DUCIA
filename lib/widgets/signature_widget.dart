import 'package:flutter/material.dart';
import 'dart:typed_data';
// import 'package:hand_signature/hand_signature.dart';
import '../config/config.dart';

// TODO: Implémenter avec un package de signature valide
// Classes temporaires pour éviter les erreurs de compilation
class HandSignatureController {
  HandSignatureController(
      {Function? onPointerDown, double? smoothRatio, double? velocityRange}) {}
  void dispose() {}
  Future<Uint8List?> toImage() async => null;
  void clear() {}
}

class HandSignature extends StatelessWidget {
  final HandSignatureController? control;
  final dynamic type;
  final Color? color;
  final double? width;
  final double? height;
  const HandSignature(
      {super.key,
      this.control,
      this.type,
      this.color,
      this.width,
      this.height});
  @override
  Widget build(BuildContext context) => Container();
}

class SignatureDrawType {
  static var shape;
}

/// Widget pour capture de signature digitale du client
class SignatureCapture extends StatefulWidget {
  final Function(Uint8List) onSignatureCapture;
  final String clientName;

  const SignatureCapture({
    super.key,
    required this.onSignatureCapture,
    required this.clientName,
  });

  @override
  State<SignatureCapture> createState() => _SignatureCaptureState();
}

class _SignatureCaptureState extends State<SignatureCapture> {
  late HandSignatureController _signCtrl;
  bool _isSigned = false;

  @override
  void initState() {
    super.initState();
    _signCtrl = HandSignatureController(
      onPointerDown: () => setState(() => _isSigned = true),
      smoothRatio: 0.5,
      velocityRange: 2.0,
    );
  }

  @override
  void dispose() {
    _signCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureSignature() async {
    if (!_isSigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez signer d\'abord'),
          backgroundColor: Color(AppColors.red),
        ),
      );
      return;
    }

    try {
      final sig = await _signCtrl.toImage();
      if (sig != null) {
        final bytes = sig.buffer.asUint8List();
        widget.onSignatureCapture(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la capture'),
          backgroundColor: Color(AppColors.red),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(AppColors.bg2),
                const Color(AppColors.bg3),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✍️ Signature Digitale',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.blue),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preuve supplémentaire de la collecte pour : ${widget.clientName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(AppColors.text2),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Zone de signature
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(AppColors.border2),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: const Color(AppColors.bg2),
            boxShadow: [
              BoxShadow(
                color: const Color(AppColors.blue).withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: HandSignature(
            control: _signCtrl,
            color: const Color(AppColors.blue),
            width: double.infinity,
            height: 220,
            type: SignatureDrawType.shape,
          ),
        ),

        const SizedBox(height: 16),

        // Boutons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Bouton Clear
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _signCtrl.clear();
                    setState(() => _isSigned = false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(AppColors.orange),
                      width: 2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Effacer',
                    style: TextStyle(
                      color: Color(AppColors.orange),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Bouton Valider
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(AppColors.green),
                        const Color(AppColors.blue),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(AppColors.green).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _captureSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Valider Signature',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Indication
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSigned ? Icons.check_circle : Icons.circle_outlined,
                color: _isSigned
                    ? const Color(AppColors.green)
                    : const Color(AppColors.text2),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isSigned ? 'Signature détectée ✓' : 'Signez ici...',
                style: TextStyle(
                  fontSize: 12,
                  color: _isSigned
                      ? const Color(AppColors.green)
                      : const Color(AppColors.text2),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
