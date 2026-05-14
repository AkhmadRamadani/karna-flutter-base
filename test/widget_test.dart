import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/storage/in_memory_storage.dart';

import 'package:karna_mvc/main.dart';

void main() {
  testWidgets('KarnaApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(KarnaApp(storage: InMemoryStorage()));
    // Pump once to trigger the initial frame (PostView shows loading first)
    await tester.pump();

    // The app should render without crashing — verify the scaffold exists
    expect(find.text('Posts'), findsOneWidget);
  });
}
