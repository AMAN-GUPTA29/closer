import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../application/group_providers.dart';
import '../../journal/presentation/special_moment_screen.dart'
    show PhotoChooserSheet;
import '../../photos/presentation/photo_widgets.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';

class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group settings'),
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
          builder: (g) => _SettingsForm(group: g),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.group});

  final Group group;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group.name);
  late DateTime? _start = widget.group.relationshipStartDate;
  late bool _showCounter = widget.group.showRelationshipCounter;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != widget.group.name ||
      _start != widget.group.relationshipStartDate ||
      _showCounter != widget.group.showRelationshipCounter;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final g = widget.group;
    setState(() => _saving = true);
    try {
      await ref
          .read(groupActionsProvider)
          .updateGroup(
            g.id,
            name: _name.text.trim() == g.name ? null : _name.text.trim(),
            relationshipStartDate: _start != g.relationshipStartDate
                ? _start
                : null,
            clearRelationshipStartDate:
                _start == null && g.relationshipStartDate != null,
            showRelationshipCounter: _showCounter == g.showRelationshipCounter
                ? null
                : _showCounter,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Group updated')));
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final g = widget.group;
    final ok = await showConfirmationDialog(
      context,
      title: 'Leave ${g.name}?',
      message: g.memberCount <= 1
          ? 'You’re the only member, so the group and its invitations will '
                'be deleted.'
          : g.isOwner
          ? 'You’ll lose access to its photos. Ownership passes to the '
                'member who has been here longest.'
          : 'You’ll lose access to its photos until someone invites you again.',
      confirmLabel: 'Leave group',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(groupActionsProvider).leaveGroup(g.id);
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _delete() async {
    final g = widget.group;
    final ok = await showConfirmationDialog(
      context,
      title: 'Delete ${g.name}?',
      message:
          'This permanently deletes the group for all ${g.memberCount} '
          '${g.memberCount == 1 ? 'member' : 'members'}, including its '
          'invitations. This can’t be undone.',
      confirmLabel: 'Delete group',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(groupActionsProvider).deleteGroup(g.id);
      if (mounted) context.go(Routes.home);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final owner = g.isOwner;
    return Form(
      key: _form,
      onChanged: () => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(CloserSpacing.gutter),
        children: [
          if (!owner) ...[
            const NoticeCard(
              icon: CloserIcons.lock,
              message: 'Only the group owner can change these settings.',
            ),
            const SizedBox(height: CloserSpacing.lg),
          ],
          Text('Group name', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          CloserTextField(
            controller: _name,
            hint: 'Group name',
            enabled: owner,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v?.trim() ?? '').isEmpty ? 'Give your group a name.' : null,
          ),
          if (g.type == GroupType.couple) ...[
            const SizedBox(height: CloserSpacing.lg),
            Text('Together since', style: context.text.titleMedium),
            const SizedBox(height: CloserSpacing.sm),
            IgnorePointer(
              ignoring: !owner,
              child: RelationshipDateField(
                value: _start,
                onChanged: (d) => setState(() => _start = d),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showCounter,
              onChanged: owner ? (v) => setState(() => _showCounter = v) : null,
              title: Text(
                'Show days-together counter',
                style: context.text.bodyLarge,
              ),
            ),
          ],
          if (owner) ...[
            const SizedBox(height: CloserSpacing.lg),
            CloserButton(
              label: 'Save changes',
              isLoading: _saving,
              onPressed: _dirty ? _save : null,
            ),
          ],
          if (owner) ...[
            const SizedBox(height: CloserSpacing.lg),
            Text('Cover photo', style: context.text.titleMedium),
            const SizedBox(height: CloserSpacing.sm),
            _CoverTile(group: g),
          ],
          const SizedBox(height: CloserSpacing.xxl),
          const Divider(),
          const SizedBox(height: CloserSpacing.lg),
          CloserButton.secondary(
            label: 'Leave group',
            icon: const Icon(CloserIcons.signOut),
            onPressed: _leave,
          ),
          if (owner) ...[
            const SizedBox(height: CloserSpacing.sm),
            CloserButton(
              label: 'Delete group',
              icon: const Icon(CloserIcons.trash),
              variant: CloserButtonVariant.danger,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverTile extends ConsumerWidget {
  const _CoverTile({required this.group});

  final Group group;

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => PhotoChooserSheet(
        group: group,
        allowNone: true,
        noneLabel: 'Use the newest photo',
      ),
    );
    if (chosen == null) return;
    try {
      await ref
          .read(groupActionsProvider)
          .setCover(group.id, chosen.isEmpty ? null : chosen);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Change cover photo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: CloserRadii.lgAll,
        onTap: group.photoCount == 0 ? null : () => _choose(context, ref),
        child: ClipRRect(
          borderRadius: CloserRadii.lgAll,
          child: SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GroupCover(group: group),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(CloserSpacing.sm),
                    child: Text(
                      group.photoCount == 0
                          ? 'Share a photo to choose a cover'
                          : group.coverPhotoId == null
                          ? 'Newest photo · tap to choose'
                          : 'Chosen photo · tap to change',
                      style: context.text.labelMedium?.copyWith(
                        color: Colors.white,
                        shadows: const [Shadow(blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
