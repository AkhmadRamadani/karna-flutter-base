import '../../../../core/network/api_client.dart';
import '../feed_repository_impl.dart';

/// Feed remote source — uses ApiClient to fetch feeds from the API.
class FeedRemoteSourceImpl implements FeedRemoteSource {
  final ApiClient _client;

  FeedRemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchById(String id) async {
    final json = await _client.get('/feeds/$id');
    return json as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final json = await _client.get('/feeds');
    return (json as List).map((e) => e as Map<String, dynamic>).toList();
  }
}
