import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/crew_api.dart';
import '../../api/dashboard_api.dart';
import '../../utils/auth_store.dart';
import '../../utils/theme.dart';
import '../../widgets/w_card.dart';
import '../../widgets/w_app_bar.dart';
import '../../widgets/theme_settings_sheet.dart';

class CrewListScreen extends StatefulWidget {
  const CrewListScreen({super.key});

  @override
  State<CrewListScreen> createState() => _CrewListScreenState();
}

class _CrewListScreenState extends State<CrewListScreen> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DashboardApi.getDashboard();
      if (mounted) setState(() { _dashboard = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List get _crews => (_dashboard?['crews_data'] as List?) ?? [];
  int get _unreadCount => (_dashboard?['unread'] as int?) ?? 0;
  int get _totalLogsThisWeek => (_dashboard?['total_logs_this_week'] as int?) ?? 0;
  int? get _quickCrewId => _dashboard?['quick_crew_id'] as int?;

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('크루 참가'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '초대 코드 입력'),
          style: TextStyle(color: WColors.text),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              try {
                final res = await CrewApi.joinCrew(ctrl.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) context.push('/crew/${res['id']}');
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('유효하지 않은 코드예요.')));
              }
            },
            child: const Text('참가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.bg,
      appBar: wHomeAppBar(
        context: context,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 22),
            color: WColors.textMuted,
            tooltip: '테마 설정',
            onPressed: () => showThemeSettingsSheet(context),
          ),
          _LogoutButton(),
          _NotificationButton(
            count: _unreadCount,
            onTap: () => context.push('/notifications').then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: WColors.purple))
          : RefreshIndicator(
              color: WColors.purple,
              backgroundColor: WColors.bg2,
              onRefresh: _load,
              child: _crews.isEmpty ? _buildEmpty() : _buildContent(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        backgroundColor: WColors.purple,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _crews.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildWeeklySummary();
        final data = _crews[i - 1] as Map;
        final crew = data['crew'] as Map;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _CrewCard(
            data: data,
            crew: crew,
            index: i - 1,
            onTap: () => context.push('/crew/${crew['id']}'),
          ),
        );
      },
    );
  }

  // ── 주간 요약 카드 ──────────────────────────────────────────────────────
  Widget _buildWeeklySummary() {
    final user = AuthStore().user;
    final name = user?['username'] ?? user?['nickname'] ?? '';
    final hasQuickCrew = _quickCrewId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a0a2e), Color(0xFF0a1a2e)],
        ),
        border: Border.all(color: WColors.purple.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: WColors.purple.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 0),
        ],
      ),
      child: Stack(
        children: [
          // 배경 글로우 장식
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WColors.purple.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -20, left: 20,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WColors.cyan.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 인사말
                Row(
                  children: [
                    const Text('👋 ', style: TextStyle(fontSize: 14)),
                    Text(
                      name.isNotEmpty ? '안녕하세요, $name님' : '안녕하세요',
                      style: TextStyle(fontSize: 13, color: WColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 이번 주 인증 횟수
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => WColors.gradientPurpleCyan.createShader(b),
                      child: Text(
                        '$_totalLogsThisWeek',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '회',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WColors.text),
                      ),
                    ),
                    const Spacer(),
                    // 바로 인증하기 버튼
                    if (hasQuickCrew)
                      GestureDetector(
                        onTap: _showCrewPickerForLog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: WColors.gradientPurpleCyan,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: WColors.purple.withValues(alpha: 0.4), blurRadius: 12),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('📸 ', style: TextStyle(fontSize: 14)),
                              Text('인증하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '이번 주 내 운동 인증',
                  style: TextStyle(fontSize: 12, color: WColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: WColors.bg2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WColors.borderH),
              ),
              child: const Center(child: Text('🏋️', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 20),
            Text('아직 크루가 없어요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: WColors.text)),
            const SizedBox(height: 8),
            Text(
              '크루를 만들거나 초대코드로\n참가해보세요',
              style: TextStyle(color: WColors.textMuted, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            WGradientButton('크루 만들기', icon: Icons.add,
                onPressed: () => context.push('/crew/create').then((_) => _load())),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showJoinDialog,
              icon: const Icon(Icons.group_add, size: 18),
              label: const Text('코드로 참가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCrewPickerForLog() {
    if (_crews.length == 1) {
      final crew = (_crews[0] as Map)['crew'] as Map;
      context.push('/crew/${crew['id']}/log/create').then((_) => _load());
      return;
    }
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('어느 크루에 인증할까요?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WColors.text)),
              ),
            ),
            ..._crews.map((item) {
              final crew = (item as Map)['crew'] as Map;
              final name = crew['name'] as String? ?? '';
              final memberCount = crew['member_count'] ?? 0;
              return ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: WColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '#',
                    style: TextStyle(color: WColors.purple, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('멤버 $memberCount명', style: TextStyle(fontSize: 12, color: WColors.textMuted)),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: WColors.textDim),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/crew/${crew['id']}/log/create').then((_) => _load());
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFabMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: WColors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add, color: WColors.purple, size: 20),
              ),
              title: const Text('크루 만들기', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('새로운 크루를 시작해요', style: TextStyle(fontSize: 12, color: WColors.textMuted)),
              onTap: () { Navigator.pop(ctx); context.push('/crew/create').then((_) => _load()); },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: WColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.group_add, color: WColors.cyan, size: 20),
              ),
              title: const Text('코드로 참가', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('초대 코드를 입력해요', style: TextStyle(fontSize: 12, color: WColors.textMuted)),
              onTap: () { Navigator.pop(ctx); _showJoinDialog(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 크루 카드 ──────────────────────────────────────────────────────────────
class _CrewCard extends StatelessWidget {
  final Map data;
  final Map crew;
  final int index;
  final VoidCallback onTap;

  _CrewCard({
    required this.data,
    required this.crew,
    required this.index,
    required this.onTap,
  });

  static final _accentColors = [WColors.purple, WColors.cyan, WColors.pink, WColors.green, WColors.yellow];

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[index % _accentColors.length];
    final name = crew['name'] as String? ?? '';
    final memberCount = crew['member_count'] ?? 0;
    final myPct = (data['my_pct'] as num?)?.toInt() ?? 0;
    final crewLogsCount = (data['crew_logs_count'] as num?)?.toInt() ?? 0;
    final pendingCount = (data['pending_count'] as num?)?.toInt() ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '#';

    final pctColor = myPct >= 100 ? WColors.green : myPct >= 50 ? WColors.yellow : WColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WColors.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: -20, right: -20,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단: 아바타 + 이름 + 승인 대기 배지 + 화살표
                    Row(
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
                            ),
                            border: Border.all(color: accent.withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Text(initial,
                              style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name,
                                        style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w700,
                                          color: WColors.text, letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: WColors.yellow.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: WColors.yellow.withValues(alpha: 0.4)),
                                      ),
                                      child: Text('🤝 $pendingCount',
                                          style: TextStyle(fontSize: 11, color: WColors.yellow, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 12, color: WColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text('$memberCount명',
                                      style: TextStyle(fontSize: 12, color: WColors.textMuted)),
                                  const SizedBox(width: 10),
                                  const Text('🔥', style: TextStyle(fontSize: 11)),
                                  const SizedBox(width: 3),
                                  Text('이번 주 ${crewLogsCount}회',
                                      style: TextStyle(fontSize: 12, color: WColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: accent),
                        ),
                      ],
                    ),

                    // 달성률이 있을 때만 표시
                    if (myPct > 0 || true) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('내 이번 주 달성률',
                              style: TextStyle(fontSize: 11, color: WColors.textMuted)),
                          Text(
                            '$myPct%',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: pctColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      WProgressBar(myPct / 100, green: myPct >= 100, yellow: myPct >= 50 && myPct < 100),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 알림 버튼 ──────────────────────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotificationButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: WColors.textMuted),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 8, top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: WColors.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: WColors.red.withValues(alpha: 0.6), blurRadius: 6)],
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

// ── 로그아웃 버튼 ──────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout, color: WColors.textMuted),
      tooltip: '로그아웃',
      onPressed: () async {
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
      },
    );
  }
}
