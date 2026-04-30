import 'package:flutter/material.dart';
import '../config/config.dart';

/// Écran de justification quand GPS hors zone
class GpsJustificationDialog extends StatefulWidget {
  final String clientNom;
  final double distance; // distance en mètres
  final Function(String) onJustified; // callback avec justification

  const GpsJustificationDialog({
    super.key,
    required this.clientNom,
    required this.distance,
    required this.onJustified,
  });

  @override
  State<GpsJustificationDialog> createState() => _GpsJustificationDialogState();
}

class _GpsJustificationDialogState extends State<GpsJustificationDialog> {
  final TextEditingController _justificationCtrl = TextEditingController();
  final List<String> _quickReasons = [
    'Client en déplacement',
    'Client chez un voisin',
    'Client au marché',
    'Client à la pharmacie',
    'Client en visite familiale',
    'Client au travail',
    'Autre (préciser)',
  ];

  String? _selectedReason;

  @override
  void dispose() {
    _justificationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final justification = _selectedReason == 'Autre (préciser)'
        ? _justificationCtrl.text.trim()
        : _selectedReason ?? '';

    if (justification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez fournir une justification'),
          backgroundColor: Color(AppColors.red),
        ),
      );
      return;
    }

    widget.onJustified(justification);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(AppColors.bg2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(AppColors.orange),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Position hors zone',
                        style: TextStyle(
                          color: Color(AppColors.orange),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Client: ${widget.clientNom}',
                        style: const TextStyle(
                          color: Color(AppColors.text2),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Distance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppColors.bg3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(AppColors.orange).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_rounded,
                    color: Color(AppColors.orange),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Distance: ${widget.distance.toStringAsFixed(1)} mètres',
                    style: const TextStyle(
                      color: Color(AppColors.text1),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Raisons rapides
            const Text(
              'Raison de la collecte hors zone:',
              style: TextStyle(
                color: Color(AppColors.text1),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Liste des raisons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = reason),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(AppColors.orange).withOpacity(0.2)
                          : const Color(AppColors.bg3),
                      border: Border.all(
                        color: isSelected
                            ? const Color(AppColors.orange)
                            : const Color(AppColors.border2),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(AppColors.orange)
                            : const Color(AppColors.text2),
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Champ texte si "Autre"
            if (_selectedReason == 'Autre (préciser)')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _justificationCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Précisez la raison...',
                    filled: true,
                    fillColor: const Color(AppColors.bg3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(AppColors.border2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(AppColors.orange),
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(AppColors.text1),
                    fontSize: 14,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(AppColors.text3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Color(AppColors.text2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(AppColors.orange),
                          Color(AppColors.red),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Justifier & Continuer',
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
          ],
        ),
      ),
    );
  }
}
