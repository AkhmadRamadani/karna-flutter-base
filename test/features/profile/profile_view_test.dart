import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/profile/controller/profile_controller.dart';
import 'package:karna_mvc/features/profile/model/profile_model.dart';
import 'package:karna_mvc/features/profile/repository/profile_repository.dart';
import 'package:karna_mvc/features/profile/view/profile_view.dart';

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<Result<ProfileModel>> getProfileById(String id) async => Success(
    ProfileModel(
      id: '1',
      displayName: 'Alice',
      avatarUrl: 'https://example.com/avatar.png',
      bio: 'Hello world',
    ),
  );

  @override
  Future<Result<ProfileModel>> getProfileFromCache(String id) async => Success(
    ProfileModel(
      id: '1',
      displayName: 'Alice',
      avatarUrl: 'https://example.com/avatar.png',
      bio: 'Hello world',
    ),
  );

  @override
  Future<Result<ProfileModel>> getProfileFromRemote(String id) async => Success(
    ProfileModel(
      id: '1',
      displayName: 'Alice',
      avatarUrl: 'https://example.com/avatar.png',
      bio: 'Hello world',
    ),
  );

  @override
  Future<Result<void>> updateProfile(ProfileModel profile) async =>
      const Success(null);
}

void main() {
  testWidgets('ProfileView displays "No profile found." initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileController>(
        create: (_) => ProfileController(repository: FakeProfileRepository()),
        child: const MaterialApp(home: ProfileView()),
      ),
    );

    expect(find.text('No profile found.'), findsOneWidget);
  });
}
