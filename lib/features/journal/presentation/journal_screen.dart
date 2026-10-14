import 'package:flutter/material.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/widgets/widgets.dart';

/// Cross-group journal tab. Populated once groups and photos exist.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: const EmptyState(
        icon: CloserIcons.journal,
        title: 'No memories yet',
        message:
            'Photos and milestones from all your groups will appear here, '
            'newest first.',
      ),
    );
  }
}
