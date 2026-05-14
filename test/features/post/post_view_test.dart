import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karna_mvc/core/errors/app_exception.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/post/controller/post_controller.dart';
import 'package:karna_mvc/features/post/model/post_model.dart';
import 'package:karna_mvc/features/post/repository/post_repository.dart';
import 'package:karna_mvc/features/post/view/post_view.dart';

class FakePostRepository implements PostRepository {
  @override
  Future<Result<PostModel>> getPostById(String id) async => Success(
    PostModel(
      id: '1',
      title: 'Test Post',
      body: 'Test body',
      authorId: 'author_1',
    ),
  );

  @override
  Future<Result<List<PostModel>>> getAllPosts() async => const Success([]);

  @override
  Future<Result<PostModel>> getPostFromCache(String id) async => Success(
    PostModel(
      id: '1',
      title: 'Test Post',
      body: 'Test body',
      authorId: 'author_1',
    ),
  );

  @override
  Future<Result<PostModel>> getPostFromRemote(String id) async => Success(
    PostModel(
      id: '1',
      title: 'Test Post',
      body: 'Test body',
      authorId: 'author_1',
    ),
  );

  @override
  Future<Result<List<PostModel>>> getPostsFromCache() async =>
      Failure(CacheException(message: 'miss', code: 'CACHE_MISS'));

  @override
  Future<Result<List<PostModel>>> getPostsFromRemote() async =>
      const Success([]);
}

void main() {
  testWidgets('PostView displays "No posts yet." when list is empty', (
    tester,
  ) async {
    final eventBus = EventBusImpl();
    await tester.pumpWidget(
      ChangeNotifierProvider<PostController>(
        create: (_) => PostController(
          repository: FakePostRepository(),
          eventBus: eventBus,
        ),
        child: const MaterialApp(home: PostView()),
      ),
    );

    // Let initState's addPostFrameCallback fire
    await tester.pumpAndSettle();

    expect(find.text('No posts yet.'), findsOneWidget);
    eventBus.dispose();
  });
}
