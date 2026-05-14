import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/profile_controller.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return Center(child: Text('Error: ${controller.errorMessage}'));
    }

    final profile = controller.profile;
    if (profile == null) {
      return const Center(child: Text('No profile found.'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(profile.displayName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(profile.avatarUrl),
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(profile.bio),
          ],
        ),
      ),
    );
  }
}
