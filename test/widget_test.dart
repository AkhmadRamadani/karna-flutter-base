import 'package:flutter_test/flutter_test.dart';
import 'package:karna_mvc/core/storage/in_memory_storage.dart';

import 'package:karna_mvc/main.dart';

void main() {
  testWidgets('KarnaApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(KarnaApp(storage: InMemoryStorage()));
    await tester.pumpAndSettle();

    expect(find.text('No user found.'), findsOneWidget);
  });
}
