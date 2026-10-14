import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_widgets.dart' show FormErrorText;
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../application/photo_providers.dart';
import '../domain/photo_models.dart';
import 'photo_widgets.dart';

/// Share a memory: pick → preview with caption/date → upload with progress
/// and retry. A retry reuses the same upload id, so it can never create a
/// duplicate photo.
class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key, required this.groupId, this.source});

  final String groupId;

  /// Opens the picker straight away when set.
  final PhotoSource? source;

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _caption = TextEditingController();
  Uint8List? _raw;
  PreparedPhoto? _prepared;
  DateTime? _takenAt;
  bool _preparing = false;
  UploadStage? _stage;
  String? _error;

  /// One id per chosen photo: retries reuse it (duplicate protection).
  String _uploadId = const Uuid().v4();

  bool get _uploading => _stage != null && _stage != UploadStage.done;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    if (source != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(source));
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() => _error = null);
    Uint8List? raw;
    try {
      raw = await ref.read(photoPickerProvider)(source);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = source == PhotoSource.camera
              ? 'The camera isn’t available. Check camera permission in Settings.'
              : 'Your photos aren’t available. Check photo permission in Settings.',
        );
      }
      return;
    }
    if (raw == null || !mounted) return;
    setState(() {
      _raw = raw;
      _prepared = null;
      _preparing = true;
      _stage = null;
      _uploadId = const Uuid().v4();
    });
    try {
      final prepared = await ref.read(imageProcessorProvider).prepare(raw);
      if (!mounted) return;
      setState(() {
        _prepared = prepared;
        _takenAt ??= prepared.takenAt;
      });
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t read that photo.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When was this taken?',
    );
    if (picked != null) setState(() => _takenAt = picked);
  }

  Future<void> _share(Group group) async {
    final prepared = _prepared;
    if (prepared == null || _uploading) return;
    setState(() {
      _error = null;
      _stage = UploadStage.preparing;
    });
    try {
      final result = await ref
          .read(photoActionsProvider)
          .upload(
            groupId: group.id,
            clientUploadId: _uploadId,
            photo: prepared,
            caption: _caption.text,
            takenAt: _takenAt,
            onStage: (s) {
              if (mounted) setState(() => _stage = s);
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.removedCount > 0
                ? 'Shared with ${group.name}. The oldest photo was removed to '
                      'keep ${Group.basicPhotoLimit}.'
                : 'Shared with ${group.name}',
          ),
        ),
      );
      context.go(Routes.group(group.id));
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() {
          _stage = null;
          _error = f.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = null;
          _error = 'The photo couldn’t be shared. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Share a Memory'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(CloserIcons.back),
            onPressed: _uploading
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.group(widget.groupId)),
          ),
        ),
        body: SafeArea(
          child: AsyncBody(
            value: group,
            onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
            builder: _body,
          ),
        ),
      ),
    );
  }

  Widget _body(Group group) {
    final c = context.closerColors;
    final raw = _raw;
    if (raw == null) {
      return ListView(
        padding: const EdgeInsets.all(CloserSpacing.gutter),
        children: [
          Text(
            'Share a photo with ${group.name}',
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: CloserSpacing.xs),
          Text(
            'Only members of this group can see it.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: CloserSpacing.xl),
          if (group.nextUploadRemovesOldest) ...[
            RetentionNotice(group: group),
            const SizedBox(height: CloserSpacing.lg),
          ],
          FormErrorText(_error),
          CloserButton(
            label: 'Choose from gallery',
            icon: const Icon(CloserIcons.gallery),
            onPressed: () => _pick(PhotoSource.gallery),
          ),
          const SizedBox(height: CloserSpacing.sm),
          CloserButton.secondary(
            label: 'Take a photo',
            icon: const Icon(CloserIcons.camera),
            onPressed: () => _pick(PhotoSource.camera),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(CloserSpacing.gutter),
      children: [
        ClipRRect(
          borderRadius: CloserRadii.xlAll,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  _prepared?.thumbnail ?? raw,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'Selected photo',
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: c.surfaceMuted,
                    child: Icon(CloserIcons.gallery, color: c.textTertiary),
                  ),
                ),
                if (_preparing)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: LoadingState(),
                  ),
                if (!_uploading)
                  Positioned(
                    top: CloserSpacing.sm,
                    right: CloserSpacing.sm,
                    child: Material(
                      color: Colors.black45,
                      shape: const StadiumBorder(),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _pick(PhotoSource.gallery),
                        icon: const Icon(CloserIcons.edit, size: 18),
                        label: const Text('Change'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        Text('Add a caption (optional)', style: context.text.titleMedium),
        const SizedBox(height: CloserSpacing.sm),
        CloserTextField(
          controller: _caption,
          hint: 'e.g. Beautiful sunset together',
          maxLength: 500,
          enabled: !_uploading,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CloserSpacing.md),
        Text('Date (optional)', style: context.text.titleMedium),
        const SizedBox(height: CloserSpacing.sm),
        Material(
          color: c.surface,
          borderRadius: CloserRadii.mdAll,
          child: ListTile(
            enabled: !_uploading,
            shape: RoundedRectangleBorder(
              borderRadius: CloserRadii.mdAll,
              side: BorderSide(color: c.line),
            ),
            leading: Icon(CloserIcons.calendar, color: c.textTertiary),
            title: Text(
              _takenAt == null
                  ? 'When was this taken?'
                  : formatMediumDate(_takenAt!),
              style: context.text.bodyLarge,
            ),
            trailing: _takenAt == null
                ? null
                : IconButton(
                    tooltip: 'Clear date',
                    icon: const Icon(CloserIcons.close, size: 20),
                    onPressed: () => setState(() => _takenAt = null),
                  ),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        if (group.nextUploadRemovesOldest) ...[
          RetentionNotice(group: group),
          const SizedBox(height: CloserSpacing.lg),
        ],
        FormErrorText(_error),
        if (_stage != null) ...[
          Semantics(
            liveRegion: true,
            label:
                '${_stage!.label}, ${(_stage!.progress * 100).round()} percent',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: CloserRadii.pillAll,
                  child: LinearProgressIndicator(
                    value: _stage!.progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: CloserSpacing.xs),
                Text(_stage!.label, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: CloserSpacing.md),
        ],
        CloserButton(
          label: _error != null && _prepared != null ? 'Retry' : 'Share Photo',
          icon: Icon(_error != null ? CloserIcons.retry : CloserIcons.share),
          isLoading: _uploading || _preparing,
          onPressed: _prepared == null ? null : () => _share(group),
        ),
      ],
    );
  }
}
