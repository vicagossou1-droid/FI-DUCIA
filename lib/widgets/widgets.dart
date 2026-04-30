import 'package:flutter/material.dart';
import '../config/config.dart';

// ── BOUTON PRINCIPAL ──
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;
  final IconData? icon;

  const PrimaryButton({super.key, required this.label, this.onTap, this.loading = false, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(AppColors.blue);
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: c, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
              ]),
      ),
    );
  }
}

// ── STATUS BADGE ──
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

// ── DARK CARD ──
class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  const DarkCard({super.key, required this.child, this.padding, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(AppColors.bg2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? const Color(AppColors.border)),
    ),
    child: child,
  );
}

// ── STEP INDICATOR ──
class StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final List<String> labels;
  const StepIndicator({super.key, required this.current, required this.total, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current;
        final color = done || active ? const Color(AppColors.blue) : const Color(AppColors.border2);
        return Expanded(
          child: Column(children: [
            Row(children: [
              if (i > 0) Expanded(child: Container(height: 2, color: done ? const Color(AppColors.blue) : const Color(AppColors.border))),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color.withOpacity(active ? 0.2 : done ? 1 : 0.1), shape: BoxShape.circle, border: Border.all(color: color, width: done ? 0 : 2)),
                child: Center(child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('${i + 1}', style: TextStyle(color: active ? const Color(AppColors.blue) : const Color(AppColors.text3), fontSize: 12, fontWeight: FontWeight.bold))),
              ),
              if (i < total - 1) Expanded(child: Container(height: 2, color: done ? const Color(AppColors.blue) : const Color(AppColors.border))),
            ]),
            const SizedBox(height: 4),
            Text(labels[i], style: TextStyle(color: active ? const Color(AppColors.blue) : const Color(AppColors.text3), fontSize: 9)),
          ]),
        );
      }),
    );
  }
}

// ── LIVE BADGE ──
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});
  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}
class _LiveBadgeState extends State<LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0x1A22C55E), const Color(0x3322C55E), _ctrl.value),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(AppColors.green).withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(AppColors.green).withOpacity(0.5 + _ctrl.value * 0.5), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('LIVE', style: TextStyle(color: Color(AppColors.green), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ]),
    ),
  );
}
