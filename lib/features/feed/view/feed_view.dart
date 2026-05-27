import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/feed_controller.dart';
import '../model/feed_model.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  @override
  void initState() {
    super.initState();
    // Load feed on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedController>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeedController>();

    if (controller.isLoading && controller.feedList.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (controller.hasError && controller.feedList.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${controller.errorMessage}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.loadAll(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          if (controller.isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Keep the controller alive while user is scrolling
          controller.onUserScroll();
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () => controller.loadAll(),
          child: controller.feedList.isEmpty
              ? const Center(child: Text('No feed items yet'))
              : ListView.builder(
                  itemCount: controller.feedList.length,
                  itemBuilder: (context, index) {
                    return _FeedCard(item: controller.feedList[index]);
                  },
                ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedModel item;

  const _FeedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(item.authorName[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _formatDate(item.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.content),
            if (item.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (_, e, s) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 20),
                const SizedBox(width: 4),
                Text('${item.likeCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
