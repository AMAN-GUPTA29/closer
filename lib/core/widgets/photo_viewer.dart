import 'package:flutter/material.dart';

import '../theme/closer_icons.dart';
import '../theme/closer_theme.dart';
import 'closer_photo.dart';

class PhotoViewerItem {
  const PhotoViewerItem({
    this.image,
    this.caption,
    this.subtitle,
    this.heroTag,
    this.placeholderVariant = 0,
  });

  /// Full-size image; `null` shows the painted placeholder.
  final ImageProvider? image;
  final String? caption;
  final String? subtitle;
  final Object? heroTag;
  final int placeholderVariant;
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.items, this.initialIndex = 0})
    : assert(items.length > 0);

  final List<PhotoViewerItem> items;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required List<PhotoViewerItem> items,
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: CloserMotion.of(context, CloserMotion.medium),
        reverseTransitionDuration: CloserMotion.of(
          context,
          CloserMotion.medium,
        ),
        pageBuilder: (_, _, _) =>
            PhotoViewer(items: items, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chromeVisible = true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    final textTheme = context.text;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final it = widget.items[i];
                Widget photo = CloserPhoto(
                  image: it.image,
                  placeholderVariant: it.placeholderVariant,
                  fit: BoxFit.contain,
                  semanticLabel: it.caption ?? 'Photo ${i + 1}',
                );
                if (it.heroTag != null) {
                  photo = Hero(tag: it.heroTag!, child: photo);
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: photo),
                );
              },
            ),
          ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: CloserMotion.of(context, CloserMotion.fast),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(CloserSpacing.xs),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Close photo',
                            color: Colors.white,
                            icon: const Icon(CloserIcons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          if (widget.items.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: CloserSpacing.md,
                              ),
                              child: Text(
                                '${_index + 1} / ${widget.items.length}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (item.caption != null || item.subtitle != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(CloserSpacing.gutter),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.caption != null)
                              Text(
                                item.caption!,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            if (item.subtitle != null)
                              Text(
                                item.subtitle!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
