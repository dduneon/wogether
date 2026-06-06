import 'package:flutter/material.dart';
import '../../api/notification_api.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import '../../widgets/w_app_bar.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ThemeProvider().addListener(_onTheme);
    _load();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    ThemeProvider().removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final notis = await NotificationApi.getNotifications();
      await NotificationApi.markAllRead();
      if (mounted) setState(() { _notifications = notis; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  _NotifStyle _styleFor(String? type) {
    switch (type) {
      case 'nudge':
        return _NotifStyle(emoji: '👉', color: WColors.yellow, label: '독촉');
      case 'goal_request':
        return _NotifStyle(emoji: '🎯', color: WColors.purple, label: '목표');
      case 'goal_approved':
        return _NotifStyle(emoji: '🏆', color: WColors.green, label: '달성');
      case 'join':
        return _NotifStyle(emoji: '🤝', color: WColors.cyan, label: '크루');
      default:
        return _NotifStyle(emoji: '🔔', color: WColors.textMuted, label: '알림');
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final utc = DateTime.parse(raw).toUtc();
      final kst = utc.add(const Duration(hours: 9));
      final now = DateTime.now().toUtc().add(const Duration(hours: 9));
      final diff = now.difference(kst);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${kst.month}/${kst.day}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wAppBar(context: context, title: const Text('알림')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔔', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text('아직 알림이 없어요', style: TextStyle(color: WColors.textMuted, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final n = _notifications[i];
                    final style = _styleFor(n['type']);
                    final isUnread = n['is_read'] == false || n['is_read'] == 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: WColors.bg2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUnread
                              ? style.color.withValues(alpha: 0.4)
                              : style.color.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 이모지 아이콘
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: style.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(style.emoji, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 메시지
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  n['message'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isUnread ? WColors.text : WColors.textMuted,
                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(n['created_at']),
                                  style: TextStyle(fontSize: 12, color: WColors.textDim),
                                ),
                              ],
                            ),
                          ),
                          // 읽지 않은 경우 점
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: style.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _NotifStyle {
  final String emoji;
  final Color color;
  final String label;
  const _NotifStyle({required this.emoji, required this.color, required this.label});
}
