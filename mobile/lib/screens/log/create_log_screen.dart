import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/log_api.dart';
import '../../api/goal_api.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import 'dart:io';

const _workoutTypes = ['헬스', '러닝', '수영', '자전거', '요가', '필라테스', '등산', '축구', '농구', '기타'];

class CreateLogScreen extends StatefulWidget {
  final int crewId;
  const CreateLogScreen({super.key, required this.crewId});

  @override
  State<CreateLogScreen> createState() => _CreateLogScreenState();
}

class _CreateLogScreenState extends State<CreateLogScreen> {
  final _captionCtrl = TextEditingController();
  final _customTypeCtrl = TextEditingController();
  List<File> _photos = [];
  List _goals = [];
  int? _selectedGoalId;
  String? _selectedType;
  bool _showCustomType = false;
  bool _loading = false;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    ThemeProvider().addListener(_onTheme);
    _loadGoals();
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    ThemeProvider().removeListener(_onTheme);
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await GoalApi.getGoals(widget.crewId);
      setState(() => _goals = goals.where((g) => g['status'] == 'approved').toList());
    } catch (e) {}
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() { _photos = picked.map((x) => File(x.path)).toList(); _currentPhoto = 0; });
    }
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) {
      setState(() { _photos = [..._photos, File(picked.path)]; });
    }
  }

  String get _workoutType {
    if (_showCustomType) return _customTypeCtrl.text.trim();
    return _selectedType ?? '';
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 최소 1장 선택해주세요.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await LogApi.createLog(
        crewId: widget.crewId,
        photoPaths: _photos.map((f) => f.path).toList(),
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        workoutType: _workoutType.isEmpty ? null : _workoutType,
        goalId: _selectedGoalId,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업로드에 실패했어요.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.bg,
      appBar: AppBar(
        backgroundColor: WColors.bg,
        leading: IconButton(
          icon: Icon(Icons.close, color: WColors.text),
          onPressed: () => context.pop(),
        ),
        title: Text('운동 인증', style: TextStyle(color: WColors.text, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── 사진 영역 ──────────────────────────────────────────
            Stack(
              children: [
                GestureDetector(
                  onTap: _photos.isEmpty ? _pickPhotos : null,
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    color: WColors.bg2,
                    child: _photos.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  color: WColors.bg3,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: WColors.borderH),
                                ),
                                child: Icon(Icons.add_photo_alternate_outlined,
                                    size: 32, color: WColors.textMuted),
                              ),
                              const SizedBox(height: 12),
                              Text('사진을 추가하세요',
                                  style: TextStyle(color: WColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('갤러리 또는 카메라',
                                  style: TextStyle(color: WColors.textDim, fontSize: 13)),
                            ],
                          )
                        : PageView.builder(
                            itemCount: _photos.length,
                            onPageChanged: (i) => setState(() => _currentPhoto = i),
                            itemBuilder: (ctx, i) => Image.file(_photos[i], fit: BoxFit.cover),
                          ),
                  ),
                ),
                // 사진 개수 인디케이터
                if (_photos.length > 1)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${_currentPhoto + 1}/${_photos.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                // 사진 추가/카메라 버튼
                Positioned(
                  bottom: 12, right: 12,
                  child: Row(
                    children: [
                      _photoBtn(Icons.camera_alt_outlined, _pickCamera),
                      const SizedBox(width: 8),
                      _photoBtn(Icons.photo_library_outlined, _pickPhotos),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── 운동 종류 ──────────────────────────────────────
                  Text('운동 종류',
                      style: TextStyle(color: WColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._workoutTypes.map((type) {
                        final selected = !_showCustomType && _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedType = type;
                            _showCustomType = false;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? WColors.purple.withValues(alpha: 0.2) : WColors.bg3,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? WColors.purple : WColors.borderH,
                              ),
                            ),
                            child: Text(type,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selected ? WColors.purple : WColors.textMuted,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                                )),
                          ),
                        );
                      }),
                      // 직접 입력 칩
                      GestureDetector(
                        onTap: () => setState(() { _showCustomType = true; _selectedType = null; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _showCustomType ? WColors.cyan.withValues(alpha: 0.15) : WColors.bg3,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _showCustomType ? WColors.cyan : WColors.borderH),
                          ),
                          child: Text('직접 입력',
                              style: TextStyle(
                                fontSize: 13,
                                color: _showCustomType ? WColors.cyan : WColors.textMuted,
                                fontWeight: _showCustomType ? FontWeight.w700 : FontWeight.normal,
                              )),
                        ),
                      ),
                    ],
                  ),
                  if (_showCustomType) ...[
                    const SizedBox(height: 10),
                    _styledTextField(
                      controller: _customTypeCtrl,
                      hint: '운동 종류를 입력하세요',
                      autofocus: true,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── 목표 연결 ──────────────────────────────────────
                  if (_goals.isNotEmpty) ...[
                    Text('목표 연결',
                        style: TextStyle(color: WColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: WColors.bg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: WColors.borderH),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedGoalId,
                          dropdownColor: WColors.bg3,
                          iconEnabledColor: WColors.textMuted,
                          style: TextStyle(color: WColors.text, fontSize: 14),
                          items: [
                            DropdownMenuItem(value: null,
                                child: Text('연결 안 함', style: TextStyle(color: WColors.textDim))),
                            ..._goals.map((g) => DropdownMenuItem(
                                  value: g['id'] as int,
                                  child: Text(g['title']),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedGoalId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── 한마디 ─────────────────────────────────────────
                  Text('한마디',
                      style: TextStyle(color: WColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _styledTextField(
                    controller: _captionCtrl,
                    hint: '오늘 운동 어땠나요? (선택)',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('올리기 →'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      autofocus: autofocus,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      style: TextStyle(color: WColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: WColors.textDim),
        filled: true,
        fillColor: WColors.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WColors.borderH),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WColors.borderH),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: WColors.purple),
        ),
      ),
    );
  }
}
