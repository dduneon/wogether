import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/crew_api.dart';
import '../../api/log_api.dart';
import '../../api/goal_api.dart';
import '../../api/client.dart';
import '../../utils/auth_store.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import '../../widgets/w_card.dart';
import '../../widgets/w_app_bar.dart';

class CrewDetailScreen extends StatefulWidget {
  final int crewId;
  const CrewDetailScreen({super.key, required this.crewId});

  @override
  State<CrewDetailScreen> createState() => _CrewDetailScreenState();
}

class _CrewDetailScreenState extends State<CrewDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    ThemeProvider().addListener(_onTheme);
    _load();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    ThemeProvider().removeListener(_onTheme);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await CrewApi.getCrew(widget.crewId);
      if (mounted) setState(() { _data = res; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map get _crew => _data?['crew'] ?? {};
  List get _feedItems => _data?['feed_items'] ?? [];
  List get _members => _data?['members'] ?? [];
  List get _pendingForMe => _data?['pending_for_me'] ?? [];
  int? get _myId => AuthStore().user?['id'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wAppBar(
        context: context,
        title: Text(_crew['name'] ?? ''),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: WColors.textMuted),
            onPressed: _showMenu,
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: _showAddMenu,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: WColors.gradientPurplePink,
            boxShadow: [
              BoxShadow(color: WColors.purple.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 1),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: WColors.purple))
          : Stack(
              children: [
                TabBarView(
                  controller: _tabCtrl,
                  children: [
                    RefreshIndicator(
                      color: WColors.purple,
                      backgroundColor: WColors.bg2,
                      onRefresh: _load,
                      child: _buildFeedTab(),
                    ),
                    RefreshIndicator(
                      color: WColors.purple,
                      backgroundColor: WColors.bg2,
                      onRefresh: _load,
                      child: _buildStatusTab(),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 28, left: 0, right: 0,
                  child: Center(child: _buildFloatingTab()),
                ),
              ],
            ),
    );
  }

  // ── 인증 피드 탭 ─────────────────────────────────────────────────
  Widget _buildFeedTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      children: [
        // 히어로 헤더
        _buildHero(),

        // 동의 대기 배너
        if (_pendingForMe.isNotEmpty) _buildPendingBanner(),

        // 피드 아이템
        if (_feedItems.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Column(children: [
              Text('📸', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('아직 인증 기록이 없어요', style: TextStyle(color: WColors.textMuted)),
            ])),
          )
        else
          ..._feedItems.asMap().entries.map((e) {
            final idx = e.key;
            final item = e.value as Map;
            if (item['type'] == 'log') {
              return _buildLogCard(item['data'], idx);
            } else {
              return _buildActivityCard(item['data']);
            }
          }),
      ],
    );
  }


  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: WColors.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREW', style: TextStyle(fontSize: 11, color: WColors.purple, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            GradientText(
              _crew['name'] ?? '',
              style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8),
            ),
            if (_crew['description'] != null) ...[
              const SizedBox(height: 4),
              Text(_crew['description'], style: TextStyle(color: WColors.textMuted, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: WColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.group_outlined, size: 16, color: WColors.textMuted),
                const SizedBox(width: 6),
                Text('멤버 ${_crew['member_count'] ?? 0}명',
                    style: TextStyle(color: WColors.textMuted, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WColors.yellow.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WColors.yellow.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🤝 동의 대기 중인 목표 ${_pendingForMe.length}개',
                style: TextStyle(color: WColors.yellow, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._pendingForMe.map((g) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g['user_nickname'] ?? '', style: TextStyle(color: WColors.textMuted, fontSize: 12)),
                  Text(g['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
                GestureDetector(
                  onTap: () async {
                    await GoalApi.approveGoal(g['id']);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [WColors.cyan, Color(0xFF0891b2)]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('동의 ✓', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map log, int idx) {
    final images = (log['images'] as List?) ?? [];
    final logUser = log['user'] as Map? ?? {};
    final isMine = logUser['id'] == _myId;
    final isLiked = log['is_liked'] ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: WColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: WColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(children: [
                  WAvatar(logUser['nickname'] ?? '', size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(logUser['nickname'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: WColors.text)),
                      Text(() {
                        return _relativeTime(log['timestamp']?.toString());
                      }(),
                          style: TextStyle(fontSize: 12, color: WColors.textMuted)),
                    ],
                  )),
                  if (log['workout_type'] != null)
                    WTag(log['workout_type'], color: WColors.cyan),
                  if (isMine) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteLog(log['id']),
                      child: Icon(Icons.delete_outline, color: WColors.textDim, size: 18),
                    ),
                  ],
                ]),
              ),

              // 이미지
              if (images.isNotEmpty)
                images.length == 1
                    ? CachedNetworkImage(
                        imageUrl: fixImageUrl(images[0].toString()),
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(height: 200, color: WColors.bg3,
                            child: Icon(Icons.broken_image, color: WColors.textDim)),
                      )
                    : SizedBox(
                        height: 240,
                        child: GridView.count(
                          crossAxisCount: images.length == 2 ? 2 : 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          children: images.take(3).map((url) => CachedNetworkImage(
                            imageUrl: fixImageUrl(url.toString()),
                            fit: BoxFit.cover,
                          )).toList(),
                        ),
                      ),

              // 캡션
              if (log['caption'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${logUser['nickname']}  ',
                        style: TextStyle(fontWeight: FontWeight.w700, color: WColors.text, fontSize: 14)),
                    TextSpan(text: log['caption'],
                        style: TextStyle(color: WColors.text, fontSize: 14, height: 1.5)),
                  ])),
                ),

              // 액션
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                child: Row(children: [
                  _actionBtn(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '${log['like_count'] ?? 0}',
                    color: isLiked ? WColors.pink : WColors.textMuted,
                    onTap: () => _toggleLike(log['id'], idx),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map act) {
    final actUser = act['user'] as Map? ?? {};
    final meta = act['meta'] as Map? ?? {};
    final eventType = act['event_type']?.toString() ?? '';
    final nickname = actUser['nickname']?.toString() ?? '';

    String icon;
    String text;
    Color accentColor;

    if (eventType == 'join') {
      icon = '🤝'; accentColor = WColors.cyan;
      text = '$nickname님이 크루에 합류했어요!';
    } else if (eventType == 'goal_added') {
      icon = '🎯'; accentColor = WColors.purple;
      text = '$nickname님이 목표를 추가했어요 — ${meta['goal_title']} (주 ${meta['frequency']}회)';
    } else if (eventType == 'goal_approved') {
      icon = '✅'; accentColor = WColors.green;
      text = '$nickname님의 목표 "${meta['goal_title']}"이(가) 승인됐어요!';
    } else if (eventType == 'goal_completed') {
      icon = '🏆'; accentColor = WColors.yellow;
      text = '$nickname님이 이번 주 목표 "${meta['goal_title']}"을(를) 달성했어요!';
    } else {
      icon = '📢'; accentColor = WColors.textMuted;
      text = '$nickname님의 활동이 있어요.';
    }

    final timeStr = _relativeTime(act['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: WColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(text,
                    style: TextStyle(color: WColors.text, fontSize: 13, height: 1.4)),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(timeStr, style: TextStyle(color: WColors.textDim, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(String? raw) {
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
    } catch (_) { return ''; }
  }

  Widget _actionBtn({required IconData icon, required String label, Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20, color: color ?? WColors.textMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, color: color ?? WColors.textMuted)),
        ]),
      ),
    );
  }

  // ── 현황 탭 ──────────────────────────────────────────────────────
  Widget _buildStatusTab() {
    if (_members.isEmpty) {
      return Center(child: Text('멤버가 없어요.', style: TextStyle(color: WColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _members.length,
      itemBuilder: (ctx, i) => _buildMemberCard(_members[i]),
    );
  }

  Widget _buildMemberCard(Map member) {
    final user = member['user'] as Map? ?? {};
    final goals = (member['goals'] as List?) ?? [];
    final pct = (member['avg_percent'] as num? ?? 0).toInt();
    final isOwner = member['role'] == 'owner';
    final isMe = user['id'] == _myId;

    Color pctColor;
    if (pct >= 100) pctColor = WColors.green;
    else if (pct >= 50) pctColor = WColors.yellow;
    else if (pct > 0) pctColor = WColors.red;
    else pctColor = WColors.textDim;

    final barPct = (pct / 100).clamp(0.0, 1.0);
    final barGreen = pct >= 100;
    final barYellow = pct >= 50 && pct < 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 닉네임 + 달성률
            Row(children: [
              WAvatar(user['nickname'] ?? '', size: 36),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(user['nickname'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WColors.text)),
                    if (isOwner) ...[
                      const SizedBox(width: 6),
                      WTag('크루장', color: WColors.purple),
                    ],
                  ]),
                ],
              )),
              Text('$pct%',
                  style: GoogleFonts.spaceMono(fontSize: 24, fontWeight: FontWeight.w700, color: pctColor),
              ),
            ]),
            const SizedBox(height: 12),
            WProgressBar(barPct, green: barGreen, yellow: barYellow),
            const SizedBox(height: 14),

            // 목표 목록
            if (goals.isEmpty)
              Text('목표 없음', style: TextStyle(fontSize: 13, color: WColors.textDim))
            else
              ...goals.map((g) {
                final prog = g['progress'] as Map? ?? {};
                final done = prog['done'] ?? 0;
                final target = prog['target'] ?? 1;
                final isMyGoal = g['user_id'] == _myId;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text(g['title'] ?? '',
                        style: TextStyle(color: WColors.textMuted, fontSize: 13))),
                    Text('$done/$target',
                        style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700, fontSize: 12, color: WColors.text)),
                    if (g['status'] == 'pending') ...[
                      const SizedBox(width: 6),
                      WTag('대기', color: WColors.yellow),
                    ],
                    if (isMyGoal) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _deleteGoal(g['id']),
                        child: Icon(Icons.close, size: 16, color: WColors.textDim),
                      ),
                    ],
                  ]),
                );
              }),

            // 독촉 버튼 (내가 아닌 멤버에게만)
            if (!isMe) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _nudge(user['id']),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: WColors.bg3,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: WColors.borderH),
                  ),
                  child: Text('👉 운동하라고 콕!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: WColors.textMuted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 액션 ─────────────────────────────────────────────────────────
  Future<void> _toggleLike(int logId, int feedIdx) async {
    try {
      final res = await LogApi.toggleLike(logId);
      setState(() {
        final item = _feedItems[feedIdx];
        if (item['type'] == 'log') {
          item['data']['is_liked'] = res['liked'];
          item['data']['like_count'] = res['count'];
        }
      });
    } catch (e) {}
  }

  Future<void> _deleteLog(int logId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: Text('인증 기록을 삭제하면 복구할 수 없어요.', style: TextStyle(color: WColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('삭제', style: TextStyle(color: WColors.red))),
        ],
      ),
    );
    if (ok == true) { await LogApi.deleteLog(logId); _load(); }
  }

  Future<void> _deleteGoal(int goalId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 삭제'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('삭제', style: TextStyle(color: WColors.red))),
        ],
      ),
    );
    if (ok == true) { await GoalApi.deleteGoal(goalId); _load(); }
  }

  Future<void> _nudge(int targetId) async {
    try {
      await CrewApi.nudge(widget.crewId, targetId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('콕! 찔렀어요 👉')));
    } catch (e) {}
  }

  Widget _buildFloatingTab() {
    return ListenableBuilder(
      listenable: _tabCtrl,
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
                  _floatingTabItem(0, '인증 피드'),
                  _floatingTabItem(1, '현황'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _floatingTabItem(int index, String label) {
    final active = _tabCtrl.index == index;
    return GestureDetector(
      onTap: () => _tabCtrl.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: active ? WColors.purple.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: active ? Border.all(color: WColors.purple.withValues(alpha: 0.35)) : null,
          boxShadow: active
              ? [
                  BoxShadow(color: WColors.purple.withValues(alpha: 0.25), blurRadius: 16),
                  BoxShadow(color: WColors.purple.withValues(alpha: 0.15), blurRadius: 4),
                ]
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

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2))),
              _addMenuItem(
                gradient: WColors.gradientPurplePink,
                icon: Icons.camera_alt_rounded,
                title: '운동 인증',
                subtitle: '오늘의 운동을 사진으로 인증해요',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/crew/${widget.crewId}/log/create').then((_) => _load());
                },
              ),
              const SizedBox(height: 10),
              _addMenuItem(
                gradient: LinearGradient(colors: [WColors.cyan, Color(0xFF0891b2)]),
                icon: Icons.flag_rounded,
                title: '목표 추가',
                subtitle: '이번 주 달성할 운동 목표를 설정해요',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/crew/${widget.crewId}/goal/create').then((_) => _load());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addMenuItem({
    required LinearGradient gradient,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WColors.border),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: WColors.text)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: WColors.textMuted)),
            ],
          )),
          Icon(Icons.chevron_right, color: WColors.textDim, size: 20),
        ]),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: WColors.border, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.link, color: WColors.cyan),
              title: const Text('초대 링크 공유'),
              subtitle: Text('join/${_crew['invite_code'] ?? ''}',
                  style: GoogleFonts.spaceMono(color: WColors.cyan, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                final code = _crew['invite_code'] ?? '';
                final crewName = _crew['name'] ?? '';
                final link = '$baseUrl/join/$code';
                final text = '[Wogether] $crewName 크루에 초대합니다!\n함께 운동 목표를 달성해요 💪\n$link';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('초대 링크가 클립보드에 복사되었습니다')),
                );
              },
            ),
            if (_crew['owner_id'] != _myId)
              ListTile(
                leading: Icon(Icons.exit_to_app, color: WColors.red),
                title: Text('크루 탈퇴', style: TextStyle(color: WColors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('크루에서 나가시겠어요?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(c, true),
                            child: Text('나가기', style: TextStyle(color: WColors.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await CrewApi.leaveCrew(widget.crewId);
                    if (mounted) context.go('/');
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
