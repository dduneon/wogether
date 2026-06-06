import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/auth_store.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import '../../widgets/w_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthStore().user;
    final username = user?['username'] ?? user?['nickname'] ?? '';
    final email = user?['email'] ?? '';

    return Scaffold(
      backgroundColor: WColors.bg,
      body: CustomScrollView(
        slivers: [
          ...wLargeTitleHeader(
            context: context,
            title: '설정',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 카드
                  _SectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: WColors.gradientPurpleCyan,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                username.isNotEmpty ? username[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: WColors.text,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: TextStyle(fontSize: 13, color: WColors.textMuted),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 테마 섹션
                  _SectionLabel('디스플레이'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    children: [_ThemeTile()],
                  ),
                  const SizedBox(height: 24),

                  // 계정 섹션
                  _SectionLabel('계정'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: WColors.red,
                        label: '로그아웃',
                        labelColor: WColors.red,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed == true) await AuthStore().logout();
  }
}

// ── 섹션 레이블 ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WColors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── 섹션 카드 컨테이너 ───────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 0.5, thickness: 0.5, color: WColors.border,
                  indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

// ── 일반 설정 타일 ───────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? WColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 테마 타일 ────────────────────────────────────────────────────────────────
class _ThemeTile extends StatefulWidget {
  @override
  State<_ThemeTile> createState() => _ThemeTileState();
}

class _ThemeTileState extends State<_ThemeTile> {
  @override
  Widget build(BuildContext context) {
    final p = ThemeProvider();
    final isDark = p.mode == WThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 18,
              color: WColors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '테마',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: WColors.text,
              ),
            ),
          ),
          // 다크/라이트 세그먼트 버튼
          Container(
            decoration: BoxDecoration(
              color: WColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WColors.border),
            ),
            child: Row(
              children: [
                _ThemeSegment(
                  label: '다크',
                  icon: '🌑',
                  selected: isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    p.setMode(WThemeMode.dark);
                    setState(() {});
                  },
                ),
                _ThemeSegment(
                  label: '라이트',
                  icon: '☀️',
                  selected: !isDark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    p.setMode(WThemeMode.light);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  final String label, icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? WColors.purple.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: selected
              ? Border.all(color: WColors.purple.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? WColors.purple : WColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
