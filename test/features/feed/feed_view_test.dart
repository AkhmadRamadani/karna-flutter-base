import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/memory/memory_manager.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/feed/controller/feed_controller.dart';
import 'package:karna_mvc/features/feed/model/feed_model.dart';
import 'package:karna_mvc/features/feed/repository/feed_repository.dart';
import 'package:karna_mvc/features/feed/view/feed_view.dart';

class FakeFeedRepository implements FeedRepository {
  @override
  Future<Result<FeedModel>> getById(String id) async => Success(
    FeedModel(
      id: '1',
      authorName: 'Test',
      content: 'Hello',
      createdAt: DateTime(2025, 1, 1),
    ),
  );

  @override
  Future<Result<List<FeedModel>>> getAll() async => const Success([]);

  @override
  Future<Result<FeedModel>> getFromCache(String id) async => Success(
    FeedModel(
      id: '1',
      authorName: 'Test',
      content: 'Hello',
      createdAt: DateTime(2025, 1, 1),
    ),
  );

  @override
  Future<Result<FeedModel>> getFromRemote(String id) async => Success(
    FeedModel(
      id: '1',
      authorName: 'Test',
      content: 'Hello',
      createdAt: DateTime(2025, 1, 1),
    ),
  );
}

void main() {
  testWidgets('FeedView renders without crashing', (tester) async {
    final memoryManager = MemoryManager(eventBus: EventBusImpl());

    await tester.pumpWidget(
      ChangeNotifierProvider<FeedController>(
        create: (_) => FeedController(
          memoryManager: memoryManager,
          repository: FakeFeedRepository(),
        ),
        child: const MaterialApp(home: FeedView()),
      ),
    );

    // After initial load with empty list
    await tester.pumpAndSettle();

    expect(find.text('No feed items yet'), findsOneWidget);

    memoryManager.dispose();
  });
}
