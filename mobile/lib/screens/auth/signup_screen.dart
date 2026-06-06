import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/auth_api.dart';
import '../../utils/auth_store.dart';
import '../../utils/fcm_service.dart';
import '../../utils/theme.dart';
import '../../widgets/w_card.dart';
import '../../widgets/w_app_bar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _signup() async {
    setState(() => _loading = true);
    try {
      final res = await AuthApi.signup(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
        _nicknameCtrl.text.trim(),
      );
      await AuthStore().setToken(res['token'], res['user'] ?? {});
      await FcmService.init();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 실패. 이미 사용 중인 아이디일 수 있어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: wAppBar(context: context, title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
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
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nicknameCtrl,
                    decoration: const InputDecoration(labelText: '닉네임'),
                    style: TextStyle(color: WColors.text),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signup(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: WGradientButton(
                      '가입하기',
                      onPressed: _loading ? null : _signup,
                      loading: _loading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
