import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/goal_api.dart';
import '../../utils/theme.dart';
import '../../widgets/w_app_bar.dart';

const _categories = [
  ('런닝·조깅', '🏃'), ('헬스·웨이트', '🏋️'), ('자전거', '🚴'),
  ('수영', '🏊'), ('요가·필라테스', '🧘'), ('홈트', '🤸'),
  ('구기종목', '⚽'), ('등산·트레킹', '🥾'), ('기타', '💪'),
];

class CreateGoalScreen extends StatefulWidget {
  final int crewId;
  const CreateGoalScreen({super.key, required this.crewId});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = '런닝·조깅';
  int _frequency = 3;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await GoalApi.createGoal(
        crewId: widget.crewId,
        title: _titleCtrl.text.trim(),
        category: _category,
        frequencyPerWeek: _frequency,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목표 등록에 실패했어요.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wAppBar(context: context, title: const Text('목표 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel('운동 카테고리'),
            const SizedBox(height: 10),
            _buildCategoryGrid(),
            const SizedBox(height: 24),
            _sectionLabel('목표 이름'),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '예: 5km 이상 달리기',
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('주당 횟수'),
            const SizedBox(height: 10),
            _buildFrequencyPills(),
            const SizedBox(height: 24),
            _sectionLabel('상세 조건', optional: true),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: '예: 페이스 6분 이내, 야외 러닝만 인정',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('목표 등록 →'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, {bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: WColors.textMuted, letterSpacing: 0.3)),
        if (optional)
          Text('  선택',
              style: TextStyle(fontSize: 12, color: WColors.textDim)),
      ],
    );
  }

  // ── 카테고리 3열 그리드 ───────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: _categories.map((c) {
        final (name, icon) = c;
        final selected = _category == name;
        return GestureDetector(
          onTap: () => setState(() => _category = name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected
                  ? WColors.cyan.withValues(alpha: 0.1)
                  : WColors.bg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? WColors.cyan : WColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? WColors.cyan : WColors.textMuted,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 주당 횟수 pill 버튼 ──────────────────────────────────────────
  Widget _buildFrequencyPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final n = i + 1;
        final selected = _frequency == n;
        return GestureDetector(
          onTap: () => setState(() => _frequency = n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? WColors.cyan.withValues(alpha: 0.1)
                  : WColors.bg3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? WColors.cyan : WColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              '$n회',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? WColors.cyan : WColors.textMuted,
              ),
            ),
          ),
        );
      }),
    );
  }
}
