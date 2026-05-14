import 'package:flutter/material.dart';

import '../../features/auth/view/login_view.dart';
import '../../features/profile/view/profile_view.dart';

/// Centralized route definitions.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
    login: (_) => const LoginView(),
    profile: (_) => const ProfileView(),
  };
}
