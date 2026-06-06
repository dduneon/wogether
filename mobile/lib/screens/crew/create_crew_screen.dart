import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/crew_api.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';

Future<void> showCreateCrewSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CreateCrewSheet(),
  );
}

class _CreateCrewSheet extends StatefulWidget {
  const _CreateCrewSheet();

  @override
  State<_CreateCrewSheet> createState() => _CreateCrewSheetState();
}

class _CreateCrewSheetState extends State<_CreateCrewSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    ThemeProvider().addListener(_onTheme);
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    ThemeProvider().removeListener(_onTheme);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final res = await CrewApi.createCrew(_nameCtrl.text.trim(), _descCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/crew/${res['id']}');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('크루 생성에 실패했어요.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        color: WColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: WColors.purple.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.group_add_rounded, color: WColors.purple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('크루 만들기',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: WColors.text)),
                        Text('함께 운동할 크루를 시작해요',
                            style: TextStyle(fontSize: 13, color: WColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 크루 이름
                Text('크루 이름',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: WColors.textMuted, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: WColors.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WColors.border),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: WColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '크루 이름을 입력하세요',
                      hintStyle: TextStyle(color: WColors.textDim, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 14),

                // 소개
                Text('소개 (선택)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: WColors.textMuted, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: WColors.bg3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WColors.border),
                  ),
                  child: TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    style: TextStyle(color: WColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '크루를 소개해주세요',
                      hintStyle: TextStyle(color: WColors.textDim, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 버튼 행
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: WColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('취소',
                            style: TextStyle(color: WColors.textMuted, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _nameCtrl.text.trim().isNotEmpty
                              ? LinearGradient(colors: [WColors.purple, WColors.pink])
                              : null,
                          color: _nameCtrl.text.trim().isEmpty ? WColors.bg3 : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _nameCtrl.text.trim().isNotEmpty
                              ? [BoxShadow(color: WColors.purple.withValues(alpha: 0.35), blurRadius: 16)]
                              : null,
                        ),
                        child: FilledButton(
                          onPressed: (_loading || _nameCtrl.text.trim().isEmpty) ? null : _create,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('만들기',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15,
                                    color: _nameCtrl.text.trim().isNotEmpty
                                        ? Colors.white
                                        : WColors.textDim,
                                  )),
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
  }
}

// 라우터에서 여전히 페이지로 쓸 경우를 위한 래퍼
class CreateCrewScreen extends StatelessWidget {
  const CreateCrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCreateCrewSheet(context).then((_) {
        if (context.mounted && !context.canPop()) context.go('/');
      });
    });
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}
