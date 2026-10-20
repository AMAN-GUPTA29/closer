import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/application/content_providers.dart';

/// Avatar for the signed-in user: their photo when set, else initials.
class MyAvatar extends ConsumerWidget {
  const MyAvatar({
    super.key,
    required this.fallbackName,
    this.size = 44,
    this.brand = false,
    this.serif = false,
  });

  final String fallbackName;
  final double size;

  /// Blush circle with a coral initial (Profile header), as on the board.
  final bool brand;

  /// Serif initials, as on the large profile avatars.
  final bool serif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final path = profile?.avatarPath;
    final image = path == null
        ? null
        : ref.watch(avatarImageProvider(path)).value;
    return MemberAvatar(
      name: profile?.displayName ?? fallbackName,
      image: image,
      size: size,
      serif: serif,
      colors: brand
          ? (context.closerColors.accentSoft, context.closerColors.accentStrong)
          : null,
    );
  }
}
