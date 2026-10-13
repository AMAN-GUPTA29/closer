import 'package:flutter/material.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/widgets/widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const EmptyState(
        icon: CloserIcons.notifications,
        title: 'You are all caught up',
        message:
            'New photos, members and milestones from your groups will '
            'show up here.',
      ),
    );
  }
}
