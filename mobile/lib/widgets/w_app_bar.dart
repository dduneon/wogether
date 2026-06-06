import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../utils/theme.dart';
import '../utils/theme_provider.dart';

// ── Frosted-glass 배경 ────────────────────────────────────────────────
Widget _frostedBg() {
  final color = ThemeProvider().isLight
      ? const Color(0xE5F5F5F7)
      : const Color(0xCC0D0D0D);
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(color: color),
    ),
  );
}

PreferredSizeWidget _bottomBorder() => PreferredSize(
  preferredSize: Size.fromHeight(0.5),
  child: Divider(height: 0.5, thickness: 0.5, color: WColors.border),
);

// ── 일반 서브 페이지 AppBar (폼, 설정 등) ─────────────────────────────
AppBar wAppBar({
  required BuildContext context,
  Widget? title,
  List<Widget>? actions,
  bool showBackButton = true,
  PreferredSizeWidget? bottom,
}) {
  final canPop = showBackButton && (Navigator.of(context).canPop() || GoRouter.of(context).canPop());
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
    flexibleSpace: _frostedBg(),
    bottom: bottom ?? _bottomBorder(),
    leading: canPop ? _WBackButton() : null,
    titleSpacing: 0,
    centerTitle: true,
    title: title == null
        ? null
        : DefaultTextStyle(
            style: TextStyle(
              color: WColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
            child: title,
          ),
    actions: [
      ...?actions,
      const SizedBox(width: 4),
    ],
  );
}

// ── 홈 AppBar (로고 전용) ─────────────────────────────────────────────
AppBar wHomeAppBar({
  required BuildContext context,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: false,
    flexibleSpace: _frostedBg(),
    bottom: bottom ?? _bottomBorder(),
    titleSpacing: 0,
    centerTitle: true,
    title: ShaderMask(
      shaderCallback: (b) => WColors.gradientPurpleCyan.createShader(b),
      child: const Text(
        'Wogether',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -1.0,
        ),
      ),
    ),
    actions: [
      ...?actions,
      const SizedBox(width: 4),
    ],
  );
}

// ── Large Title 헤더 (iOS 방식) ───────────────────────────────────────
// [SliverAppBar(pinned)] + [SliverToBoxAdapter(큰 타이틀)] 두 슬리버를 반환.
// CustomScrollView / NestedScrollView의 headerSliverBuilder에서
// ...wLargeTitleHeader(...) 로 스프레드해서 사용.
//
// 큰 타이틀은 스크롤 컨텐츠의 일부로 처리되어 자연스럽게 사라지고,
// 핀된 AppBar에는 작은 타이틀만 남아 백버튼과 절대 겹치지 않음.
List<Widget> wLargeTitleHeader({
  required BuildContext context,
  required String title,
  List<Widget>? actions,
  bool showBackButton = true,
  bool gradientTitle = false,
  PreferredSizeWidget? bottom,
}) {
  final canPop = showBackButton && (Navigator.of(context).canPop() || GoRouter.of(context).canPop());

  final smallTitle = Text(
    title,
    style: TextStyle(
      color: WColors.text,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
  );

  final largeTitle = gradientTitle
      ? ShaderMask(
          shaderCallback: (b) => WColors.gradientPurpleCyan.createShader(b),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
        )
      : Text(
          title,
          style: TextStyle(
            color: WColors.text,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
          ),
        );

  return [
    // ① 핀된 작은 AppBar — 백버튼 + 작은 타이틀 + 액션
    SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 0, // 확장 없음 — 타이틀은 아래 슬리버에서
      backgroundColor: ThemeProvider().isLight ? const Color(0xE5F5F5F7) : const Color(0xCC0D0D0D),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: canPop ? _WBackButton() : null,
      titleSpacing: canPop ? 4 : 20,
      title: smallTitle,
      centerTitle: false,
      actions: [
        ...?actions,
        const SizedBox(width: 4),
      ],
      bottom: bottom ??
          PreferredSize(
            preferredSize: Size.fromHeight(0.5),
            child: Divider(height: 0.5, thickness: 0.5, color: WColors.border),
          ),
      flexibleSpace: _frostedBg(),
    ),

    // ② 큰 타이틀 — 스크롤과 함께 사라짐
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        child: largeTitle,
      ),
    ),
  ];
}

// ── 뒤로가기 버튼 ─────────────────────────────────────────────────────
class _WBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).pop();
        }
      },
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: WColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WColors.border),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 15,
            color: WColors.text,
          ),
        ),
      ),
    );
  }
}
