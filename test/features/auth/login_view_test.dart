import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:karna_mvc/core/events/event_bus.dart';
import 'package:karna_mvc/core/result/result.dart';
import 'package:karna_mvc/features/auth/controller/auth_controller.dart';
import 'package:karna_mvc/features/auth/model/user_model.dart';
import 'package:karna_mvc/features/auth/repository/auth_repository.dart';
import 'package:karna_mvc/features/auth/view/login_view.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<UserModel>> getUserById(String id) async =>
      Success(UserModel(id: '1', name: 'Alice', email: 'alice@test.com'));

  @override
  Future<Result<List<UserModel>>> getAllUsers() async => const Success([]);

  @override
  Future<Result<UserModel>> getUserFromCache(String id) async =>
      Success(UserModel(id: '1', name: 'Alice', email: 'alice@test.com'));

  @override
  Future<Result<UserModel>> getUserFromRemote(String id) async =>
      Success(UserModel(id: '1', name: 'Alice', email: 'alice@test.com'));
}

void main() {
  testWidgets('LoginView displays "No user found." initially', (tester) async {
    final eventBus = EventBusImpl();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(
          repository: FakeAuthRepository(),
          eventBus: eventBus,
        ),
        child: const MaterialApp(home: LoginView()),
      ),
    );

    expect(find.text('No user found.'), findsOneWidget);
    eventBus.dispose();
  });
}
