import '../../../../core/network/api_client.dart';
import '../auth_repository_impl.dart';

class AuthRemoteSourceImpl implements AuthRemoteSource {
  final ApiClient _client;

  AuthRemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchUser(String id) async {
    final json = await _client.get('/users/$id');
    return json as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final json = await _client.get('/users');
    return (json as List).map((e) => e as Map<String, dynamic>).toList();
  }
}
