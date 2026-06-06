import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme_provider.dart';

void showThemeSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ThemeSettingsSheet(),
  );
}

class _ThemeSettingsSheet extends StatelessWidget {
  const _ThemeSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final p = ThemeProvider();
    final bg2 = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('테마', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: textColor, letterSpacing: -0.4,
              )),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ModeChip(
                    mode: WThemeMode.dark,
                    label: '다크', icon: '🌑',
                    current: p.mode,
                    onTap: (m) {
                      HapticFeedback.selectionClick();
                      p.setMode(m);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 10),
                  _ModeChip(
                    mode: WThemeMode.light,
                    label: '라이트', icon: '☀️',
                    current: p.mode,
                    onTap: (m) {
                      HapticFeedback.selectionClick();
                      p.setMode(m);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode, required this.label, required this.icon,
    required this.current, required this.onTap,
  });
  final WThemeMode mode, current;
  final String label, icon;
  final ValueChanged<WThemeMode> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected
                    ? accent
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
