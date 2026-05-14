import '../../../../core/network/api_client.dart';
import '../post_repository_impl.dart';

/// Remote source — uses ApiClient to fetch posts from the API.
class PostRemoteSourceImpl implements PostRemoteSource {
  final ApiClient _client;

  PostRemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchPost(String id) async {
    final json = await _client.get('/posts/$id');
    return json as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllPosts() async {
    final json = await _client.get('/posts');
    return (json as List).map((e) => e as Map<String, dynamic>).toList();
  }
}
