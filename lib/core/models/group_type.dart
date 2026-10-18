import 'package:flutter/widgets.dart';

import '../theme/closer_colors.dart';
import '../theme/closer_icons.dart';

/// The three kinds of Keeploom group. Stored as the lowercase [name] in the
/// database (`couple`, `friends`, `family`).
enum GroupType {
  couple(label: 'Couple', blurb: 'Only 2 people can join', maxMembers: 2),
  family(label: 'Family', blurb: 'For your family members', maxMembers: null),
  friends(label: 'Friends', blurb: 'For close friends', maxMembers: null);

  const GroupType({
    required this.label,
    required this.blurb,
    required this.maxMembers,
  });

  final String label;
  final String blurb;

  /// `null` means no fixed cap.
  final int? maxMembers;

  IconData get icon => switch (this) {
    GroupType.couple => CloserIcons.heart,
    GroupType.family => CloserIcons.family,
    GroupType.friends => CloserIcons.friends,
  };

  Color tint(CloserColors colors) => switch (this) {
    GroupType.couple => colors.coupleTint,
    GroupType.family => colors.familyTint,
    GroupType.friends => colors.friendsTint,
  };

  static GroupType parse(String value) => GroupType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => throw FormatException('Unknown group type: $value'),
  );
}
