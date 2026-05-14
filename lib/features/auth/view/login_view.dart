import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/auth_controller.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return Center(child: Text('Error: ${controller.errorMessage}'));
    }

    final user = controller.user;
    if (user == null) {
      return const Center(child: Text('No user found.'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: Column(
        children: [
          Text(user.email),
          ElevatedButton(
            onPressed: () => controller.loadUser(user.id),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
