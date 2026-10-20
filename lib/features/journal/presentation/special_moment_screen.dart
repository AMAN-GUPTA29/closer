import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_widgets.dart' show FormErrorText;
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../../photos/application/photo_providers.dart';
import '../../photos/domain/photo_models.dart';
import '../../photos/presentation/photo_widgets.dart';
import '../application/content_providers.dart';
import '../domain/journal_models.dart';
import 'milestone_views.dart';

/// Create or edit a special moment (milestone).
class SpecialMomentScreen extends ConsumerWidget {
  const SpecialMomentScreen({
    super.key,
    required this.groupId,
    this.milestoneId,
    this.coverPhotoId,
  });

  final String groupId;

  /// Editing when set.
  final String? milestoneId;

  /// Pre-selected cover (e.g. from "Mark as special moment" after an upload).
  final String? coverPhotoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    final milestones = milestoneId == null
        ? const AsyncData<List<Milestone>>([])
        : ref.watch(milestonesProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: Text(milestoneId == null ? 'New special moment' : 'Edit moment'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.group(groupId)),
        ),
      ),
      body: SafeArea(
        child: AsyncBody(
          value: group,
          onRetry: () => ref.invalidate(groupProvider(groupId)),
          builder: (g) => AsyncBody(
            value: milestones,
            onRetry: () => ref.invalidate(milestonesProvider(groupId)),
            builder: (list) {
              final existing = milestoneId == null
                  ? null
                  : list.where((m) => m.id == milestoneId).firstOrNull;
              if (milestoneId != null && existing == null) {
                return const ErrorState(
                  title: 'Not available',
                  message: 'This moment was deleted.',
                );
              }
              return _MomentForm(
                group: g,
                existing: existing,
                initialCover: coverPhotoId,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MomentForm extends ConsumerStatefulWidget {
  const _MomentForm({
    required this.group,
    required this.existing,
    this.initialCover,
  });

  final Group group;
  final Milestone? existing;
  final String? initialCover;

  @override
  ConsumerState<_MomentForm> createState() => _MomentFormState();
}

class _MomentFormState extends ConsumerState<_MomentForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late MilestoneType _type = widget.existing?.type ?? MilestoneType.custom;
  late MilestoneTheme _theme =
      widget.existing?.theme ??
      (widget.group.type == GroupType.couple
          ? MilestoneTheme.heart
          : MilestoneTheme.celebration);
  late DateTime _date = widget.existing?.eventDate ?? _today();
  late String? _cover = widget.existing?.coverPhotoId ?? widget.initialCover;
  late bool _pinned = widget.existing?.isPinned ?? false;
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _applyTemplate(MilestoneTemplate t) {
    setState(() {
      _type = t.type;
      _theme = t.theme;
      if (t.title.isNotEmpty) _title.text = t.title;
      final start = widget.group.relationshipStartDate;
      if (t.type == MilestoneType.daysTogether && start != null) {
        // 100th day (day 1 = start date).
        _date = DateTime(start.year, start.month, start.day + 99);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(_today().year + 10),
      helpText: 'Date of this moment',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCover() async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => PhotoChooserSheet(group: widget.group, allowNone: true),
    );
    if (chosen == null) return;
    setState(() => _cover = chosen.isEmpty ? null : chosen);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final draft = MilestoneDraft(
      title: _title.text,
      type: _type,
      eventDate: _date,
      theme: _theme,
      description: _description.text,
      coverPhotoId: _cover,
      isPinned: _pinned,
    );
    try {
      final actions = ref.read(milestoneActionsProvider);
      if (widget.existing == null) {
        await actions.create(widget.group.id, draft);
      } else {
        await actions.update(widget.existing!, draft);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Moment saved')));
      context.pop();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final templates = MilestoneTemplate.forGroup(widget.group.type);
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(CloserSpacing.gutter),
        children: [
          if (widget.existing == null) ...[
            const _Label('Start from'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in templates)
                  _Choice(
                    label: t.label,
                    selected:
                        _type == t.type &&
                        (t.title.isEmpty || _title.text == t.title),
                    onSelected: () => _applyTemplate(t),
                  ),
              ],
            ),
            const SizedBox(height: CloserSpacing.lg),
          ],
          CloserTextField(
            controller: _title,
            hint: 'Title',
            placeholder: 'e.g. Our first trip',
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v?.trim() ?? '').isEmpty ? 'Give this moment a title.' : null,
          ),
          const SizedBox(height: CloserSpacing.sm),
          const _Label('Date', top: 0),
          Semantics(
            button: true,
            label: 'Date, ${formatLongDate(_date)}',
            excludeSemantics: true,
            child: Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: CloserRadii.mdAll,
                side: BorderSide(color: c.line),
              ),
              child: InkWell(
                borderRadius: CloserRadii.mdAll,
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CloserIcons.calendar,
                        color: c.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: CloserSpacing.sm),
                      Text(
                        formatLongDate(_date),
                        style: context.text.bodyLarge?.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_date.isAfter(_today()))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                'Upcoming — it will count down until then',
                style: context.text.bodySmall,
              ),
            ),
          const SizedBox(height: CloserSpacing.md),
          CloserTextField(
            controller: _description,
            hint: 'A few words (optional)',
            placeholder: 'What made it special?',
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: CloserSpacing.sm),
          const _Label('Cover photo (optional)', top: 0),
          _CoverPicker(
            group: widget.group,
            photoId: _cover,
            onChoose: (id) => setState(() => _cover = id),
            onMore: _pickCover,
          ),
          const _Label('Style'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in MilestoneTheme.values)
                if (t != MilestoneTheme.heart ||
                    widget.group.type == GroupType.couple ||
                    _theme == MilestoneTheme.heart)
                  _Choice(
                    label: t.label,
                    selected: _theme == t,
                    onSelected: () => setState(() => _theme = t),
                  ),
            ],
          ),
          const SizedBox(height: CloserSpacing.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
            title: Text(
              'Pin to the top of the journal',
              style: context.text.bodyLarge?.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(height: CloserSpacing.lg),
          FormErrorText(_error),
          CloserButton(
            label: 'Save moment',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// The group's newest photos as tappable covers (the chosen one outlined),
/// with "More photos" for the rest.
class _CoverPicker extends ConsumerWidget {
  const _CoverPicker({
    required this.group,
    required this.photoId,
    required this.onChoose,
    required this.onMore,
  });

  final Group group;
  final String? photoId;
  final ValueChanged<String?> onChoose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.closerColors;
    final photos =
        ref.watch(groupPhotosProvider(group.id)).value?.photos ??
        const <Photo>[];
    if (photos.isEmpty) {
      return Semantics(
        button: true,
        label: 'Choose a cover photo',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: CloserRadii.lgAll,
          onTap: onMore,
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: CloserRadii.lgAll,
              border: Border.all(color: c.line),
            ),
            child: Center(
              child: Text(
                'Share a photo in this group to use it as a cover',
                style: context.text.bodySmall,
              ),
            ),
          ),
        ),
      );
    }
    final chosen = photos.where((p) => p.id == photoId).firstOrNull;
    final shown = [
      ?chosen,
      ...photos.where((p) => p.id != photoId),
    ].take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1 / 1.03,
                  child: i >= shown.length
                      ? const SizedBox.shrink()
                      : Semantics(
                          button: true,
                          selected: shown[i].id == photoId,
                          label: shown[i].id == photoId
                              ? 'Cover photo, chosen'
                              : 'Use as cover photo',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => onChoose(
                              shown[i].id == photoId ? null : shown[i].id,
                            ),
                            child: AnimatedContainer(
                              duration: CloserMotion.of(
                                context,
                                CloserMotion.fast,
                              ),
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: CloserRadii.mdAll,
                                border: Border.all(
                                  color: shown[i].id == photoId
                                      ? c.textPrimary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: CloserRadii.smAll,
                                child: PhotoImage(photo: shown[i]),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
        if (photos.length > 3)
          Semantics(
            label: 'Choose a cover photo',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              onPressed: onMore,
              child: const Text('More photos'),
            ),
          ),
      ],
    );
  }
}

/// Lets the user pick one of the group's photos. Pops with the photo id, an
/// empty string for "no photo" (when [allowNone]), or null when dismissed.
class PhotoChooserSheet extends ConsumerWidget {
  const PhotoChooserSheet({
    super.key,
    required this.group,
    this.allowNone = false,
    this.noneLabel = 'No photo',
  });

  final Group group;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(groupPhotosProvider(group.id));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CloserSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose a photo', style: context.text.headlineSmall),
              const SizedBox(height: CloserSpacing.sm),
              if (allowNone)
                CloserButton.ghost(
                  label: noneLabel,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(''),
                ),
              Expanded(
                child: AsyncBody(
                  value: feed,
                  onRetry: () => ref.invalidate(groupPhotosProvider(group.id)),
                  builder: (data) => data.photos.isEmpty
                      ? const EmptyState(
                          icon: CloserIcons.gallery,
                          title: 'No photos yet',
                          message: 'Share a photo in this group first.',
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: CloserSpacing.xs,
                                crossAxisSpacing: CloserSpacing.xs,
                              ),
                          itemCount: data.photos.length,
                          itemBuilder: (context, i) {
                            final Photo p = data.photos[i];
                            return Semantics(
                              button: true,
                              label: 'Choose ${p.caption ?? 'photo ${i + 1}'}',
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(p.id),
                                child: ClipRRect(
                                  borderRadius: CloserRadii.mdAll,
                                  child: PhotoImage(photo: p),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Readable choice chip: dark text on white, dark rose on blush when selected.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final fg = selected ? c.onPrimary : c.textPrimary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: c.background,
      selectedColor: c.primary,
      side: BorderSide(color: selected ? c.primary : c.line),
      labelStyle: context.text.labelLarge?.copyWith(color: fg, fontSize: 14),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Small muted label above a field or a group of choices.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = CloserSpacing.md});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: context.text.titleSmall?.copyWith(fontSize: 13.5),
      ),
    ),
  );
}
