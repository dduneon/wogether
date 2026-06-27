import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/auth_api.dart';
import '../../utils/auth_store.dart';
import '../../utils/fcm_service.dart';
import '../../utils/theme.dart';
import '../../utils/theme_provider.dart';
import '../../widgets/w_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
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
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await AuthApi.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      await AuthStore().setToken(res['token'], res['user'] ?? {});
      FcmService.ensureToken();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아이디 또는 비밀번호가 올바르지 않아요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // 로고
              GradientText(
                'Wogether',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '크루와 함께 운동 목표를 달성해요 💪',
                style: TextStyle(color: WColors.textMuted, fontSize: 15),
              ),
              const SizedBox(height: 48),

              // 폼 카드
              WCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: '아이디'),
                      style: TextStyle(color: WColors.text),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      style: TextStyle(color: WColors.text),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: WGradientButton(
                        '로그인',
                        onPressed: _loading ? null : _login,
                        loading: _loading,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 없으신가요? ', style: TextStyle(color: WColors.textMuted, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: Text(
                      '회원가입',
                      style: TextStyle(color: WColors.purpleL, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
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
