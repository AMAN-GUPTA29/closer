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
import '../application/photo_providers.dart';
import '../domain/photo_models.dart';
import 'photo_widgets.dart';

/// Most photos shared in one go.
const maxPhotosPerShare = 10;

/// One picked photo. Each group it goes to gets its own upload id, kept
/// across retries, so a retry can never create a duplicate.
class _Pick {
  _Pick(this.raw);

  final Uint8List raw;
  final _uploadIds = <String, String>{};

  /// Group id -> photo id once shared there.
  final shared = <String, String>{};
  PreparedPhoto? prepared;
  String? error;

  bool get ready => prepared != null;
  String uploadIdFor(String groupId) =>
      _uploadIds.putIfAbsent(groupId, () => const Uuid().v4());
}

/// Share a memory, as on the Keeploom showcase: photos with "Add more",
/// the group, a caption and options, then Share. Opened from the + button
/// (no group chosen yet) or from a group (pre-selected).
class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key, this.groupId, this.source});

  /// Pre-selected group (from a group's Camera / Add buttons).
  final String? groupId;

  /// Opens the picker straight away when set.
  final PhotoSource? source;

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen> {
  final _caption = TextEditingController();
  final _picks = <_Pick>[];

  /// Chosen groups, in the order they were ticked.
  final _groupIds = <String>[];
  DateTime? _takenAt;
  bool _pin = false;
  bool _moment = false;
  bool _sharing = false;
  UploadStage? _stage;
  int _current = 0;
  String? _error;

  bool get _preparing => _picks.any((p) => !p.ready && p.error == null);
  List<_Pick> get _usable => [
    for (final p in _picks)
      if (p.ready) p,
  ];

  @override
  void initState() {
    super.initState();
    final pre = widget.groupId;
    if (pre != null) _groupIds.add(pre);
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

  Future<void> _choose() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
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
              Text('Add a photo', style: sheet.text.headlineSmall),
              const SizedBox(height: CloserSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CloserIcons.gallery),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheet, PhotoSource.gallery),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CloserIcons.camera),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheet, PhotoSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _pick(PhotoSource source) async {
    if (_picks.length >= maxPhotosPerShare) return;
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
    final pick = _Pick(raw);
    setState(() => _picks.add(pick));
    try {
      final prepared = await ref.read(imageProcessorProvider).prepare(raw);
      if (!mounted) return;
      setState(() {
        pick.prepared = prepared;
        _takenAt ??= prepared.takenAt;
      });
    } on AppFailure catch (f) {
      if (mounted) setState(() => pick.error = f.message);
    } catch (_) {
      if (mounted) setState(() => pick.error = 'We couldn’t read that photo.');
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

  Future<void> _share(List<Group> targets) async {
    final photos = _usable;
    if (photos.isEmpty || targets.isEmpty || _sharing) return;
    setState(() {
      _error = null;
      _sharing = true;
    });
    final actions = ref.read(photoActionsProvider);
    final total = photos.length * targets.length;
    var removed = 0;
    try {
      var step = 0;
      for (final group in targets) {
        for (final p in photos) {
          setState(() => _current = step++);
          if (p.shared.containsKey(group.id)) continue; // done before a retry
          final result = await actions.upload(
            groupId: group.id,
            clientUploadId: p.uploadIdFor(group.id),
            photo: p.prepared!,
            caption: _caption.text,
            takenAt: _takenAt,
            onStage: (s) {
              if (mounted) setState(() => _stage = s);
            },
          );
          p.shared[group.id] = result.photoId;
          removed += result.removedCount;
        }
        if (_pin && group.isPremium) {
          for (final p in photos) {
            await actions.setPinnedById(group.id, p.shared[group.id]!, true);
          }
        }
      }
      if (!mounted) return;
      final names = targets.length == 1
          ? targets.single.name
          : targets.length == 2
          ? '${targets[0].name} and ${targets[1].name}'
          : '${targets.length} groups';
      final what = photos.length == 1 ? 'Shared' : 'Shared ${photos.length}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed > 0
                ? '$what with $names. To keep ${Group.basicPhotoLimit}, the '
                      'oldest ${removed == 1 ? 'photo was' : 'photos were'} '
                      'removed from Basic groups.'
                : '$what with $names',
          ),
        ),
      );
      final first = targets.first;
      context.go(targets.length == 1 ? Routes.group(first.id) : Routes.home);
      if (_moment) {
        context.push(
          Routes.newMoment(first.id, photoId: photos.first.shared[first.id]),
        );
      }
      assert(step == total);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The photo couldn’t be shared. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
          _stage = null;
        });
      }
    }
  }

  void _close() {
    if (_sharing) return;
    context.canPop() ? context.pop() : context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(myGroupsProvider);
    return PopScope(
      canPop: !_sharing,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: switch (groups) {
                AsyncData(:final value) => _body(value),
                AsyncError() => ErrorState(
                  message: 'Your groups couldn’t be loaded.',
                  onRetry: () => ref.invalidate(myGroupsProvider),
                ),
                _ => const LoadingState(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<Group> groups) {
    final c = context.closerColors;
    final byId = {for (final g in groups) g.id: g};
    final selected = [
      for (final id in _groupIds)
        if (byId[id] != null) byId[id]!,
    ];
    final anyPremium = selected.any((g) => g.isPremium);
    final usable = _usable;
    final total = usable.length * (selected.isEmpty ? 1 : selected.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CloserSpacing.gutter,
        CloserSpacing.xs,
        CloserSpacing.gutter,
        CloserSpacing.xl,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Close',
              icon: const Icon(CloserIcons.close),
              onPressed: _sharing ? null : _close,
            ),
            const SizedBox(width: CloserSpacing.xxs),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Share a memory', style: context.text.titleLarge),
              ),
            ),
          ],
        ),
        const SizedBox(height: CloserSpacing.xs),
        _PhotoStrip(
          picks: _picks,
          enabled: !_sharing,
          onAdd: _picks.length >= maxPhotosPerShare ? null : _choose,
          onRemove: (p) => setState(() => _picks.remove(p)),
        ),
        for (final p in _picks)
          if (p.error != null) ...[
            const SizedBox(height: CloserSpacing.xs),
            FormErrorText(p.error),
          ],
        const SizedBox(height: CloserSpacing.md),
        CloserTextField(
          controller: _caption,
          hint: 'Add a caption',
          showLabel: false,
          maxLength: 500,
          enabled: !_sharing,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CloserSpacing.lg),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, CloserSpacing.xs),
          child: Semantics(
            header: true,
            child: Text(
              'Share with',
              style: context.text.labelMedium?.copyWith(color: c.textSecondary),
            ),
          ),
        ),
        if (groups.isEmpty) ...[
          const NoticeCard(
            title: 'No groups yet',
            message:
                'Photos are shared into a group. Create or join one first.',
          ),
          const SizedBox(height: CloserSpacing.sm),
          CloserButton.secondary(
            label: 'Create a group',
            onPressed: () => context.push(Routes.createGroup),
          ),
        ] else
          SectionCard(
            dividerIndent: CloserSpacing.md,
            children: [
              for (final g in groups)
                _GroupOption(
                  group: g,
                  selected: _groupIds.contains(g.id),
                  onTap: _sharing
                      ? null
                      : () => setState(() {
                          _groupIds.contains(g.id)
                              ? _groupIds.remove(g.id)
                              : _groupIds.add(g.id);
                          if (!_groupIds.any(
                            (id) => byId[id]?.isPremium ?? false,
                          )) {
                            _pin = false;
                          }
                        }),
                ),
            ],
          ),
        for (final g in selected)
          if (g.nextUploadRemovesOldest) ...[
            const SizedBox(height: CloserSpacing.sm),
            RetentionNotice(group: g),
          ],
        const SizedBox(height: CloserSpacing.sm),
        SectionCard(
          dividerIndent: CloserSpacing.md,
          children: [
            _OptionRow(
              icon: CloserIcons.calendar,
              label: 'Date',
              value: _takenAt == null ? 'Today' : formatMediumDate(_takenAt!),
              onTap: _sharing ? null : _pickDate,
            ),
            _OptionRow(
              icon: CloserIcons.starOutline,
              label: 'Make it a special moment',
              value: !_moment
                  ? null
                  : selected.length > 1
                  ? 'In ${selected.first.name}'
                  : 'New special moment',
              onTap: _sharing ? null : () => setState(() => _moment = !_moment),
            ),
            _OptionRow(
              icon: CloserIcons.journal,
              label: 'Pin to journal',
              hint: selected.isEmpty || selected.every((g) => g.isPremium)
                  ? null
                  : anyPremium
                  ? 'Keeploom Memories groups only'
                  : 'Keeploom Memories',
              trailing: Switch(
                value: _pin,
                onChanged: _sharing || !anyPremium
                    ? null
                    : (v) => setState(() => _pin = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: CloserSpacing.lg),
        FormErrorText(_error),
        if (_sharing && _stage != null) ...[
          Semantics(
            liveRegion: true,
            label: total > 1
                ? 'Sharing ${_current + 1} of $total'
                : _stage!.label,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: CloserRadii.pillAll,
                  child: LinearProgressIndicator(
                    value: (_current + _stage!.progress) / total,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: CloserSpacing.xs),
                Text(
                  total > 1
                      ? '${_current + 1} of $total · ${_stage!.label}'
                      : _stage!.label,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: CloserSpacing.md),
        ],
        CloserButton(
          label: _error != null && usable.isNotEmpty
              ? 'Retry'
              : usable.length <= 1 && selected.length <= 1
              ? 'Share'
              : 'Share ${usable.length} '
                    '${usable.length == 1 ? 'photo' : 'photos'} with '
                    '${selected.length} '
                    '${selected.length == 1 ? 'group' : 'groups'}',
          isLoading: _sharing || _preparing,
          onPressed: usable.isEmpty || selected.isEmpty
              ? null
              : () => _share(selected),
        ),
        if (usable.isEmpty || selected.isEmpty) ...[
          const SizedBox(height: CloserSpacing.xs),
          Text(
            usable.isEmpty
                ? 'Add a photo to share.'
                : 'Choose at least one group.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Picked photos as square tiles (with remove buttons) and an "Add more"
/// tile, two to a row like the board.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.picks,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_Pick> picks;
  final bool enabled;
  final VoidCallback? onAdd;
  final ValueChanged<_Pick> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final w =
        (MediaQuery.sizeOf(context).width -
            CloserSpacing.gutter * 2 -
            CloserSpacing.xs * 2) /
        3;
    final h = w * 1.29;
    final tiles = <Widget>[
      for (final p in picks)
        SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: CloserRadii.lgAll,
                child: Image.memory(
                  p.prepared?.thumbnail ?? p.raw,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'Selected photo',
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: c.surfaceMuted,
                    child: Icon(CloserIcons.gallery, color: c.textTertiary),
                  ),
                ),
              ),
              if (!p.ready && p.error == null)
                const ClipRRect(
                  borderRadius: CloserRadii.lgAll,
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: LoadingState(),
                  ),
                ),
              if (enabled)
                Positioned(
                  top: CloserSpacing.xs,
                  right: CloserSpacing.xs,
                  child: Semantics(
                    button: true,
                    label: 'Remove photo',
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove(p),
                        child: const SizedBox.square(
                          dimension: 32,
                          child: Icon(
                            CloserIcons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (onAdd != null)
        SizedBox(
          width: w,
          height: h,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: CloserRadii.lgAll,
              side: BorderSide(color: c.textTertiary, width: 1.2),
            ),
            child: InkWell(
              borderRadius: CloserRadii.lgAll,
              onTap: enabled ? onAdd : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CloserIcons.gallery, size: 22, color: c.textSecondary),
                  const SizedBox(height: CloserSpacing.xxs),
                  Text(
                    picks.isEmpty ? 'Add photo' : 'Add more',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    return Wrap(
      spacing: CloserSpacing.xs,
      runSpacing: CloserSpacing.xs,
      children: tiles,
    );
  }
}

class _GroupOption extends StatelessWidget {
  const _GroupOption({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final Group group;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final n = group.memberCount;
    return Semantics(
      checked: selected,
      button: true,
      label: '${group.name}, $n ${n == 1 ? 'member' : 'members'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CloserSpacing.md,
            vertical: 9,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: CloserRadii.smAll,
                child: SizedBox.square(
                  dimension: 36,
                  child: GroupCover(group: group),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(fontSize: 15),
                ),
              ),
              AnimatedContainer(
                duration: CloserMotion.of(context, CloserMotion.fast),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? c.primary : c.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, color: c.onPrimary, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    this.value,
    this.hint,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? hint;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: CloserSpacing.md),
      minTileHeight: 52,
      horizontalTitleGap: 14,
      onTap: onTap,
      leading: Icon(icon, color: c.textPrimary, size: 18),
      title: Text(label, style: context.text.bodyLarge?.copyWith(fontSize: 15)),
      subtitle: hint == null
          ? null
          : Text(hint!, style: context.text.bodySmall),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) Text(value!, style: context.text.bodyMedium),
              const SizedBox(width: CloserSpacing.xxs),
              Icon(CloserIcons.chevronRight, color: c.textTertiary, size: 20),
            ],
          ),
    );
  }
}
