import 'package:flutter/material.dart';

import '../../features/post/view/post_view.dart';

/// Centralized route definitions.
///
/// Add new routes here as you create features.
/// Example:
///   static const String myFeature = '/my-feature';
///   // then add to the routes map below.
class AppRoutes {
  AppRoutes._();

  // Example route (replace with your own)
  static const String posts = '/';

  static Map<String, WidgetBuilder> get routes => {
    posts: (_) => const PostView(),
  };
}
