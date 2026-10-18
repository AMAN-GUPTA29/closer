import 'package:flutter/material.dart';

import '../theme/closer_theme.dart';

/// A circular avatar showing a photo, or initials on a tint derived from the
/// member's name when there is no photo.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.image,
    this.size = 40,
    this.ringColor,
  });

  final String name;
  final ImageProvider? image;
  final double size;

  /// Optional ring (e.g. white ring when overlapping in a stack).
  final Color? ringColor;

  static const _tints = [
    Color(0xFFF36B7F),
    Color(0xFF8C6BC8),
    Color(0xFF5B8DEF),
    Color(0xFF4FA37A),
    Color(0xFFF5A04A),
    Color(0xFFC94F8A),
  ];

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  static Color tintFor(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _tints[hash % _tints.length];
  }

  @override
  Widget build(BuildContext context) {
    final ring = ringColor;
    final tint = tintFor(name);
    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: tint.withValues(alpha: 0.18),
      foregroundImage: image,
      child: Text(
        initialsOf(name),
        style: context.text.titleSmall?.copyWith(
          color: tint,
          fontSize: size * 0.36,
        ),
      ),
    );
    if (ring != null) {
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
        child: avatar,
      );
    }
    return Semantics(label: name, image: true, child: avatar);
  }
}

/// Overlapping avatars, e.g. on the group header. Shows "+N" past [max].
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.images = const {},
    this.size = 36,
    this.max = 6,
    this.showOverflow = true,
  });

  final List<String> names;
  final Map<String, ImageProvider> images;
  final double size;
  final int max;

  /// Shows a "+N" bubble after [max] faces; off where a count sits next
  /// to the stack anyway.
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final shown = names.take(max).toList();
    final extra = showOverflow ? names.length - shown.length : 0;
    final step = size * (shown.length > 3 ? 0.58 : 0.68);
    final count = shown.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: '${names.length} members',
      excludeSemantics: true,
      child: SizedBox(
        height: size + 4,
        width: count == 0 ? 0 : step * (count - 1) + size + 4,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * step,
                child: MemberAvatar(
                  name: shown[i],
                  image: images[shown[i]],
                  size: size,
                  ringColor: c.surface,
                ),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * step,
                child: Container(
                  width: size + 4,
                  height: size + 4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Text(
                    '+$extra',
                    style: context.text.labelMedium?.copyWith(
                      color: c.accentStrong,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
