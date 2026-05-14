import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/data_strategy.dart';
import '../../../core/widgets/error_display.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../controller/post_controller.dart';

/// Example view demonstrating:
/// - Reading state from the controller (isLoading, isRefreshing, hasError, data)
/// - Calling controller methods (loadPosts with different strategies)
/// - Using shared core widgets (LoadingIndicator, ErrorDisplay)
/// - Zero business logic in the view
class PostView extends StatefulWidget {
  const PostView({super.key});

  @override
  State<PostView> createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  @override
  void initState() {
    super.initState();
    // Load posts on first build using stale-while-revalidate:
    // shows cached data instantly, refreshes in background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostController>().loadPosts(
        strategy: DataStrategy.staleWhileRevalidate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        actions: [
          // Show a subtle refresh indicator when background-refreshing
          if (controller.isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(controller),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            controller.loadPosts(strategy: DataStrategy.remoteFirst),
        tooltip: 'Force refresh from network',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody(PostController controller) {
    if (controller.isLoading) {
      return const LoadingIndicator(message: 'Loading posts...');
    }

    if (controller.hasError) {
      return ErrorDisplay(
        message: controller.errorMessage ?? 'Something went wrong',
        onRetry: () => controller.loadPosts(strategy: DataStrategy.remoteFirst),
      );
    }

    final posts = controller.posts;
    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet.'));
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadPosts(strategy: DataStrategy.remoteFirst),
      child: ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return ListTile(
            title: Text(post.title),
            subtitle: Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => controller.loadPost(post.id),
          );
        },
      ),
    );
  }
}
