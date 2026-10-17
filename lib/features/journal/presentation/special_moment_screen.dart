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
        title: Text(
          milestoneId == null ? 'Create a Special Moment' : 'Edit Moment',
        ),
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
            Text('Start from', style: context.text.titleMedium),
            const SizedBox(height: CloserSpacing.sm),
            Wrap(
              spacing: CloserSpacing.xs,
              runSpacing: CloserSpacing.xs,
              children: [
                for (final t in templates)
                  ChoiceChip(
                    label: Text(t.label),
                    avatar: Icon(t.theme.icon, size: 18),
                    selected:
                        _type == t.type &&
                        (t.title.isEmpty || _title.text == t.title),
                    onSelected: (_) => _applyTemplate(t),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: CloserSpacing.lg),
          ],
          Text('Title', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          CloserTextField(
            controller: _title,
            hint: 'e.g. 100 days together',
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v?.trim() ?? '').isEmpty ? 'Give this moment a title.' : null,
          ),
          const SizedBox(height: CloserSpacing.md),
          Text('Date', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          Material(
            color: c.surface,
            borderRadius: CloserRadii.mdAll,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: CloserRadii.mdAll,
                side: BorderSide(color: c.line),
              ),
              leading: Icon(CloserIcons.calendar, color: c.textTertiary),
              title: Text(
                formatMediumDate(_date),
                style: context.text.bodyLarge,
              ),
              subtitle: _date.isAfter(_today())
                  ? Text(
                      'Upcoming — it will count down until then',
                      style: context.text.bodySmall,
                    )
                  : null,
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: CloserSpacing.md),
          Text('Description (optional)', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          CloserTextField(
            controller: _description,
            hint: 'A few words about this moment',
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: CloserSpacing.md),
          Text('Cover photo (optional)', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          _CoverPreview(
            group: widget.group,
            photoId: _cover,
            onTap: _pickCover,
          ),
          const SizedBox(height: CloserSpacing.md),
          Text('Style', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          Wrap(
            spacing: CloserSpacing.xs,
            children: [
              for (final t in MilestoneTheme.values)
                if (t != MilestoneTheme.heart ||
                    widget.group.type == GroupType.couple ||
                    _theme == MilestoneTheme.heart)
                  ChoiceChip(
                    label: Text(t.label),
                    avatar: Icon(t.icon, size: 18),
                    selected: _theme == t,
                    onSelected: (_) => setState(() => _theme = t),
                    showCheckmark: false,
                  ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
            title: Text(
              'Pin to the top of the journal',
              style: context.text.bodyLarge,
            ),
          ),
          const SizedBox(height: CloserSpacing.lg),
          FormErrorText(_error),
          CloserButton(
            label: 'Save Moment',
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends ConsumerWidget {
  const _CoverPreview({
    required this.group,
    required this.photoId,
    required this.onTap,
  });

  final Group group;
  final String? photoId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.closerColors;
    final photos = ref.watch(groupPhotosProvider(group.id)).value?.photos;
    final photo = photoId == null
        ? null
        : photos?.where((p) => p.id == photoId).firstOrNull;
    return Semantics(
      button: true,
      label: photo == null ? 'Choose a cover photo' : 'Change cover photo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: CloserRadii.lgAll,
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: CloserRadii.lgAll,
            border: Border.all(color: c.line),
            color: c.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: photo == null
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CloserIcons.gallery, color: c.textTertiary),
                      const SizedBox(width: CloserSpacing.xs),
                      Text(
                        'Choose from this group’s photos',
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                )
              : SizedBox.expand(child: PhotoImage(photo: photo)),
        ),
      ),
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
