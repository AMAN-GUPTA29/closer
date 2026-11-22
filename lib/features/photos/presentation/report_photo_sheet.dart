import 'package:flutter/material.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/photo_models.dart';

/// Asks why a photo is being reported. Returns null when dismissed.
Future<ReportReason?> showReportPhotoSheet(
  BuildContext context, {
  required String? uploaderName,
}) => showModalBottomSheet<ReportReason>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ReportPhotoSheet(uploaderName: uploaderName),
);

class _ReportPhotoSheet extends StatefulWidget {
  const _ReportPhotoSheet({required this.uploaderName});

  final String? uploaderName;

  @override
  State<_ReportPhotoSheet> createState() => _ReportPhotoSheetState();
}

class _ReportPhotoSheetState extends State<_ReportPhotoSheet> {
  ReportReason? _reason;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final who = widget.uploaderName ?? 'The person who shared it';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.gutter,
          0,
          CloserSpacing.gutter,
          CloserSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Report this photo',
                style: context.text.headlineSmall,
              ),
            ),
            const SizedBox(height: CloserSpacing.xs),
            Text(
              'It will be hidden for you and sent to the Keeploom team to '
              'review. $who won’t be told who reported it.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: CloserSpacing.sm),
            for (final r in ReportReason.values)
              Semantics(
                selected: _reason == r,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 52,
                  title: Text(
                    r.label,
                    style: context.text.bodyLarge?.copyWith(fontSize: 15),
                  ),
                  trailing: _reason == r
                      ? Icon(CloserIcons.success, color: c.primary, size: 22)
                      : Icon(
                          CloserIcons.unselected,
                          color: c.textTertiary,
                          size: 22,
                        ),
                  onTap: () => setState(() => _reason = r),
                ),
              ),
            const SizedBox(height: CloserSpacing.md),
            CloserButton(
              label: 'Send report',
              onPressed: _reason == null
                  ? null
                  : () => Navigator.of(context).pop(_reason),
            ),
          ],
        ),
      ),
    );
  }
}
