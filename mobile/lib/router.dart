import 'package:go_router/go_router.dart';
import 'utils/auth_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/crew/crew_list_screen.dart';
import 'screens/crew/crew_detail_screen.dart';
import 'screens/crew/create_crew_screen.dart';
import 'screens/log/create_log_screen.dart';
import 'screens/goal/create_goal_screen.dart';
import 'screens/notification/notification_screen.dart';
import 'screens/settings/settings_screen.dart';

final router = GoRouter(
  redirect: (context, state) {
    final loggedIn = AuthStore().isLoggedIn;
    final onAuth = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/';
    return null;
  },
  refreshListenable: AuthStore(),
  routes: [
    GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),
    GoRoute(path: '/', builder: (ctx, _) => const CrewListScreen()),
    GoRoute(
      path: '/crew/create',
      builder: (ctx, _) => const CreateCrewScreen(),
    ),
    GoRoute(
      path: '/crew/:id',
      builder: (ctx, state) =>
          CrewDetailScreen(crewId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/crew/:id/log/create',
      builder: (ctx, state) =>
          CreateLogScreen(crewId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/crew/:id/goal/create',
      builder: (ctx, state) =>
          CreateGoalScreen(crewId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/notifications', builder: (ctx, _) => const NotificationScreen()),
    GoRoute(path: '/settings', builder: (ctx, _) => const SettingsScreen()),
  ],
);
