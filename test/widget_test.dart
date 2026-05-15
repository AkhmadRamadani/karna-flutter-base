import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/di/app_dependencies.dart';
import 'package:karna_mvc/core/storage/in_memory_storage.dart';

import 'package:karna_mvc/main.dart';

void main() {
  testWidgets('KarnaApp renders without crashing', (WidgetTester tester) async {
    final deps = AppDependencies(
      storage: InMemoryStorage(),
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    );

    await tester.pumpWidget(KarnaApp(dependencies: deps));
    await tester.pump();

    // The app should render without crashing — verify the scaffold exists
    expect(find.text('Posts'), findsOneWidget);
  });
}
