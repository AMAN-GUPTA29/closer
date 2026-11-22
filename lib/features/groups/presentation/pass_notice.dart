import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/group_models.dart';

String _photos(int n) => '$n ${n == 1 ? 'photo' : 'photos'}';

/// Warning at the top of a group's journal while its pass ends soon, is in
/// the 30 days after ending, or has ended.
class PassNotice extends StatelessWidget {
  const PassNotice({super.key, required this.group});

  final Group group;

  static bool appliesTo(Group group) =>
      group.passEnded || group.premiumEndsSoon;

  /// Title and message. Photos are only ever said to be "at risk": removal
  /// always needs the Keeploom team's approval (docs/purchases-and-retention.md).
  static (String, String) copy(Group group) {
    final risk = group.photosAtRisk;
    if (group.passEnded) {
      if (risk > 0) {
        return (
          'Your pass ended. Renew to protect your photos.',
          '${_photos(risk)} may be removed, but only after the Keeploom team '
              'approves it. To add photos, renew or delete until fewer than '
              '${Group.basicPhotoLimit} remain.',
        );
      }
      final room = group.roomWithoutPass;
      return (
        'Your pass ended',
        room > 0
            ? 'Your photos are safe. You can add ${_photos(room)} more, or '
                  'renew for no limit.'
            : 'Your photos are safe. To add more, renew or delete one.',
      );
    }
    if (group.premiumLapsed) {
      final deadline = formatDayMonth(group.premiumGraceEnds!);
      return (
        'Your pass ended on ${formatDayMonth(group.premiumExpiresAt!)}',
        risk > 0
            ? '${_photos(risk)} may be removed after $deadline. Renew to '
                  'keep them all. Nothing is removed without approval.'
            : 'Renew by $deadline to keep sharing without a limit.',
      );
    }
    return (
      'Your pass ends on ${formatDayMonth(group.premiumExpiresAt!)}',
      'Renew to keep every photo. You have ${Group.premiumGraceDays} more '
          'days after it ends.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, message) = copy(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeCard(icon: CloserIcons.clock, title: title, message: message),
        const SizedBox(height: CloserSpacing.xxs),
        CloserButton.ghost(
          label: 'Renew pass',
          expand: true,
          onPressed: () => context.push(Routes.upgrade(group.id)),
        ),
      ],
    );
  }
}

/// On the share screen, when a group whose pass ended can't take the photos.
class UploadPausedNotice extends StatelessWidget {
  const UploadPausedNotice({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final room = group.roomWithoutPass;
    return NoticeCard(
      icon: CloserIcons.clock,
      title: 'Renew to share with ${group.name}',
      message: room > 0
          ? 'Its pass ended and it has room for ${_photos(room)}. Choose '
                'fewer photos or renew.'
          : 'Its pass ended and it has ${_photos(group.photoCount)}. Renew, '
                'or delete until fewer than ${Group.basicPhotoLimit} remain.',
    );
  }
}
