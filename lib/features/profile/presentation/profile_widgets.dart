import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../../journal/application/content_providers.dart';

/// Avatar for the signed-in user: their photo when set, else initials.
class MyAvatar extends ConsumerWidget {
  const MyAvatar({super.key, required this.fallbackName, this.size = 44});

  final String fallbackName;
  final double size;

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
    );
  }
}
