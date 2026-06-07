import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/crew_api.dart';
import '../../api/dashboard_api.dart';
import '../../utils/auth_store.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import '../../widgets/w_card.dart';
import '../../widgets/w_app_bar.dart';
import '../../widgets/workout_calendar.dart';
import 'create_crew_screen.dart';

class CrewListScreen extends StatefulWidget {
  const CrewListScreen({super.key});

  @override
  State<CrewListScreen> createState() => _CrewListScreenState();
}

class _CrewListScreenState extends State<CrewListScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ThemeProvider().addListener(_onTheme);
    _load();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _tabController.dispose();
    ThemeProvider().removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await DashboardApi.getDashboard();
      if (mounted) setState(() { _dashboard = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List get _crews         => (_dashboard?['crews_data'] as List?) ?? [];
  int  get _unreadCount   => (_dashboard?['unread'] as int?) ?? 0;
  int  get _totalLogs     => (_dashboard?['total_logs_this_week'] as int?) ?? 0;
  int  get _totalGoal     => (_dashboard?['total_goal_count'] as int?) ?? 0;
  int  get _goalRemaining => (_dashboard?['goal_remaining'] as int?) ?? 0;
  int? get _quickCrewId   => _dashboard?['quick_crew_id'] as int?;
  int  get _streak        => (_dashboard?['streak'] as int?) ?? 0;
  List get _weekDots      => (_dashboard?['week_dots'] as List?) ?? List.filled(7, false);
  bool get _todayLogged   => (_dashboard?['today_logged'] as bool?) ?? false;
  List get _recentFeed    => (_dashboard?['recent_feed'] as List?) ?? [];
  int  get _totalPending  => _crews.fold(0, (sum, d) => sum + (((d as Map)['pending_count'] as int?) ?? 0));

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: WColors.bg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: WColors.border)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: WColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // 아이콘 + 타이틀
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: WColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: WColors.cyan.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.group_add_outlined, color: WColors.cyan, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('크루 참가',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WColors.text)),
                            Text('초대 코드를 입력해주세요',
                                style: TextStyle(fontSize: 13, color: WColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 코드 입력 필드
                    Container(
                      decoration: BoxDecoration(
                        color: WColors.bg3,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: WColors.border),
                      ),
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: WColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'XXXXXX',
                          hintStyle: TextStyle(
                            color: WColors.textDim,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 버튼 행
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: WColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('취소', style: TextStyle(color: WColors.textMuted, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [WColors.cyan, WColors.purple],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: WColors.cyan.withValues(alpha: 0.35), blurRadius: 16),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: () async {
                                final code = ctrl.text.trim();
                                if (code.isEmpty) return;
                                try {
                                  final res = await CrewApi.joinCrew(code);
                                  if (!ctx.mounted) return;
                                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                                  if (mounted) context.push('/crew/${res['id']}');
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('유효하지 않은 코드예요.')));
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('참가하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: WColors.textMuted,
            onPressed: () => context.push('/settings'),
          ),
          _NotificationButton(
            count: _unreadCount,
            onTap: () => context.push('/notifications').then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: WColors.purple))
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatusTab(),
                    _buildCrewTab(),
                  ],
                ),
                Positioned(
                  bottom: 28,
                  left: 0, right: 0,
                  child: Center(child: _buildFloatingTab()),
                ),
              ],
            ),
    );
  }

  Widget _buildFloatingTab() {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: WColors.bg2.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 32, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _floatingTabItem(0, '현황'),
                  _floatingTabItem(1, '크루 목록'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _floatingTabItem(int index, String label) {
    final active = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: active ? WColors.purple.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(color: WColors.purple.withValues(alpha: 0.25), blurRadius: 16),
                  BoxShadow(color: WColors.purple.withValues(alpha: 0.15), blurRadius: 4),
                ]
              : null,
          border: active
              ? Border.all(color: WColors.purple.withValues(alpha: 0.35))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? WColors.purpleL : WColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab() {
    final user = AuthStore().user;
    final name = user?['nickname'] ?? user?['username'] ?? '';

    return RefreshIndicator(
      color: WColors.purple,
      backgroundColor: WColors.bg2,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ── 헤더 인사말 ──
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Text('👋 ', style: TextStyle(fontSize: 14)),
                Text('안녕하세요, ',
                    style: TextStyle(fontSize: 15, color: WColors.textMuted)),
                Text(name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WColors.purpleL)),
                Text('님', style: TextStyle(fontSize: 15, color: WColors.textMuted)),
              ],
            ),
          ),

          // ── 목표 승인 액션 카드 ──
          if (_totalPending > 0) ...[
            _PendingActionCard(
              count: _totalPending,
              onTap: () {
                final target = _crews.firstWhere(
                  (d) => (((d as Map)['pending_count'] as int?) ?? 0) > 0,
                  orElse: () => _crews.first,
                ) as Map;
                context.push('/crew/${target['crew']['id']}');
              },
            ),
            const SizedBox(height: 12),
          ],

          // ── 스트릭 히어로 카드 ──
          _StreakHeroCard(
            streak: _streak,
            weekDots: _weekDots,
            totalLogs: _totalLogs,
            totalGoal: _totalGoal,
            goalRemaining: _goalRemaining,
          ),
          const SizedBox(height: 12),

          // ── 인증 CTA / 완료 상태 ──
          if (_todayLogged)
            _DoneStateCard(onExtraLog: _quickCrewId != null ? _showCrewPickerForLog : null)
          else if (_quickCrewId != null)
            _LogCTACard(crewCount: _crews.length, onTap: _showCrewPickerForLog)
          else
            const SizedBox.shrink(),

          // ── 미니 소셜 피드 ──
          if (_recentFeed.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionLabel(label: '최근 팀 활동'),
            const SizedBox(height: 10),
            _MiniFeedCard(
              items: _recentFeed,
              onTap: (crewId) => context.push('/crew/$crewId'),
            ),
          ],

          // ── 운동 달력 ──
          const SizedBox(height: 24),
          _SectionLabel(label: '운동 달력'),
          const SizedBox(height: 10),
          const WorkoutCalendarWidget(),
        ],
      ),
    );
  }

  Widget _buildCrewTab() {
    return RefreshIndicator(
      color: WColors.purple,
      backgroundColor: WColors.bg2,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ── 액션 버튼 행 ──
          Row(
            children: [
              Expanded(
                child: _CrewActionButton(
                  icon: Icons.add_rounded,
                  label: '크루 만들기',
                  color: WColors.purple,
                  onTap: () => showCreateCrewSheet(context).then((_) => _load()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CrewActionButton(
                  icon: Icons.group_add_outlined,
                  label: '코드로 참가',
                  color: WColors.cyan,
                  onTap: _showJoinDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_crews.isNotEmpty) ...[
            _SectionLabel(label: '내 크루', count: _crews.length),
            const SizedBox(height: 10),
            ..._crews.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CrewCard(
                data: e.value as Map,
                crew: (e.value as Map)['crew'] as Map,
                index: e.key,
                onTap: () => context.push('/crew/${(e.value as Map)['crew']['id']}'),
              ),
            )),
          ] else
            _buildEmptyCrewsSimple(),
        ],
      ),
    );
  }

  Widget _buildEmptyCrewsSimple() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text('🏋️', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('아직 크루가 없어요',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WColors.text)),
          const SizedBox(height: 6),
          Text('위 버튼으로 크루를 만들거나 참가해보세요',
              style: TextStyle(color: WColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
        ],
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
      isScrollControlled: true,
      backgroundColor: WColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('어느 크루에 인증할까요?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WColors.text)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._crews.map((item) {
                      final crew = (item as Map)['crew'] as Map;
                      final crewName = crew['name'] as String? ?? '';
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
                            crewName.isNotEmpty ? crewName[0].toUpperCase() : '#',
                            style: TextStyle(color: WColors.purple, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        title: Text(crewName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('멤버 $memberCount명',
                            style: TextStyle(fontSize: 12, color: WColors.textMuted)),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showFabMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: WColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: WColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.add, color: WColors.purple, size: 20),
              ),
              title: const Text('크루 만들기', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('새로운 크루를 시작해요',
                  style: TextStyle(fontSize: 12, color: WColors.textMuted)),
              onTap: () { Navigator.pop(ctx); showCreateCrewSheet(context).then((_) => _load()); },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: WColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.group_add, color: WColors.cyan, size: 20),
              ),
              title: const Text('코드로 참가', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('초대 코드를 입력해요',
                  style: TextStyle(fontSize: 12, color: WColors.textMuted)),
              onTap: () { Navigator.pop(ctx); _showJoinDialog(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 섹션 레이블
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionLabel({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          count != null ? '$label $count' : label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.8, color: WColors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: WColors.border, height: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 목표 승인 액션 카드
// ─────────────────────────────────────────────────────────────────────────────
class _PendingActionCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingActionCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WColors.yellow.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WColors.yellow.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('목표 승인 요청 $count건',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: WColors.text)),
                  const SizedBox(height: 2),
                  Text('팀원의 목표를 확인하고 승인해주세요',
                      style: TextStyle(fontSize: 12, color: WColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: WColors.yellow),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 스트릭 히어로 카드
// ─────────────────────────────────────────────────────────────────────────────
class _StreakHeroCard extends StatelessWidget {
  final int streak;
  final List weekDots;
  final int totalLogs;
  final int totalGoal;
  final int goalRemaining;
  const _StreakHeroCard({
    required this.streak, required this.weekDots,
    required this.totalLogs, required this.totalGoal, required this.goalRemaining,
  });

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1; // 0=월 … 6=일

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            WColors.purple.withValues(alpha: 0.15),
            WColors.cyan.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(color: WColors.purple.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: WColors.purple.withValues(alpha: 0.12), blurRadius: 24)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 스트릭 숫자
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(streak > 0 ? '🔥' : '💤', style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text('$streak',
                  style: TextStyle(
                    fontSize: 46, fontWeight: FontWeight.w800, color: WColors.text,
                    height: 1, fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              Text('일 연속 운동',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: WColors.textMuted, letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(width: 16),
          // 주간 도트 + 횟수
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 7일 도트
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final done = i < weekDots.length ? (weekDots[i] as bool? ?? false) : false;
                    final isToday = i == todayIdx;
                    return Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: done
                                ? WColors.purple.withValues(alpha: 0.25)
                                : WColors.bg2.withValues(alpha: 0.6),
                            border: Border.all(
                              color: done && isToday
                                  ? WColors.cyan
                                  : done
                                      ? WColors.purple.withValues(alpha: 0.6)
                                      : isToday
                                          ? WColors.cyan.withValues(alpha: 0.6)
                                          : WColors.borderH,
                              width: 1.5,
                            ),
                            boxShadow: done ? [
                              BoxShadow(color: WColors.purple.withValues(alpha: 0.2), blurRadius: 6),
                            ] : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(_dayLabels[i],
                            style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: done ? WColors.purpleL : WColors.textMuted,
                            )),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 10),
                // 이번 주 횟수
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$totalLogs',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                                color: WColors.text,
                                fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          if (totalGoal > 0)
                            TextSpan(
                              text: ' / $totalGoal 회',
                              style: TextStyle(fontSize: 13, color: WColors.textMuted),
                            )
                          else
                            TextSpan(
                              text: ' 회',
                              style: TextStyle(fontSize: 13, color: WColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    if (goalRemaining > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: WColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: WColors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Text('아직 $goalRemaining번 더!',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: WColors.purpleL)),
                      ),
                    if (goalRemaining == 0 && totalGoal > 0)
                      const Text('🎉', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 인증 CTA 카드
// ─────────────────────────────────────────────────────────────────────────────
class _LogCTACard extends StatelessWidget {
  final int crewCount;
  final VoidCallback onTap;
  const _LogCTACard({required this.crewCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              WColors.purple.withValues(alpha: 0.22),
              WColors.cyan.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(color: WColors.purple.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: WColors.purple.withValues(alpha: 0.15), blurRadius: 20)],
        ),
        child: Row(
          children: [
            const Text('📸', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘 운동 인증하기',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: WColors.text)),
                  const SizedBox(height: 3),
                  Text(
                    crewCount > 1 ? '어느 크루에 인증할지 선택해요' : '사진을 올려서 크루에게 인증하세요',
                    style: TextStyle(fontSize: 12, color: WColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 15, color: WColors.purpleL),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 오늘 인증 완료 카드
// ─────────────────────────────────────────────────────────────────────────────
class _DoneStateCard extends StatelessWidget {
  final VoidCallback? onExtraLog;
  const _DoneStateCard({this.onExtraLog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: WColors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘 인증 완료!',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WColors.text)),
                const SizedBox(height: 2),
                Text('내일도 화이팅 💪',
                    style: TextStyle(fontSize: 12, color: WColors.textMuted)),
              ],
            ),
          ),
          if (onExtraLog != null)
            GestureDetector(
              onTap: onExtraLog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: WColors.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WColors.border),
                ),
                child: Text('추가 인증',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WColors.text)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 크루 카드
// ─────────────────────────────────────────────────────────────────────────────
class _CrewCard extends StatelessWidget {
  final Map data;
  final Map crew;
  final int index;
  final VoidCallback onTap;

  const _CrewCard({
    required this.data, required this.crew,
    required this.index, required this.onTap,
  });

  static final _accentColors = [WColors.purple, WColors.cyan, WColors.pink, WColors.green, WColors.yellow];

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[index % _accentColors.length];
    final name = crew['name'] as String? ?? '';
    final memberCount = crew['member_count'] ?? 0;
    final myPct = (data['my_pct'] as num?)?.toInt() ?? 0;
    final crewLogsCount = (data['crew_logs_count'] as num?)?.toInt() ?? 0;
    final crewGoalRemaining = (data['crew_goal_remaining'] as num?)?.toInt() ?? 0;
    final pendingCount = (data['pending_count'] as num?)?.toInt() ?? 0;
    final members = (data['members'] as List?) ?? [];
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
                    // 상단: 아이콘 + 이름 + 배지
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
                            ),
                            border: Border.all(color: accent.withValues(alpha: 0.35)),
                          ),
                          alignment: Alignment.center,
                          child: Text(initial,
                              style: TextStyle(color: accent, fontSize: 19, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                            color: WColors.text, letterSpacing: -0.3),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: WColors.yellow.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: WColors.yellow.withValues(alpha: 0.4)),
                                      ),
                                      child: Text('🤝 $pendingCount',
                                          style: TextStyle(fontSize: 10, color: WColors.yellow,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                  if (myPct >= 100) ...[
                                    const SizedBox(width: 6),
                                    const Text('✅', style: TextStyle(fontSize: 13)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 11, color: WColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text('$memberCount명',
                                      style: TextStyle(fontSize: 11, color: WColors.textMuted)),
                                  const SizedBox(width: 8),
                                  const Text('🔥', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 2),
                                  Text('이번 주 ${crewLogsCount}회',
                                      style: TextStyle(fontSize: 11, color: WColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accent),
                        ),
                      ],
                    ),

                    // 팀원 아바타
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ...members.take(6).map((m) {
                            final mMap = m as Map;
                            final loggedToday = mMap['logged_today'] as bool? ?? false;
                            final isMe = mMap['is_me'] as bool? ?? false;
                            final nick = mMap['nickname'] as String? ?? '?';
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Tooltip(
                                message: '$nick${loggedToday ? ' · 오늘 인증 완료' : ' · 미인증'}',
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: loggedToday
                                        ? WColors.green.withValues(alpha: 0.2)
                                        : WColors.bg3,
                                    border: Border.all(
                                      color: isMe
                                          ? WColors.purple
                                          : loggedToday
                                              ? WColors.green.withValues(alpha: 0.7)
                                              : WColors.borderH,
                                      width: isMe ? 2 : 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    nick.isNotEmpty ? nick[0] : '?',
                                    style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w700,
                                      color: loggedToday ? WColors.green : WColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 2),
                          Text(
                            '${members.where((m) => (m as Map)['logged_today'] == true).length}/${members.length}명 인증',
                            style: TextStyle(fontSize: 10, color: WColors.textDim),
                          ),
                        ],
                      ),
                    ],

                    // 달성률 바
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('내 이번 주 달성률',
                            style: TextStyle(fontSize: 11, color: WColors.textMuted)),
                        Row(
                          children: [
                            Text('$myPct%',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: pctColor,
                                    fontFeatures: const [FontFeature.tabularFigures()])),
                            if (crewGoalRemaining > 0)
                              Text(' (${crewGoalRemaining}번 남음)',
                                  style: TextStyle(fontSize: 10, color: WColors.textDim)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    WProgressBar(myPct / 100, green: myPct >= 100, yellow: myPct >= 50 && myPct < 100),
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

// ─────────────────────────────────────────────────────────────────────────────
// 미니 소셜 피드
// ─────────────────────────────────────────────────────────────────────────────
class _MiniFeedCard extends StatelessWidget {
  final List items;
  final void Function(int crewId) onTap;
  const _MiniFeedCard({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value as Map;
          final nickname  = item['nickname']  as String? ?? '';
          final crewName  = item['crew_name'] as String? ?? '';
          final crewId    = item['crew_id']   as int?    ?? 0;
          final caption   = item['caption']   as String?;
          final timeAgo   = item['time_ago']  as String? ?? '';
          final thumbnail = item['thumbnail_url'] as String?;

          return GestureDetector(
            onTap: () => onTap(crewId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? Border(bottom: BorderSide(color: WColors.border))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        WColors.purple.withValues(alpha: 0.3),
                        WColors.cyan.withValues(alpha: 0.2),
                      ]),
                      border: Border.all(color: WColors.purple.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nickname.isNotEmpty ? nickname[0] : '?',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: WColors.purpleL),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: WColors.text),
                            children: [
                              TextSpan(text: nickname,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: '님이 ',
                                  style: TextStyle(color: WColors.textMuted)),
                              TextSpan(text: crewName,
                                  style: TextStyle(color: WColors.purpleL, fontWeight: FontWeight.w600)),
                              TextSpan(text: '에 인증했어요',
                                  style: TextStyle(color: WColors.textMuted)),
                            ],
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(caption,
                              style: TextStyle(fontSize: 11, color: WColors.textDim),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 2),
                        Text(timeAgo, style: TextStyle(fontSize: 10, color: WColors.textDim)),
                      ],
                    ),
                  ),
                  if (thumbnail != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(thumbnail, width: 44, height: 44, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 알림 버튼
// ─────────────────────────────────────────────────────────────────────────────
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
                color: WColors.red, shape: BoxShape.circle,
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

// ─────────────────────────────────────────────────────────────────────────────
// 크루 탭 액션 버튼
// ─────────────────────────────────────────────────────────────────────────────
class _CrewActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CrewActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
