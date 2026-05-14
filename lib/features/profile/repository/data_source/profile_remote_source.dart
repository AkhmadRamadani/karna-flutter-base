import '../../../../core/network/api_client.dart';
import '../profile_repository_impl.dart';

class ProfileRemoteSourceImpl implements ProfileRemoteSource {
  final ApiClient _client;

  ProfileRemoteSourceImpl({required ApiClient client}) : _client = client;

  @override
  Future<Map<String, dynamic>> fetchProfile(String id) async {
    final json = await _client.get('/profiles/$id');
    return json as Map<String, dynamic>;
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final id = data['id'] as String;
    await _client.put('/profiles/$id', body: data);
  }
}
