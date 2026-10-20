import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/presentation/group_widgets.dart';
import '../domain/invitation_models.dart';

/// Expiry choices offered when creating an invitation.
enum InviteExpiry {
  day('1 day', Duration(days: 1)),
  week('7 days', Duration(days: 7)),
  month('30 days', Duration(days: 30)),
  never('No expiry', null);

  const InviteExpiry(this.label, this.duration);
  final String label;
  final Duration? duration;
}

/// Use-limit choices for friends and family groups.
enum InviteUses {
  one('1 person', 1),
  five('5 people', 5),
  unlimited('Unlimited', null);

  const InviteUses(this.label, this.count);
  final String label;
  final int? count;
}

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  InviteExpiry _expiry = InviteExpiry.week;
  InviteUses _uses = InviteUses.unlimited;
  CreatedInvitation? _created;
  bool _busy = false;

  Future<void> _create(Group group) async {
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(groupActionsProvider)
          .createInvitation(
            group.id,
            expiresIn: _expiry.duration,
            maxRedemptions: group.type == GroupType.couple ? 1 : _uses.count,
          );
      if (mounted) setState(() => _created = created);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(Group group, CreatedInvitation inv) async {
    await SharePlus.instance.share(
      ShareParams(
        text: InviteCodes.shareMessage(groupName: group.name, invitation: inv),
        subject: 'Join ${group.name} on Keeploom',
      ),
    );
  }

  Future<void> _copyLink(CreatedInvitation inv) async {
    await Clipboard.setData(ClipboardData(text: inv.link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Invite link copied')));
  }

  Future<void> _revoke(Invitation inv) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Cancel this invitation?',
      message:
          'Anyone who has code ••••-••${inv.codeHint} will no longer be able '
          'to join. People who already joined stay in the group.',
      confirmLabel: 'Cancel invitation',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(groupActionsProvider)
          .revokeInvitation(widget.groupId, inv.id);
      if (_created?.invitationId == inv.id) setState(() => _created = null);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          group.value == null ? 'Invite' : 'Invite to ${group.value!.name}',
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.group(widget.groupId)),
        ),
      ),
      body: SafeArea(
        child: AsyncBody(
          value: group,
          onRetry: () => ref.invalidate(groupProvider(widget.groupId)),
          builder: (g) => _body(context, g),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Group group) {
    final created = _created;
    final isCouple = group.type == GroupType.couple;
    return ListView(
      padding: const EdgeInsets.all(CloserSpacing.gutter),
      children: [
        _GroupBanner(group: group),
        const SizedBox(height: CloserSpacing.xl),
        if (group.isFull && created == null)
          NoticeCard(
            icon: CloserIcons.heart,
            title: 'Your couple group is complete',
            message:
                'Couple groups are just for two, so there’s no one else to '
                'invite.',
          )
        else if (created != null) ...[
          InviteCodeCard(
            code: created.displayCode,
            caption: isCouple
                ? 'Share this code or link with your partner.'
                : 'Share this code or link with the people you want here.',
          ),
          const SizedBox(height: CloserSpacing.sm),
          Text(
            '${sentenceCase(expiryLabel(created.expiresAt, DateTime.now()))}. '
            'For your privacy the code is shown only now — you can always '
            'create a new one.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: CloserSpacing.lg),
          CloserButton(
            label: 'Share Invite',
            icon: const Icon(CloserIcons.share),
            onPressed: () => _share(group, created),
          ),
          const SizedBox(height: CloserSpacing.sm),
          CloserButton.secondary(
            label: 'Copy invite link',
            icon: const Icon(CloserIcons.link),
            onPressed: () => _copyLink(created),
          ),
          const SizedBox(height: CloserSpacing.sm),
          Center(
            child: CloserButton.ghost(
              label: 'Create a different invitation',
              onPressed: () => setState(() => _created = null),
            ),
          ),
        ] else ...[
          Text('Expires after', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          _ChoiceChips<InviteExpiry>(
            values: InviteExpiry.values,
            selected: _expiry,
            label: (e) => e.label,
            onSelected: (e) => setState(() => _expiry = e),
          ),
          if (!isCouple) ...[
            const SizedBox(height: CloserSpacing.lg),
            Text('Can be used by', style: context.text.titleMedium),
            const SizedBox(height: CloserSpacing.sm),
            _ChoiceChips<InviteUses>(
              values: InviteUses.values,
              selected: _uses,
              label: (e) => e.label,
              onSelected: (e) => setState(() => _uses = e),
            ),
          ] else ...[
            const SizedBox(height: CloserSpacing.sm),
            Text(
              'Couple invitations work once — for your partner only.',
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: CloserSpacing.xl),
          CloserButton(
            label: 'Create invite code',
            icon: const Icon(CloserIcons.invite),
            isLoading: _busy,
            onPressed: () => _create(group),
          ),
        ],
        const SizedBox(height: CloserSpacing.xxl),
        _InvitationList(groupId: group.id, onRevoke: _revoke),
      ],
    );
  }
}

class _GroupBanner extends StatelessWidget {
  const _GroupBanner({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: CloserRadii.xlAll,
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CloserPhoto(placeholderVariant: group.placeholderVariant),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: context.closerColors.heroScrim,
              ),
            ),
            Positioned(
              left: CloserSpacing.md,
              bottom: CloserSpacing.md,
              right: CloserSpacing.md,
              child: Row(
                children: [
                  Icon(group.type.icon, color: Colors.white, size: 22),
                  const SizedBox(width: CloserSpacing.xs),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChips<T> extends StatelessWidget {
  const _ChoiceChips({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return Wrap(
      spacing: CloserSpacing.xs,
      runSpacing: CloserSpacing.xs,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
            showCheckmark: false,
            selectedColor: c.primary,
            backgroundColor: c.background,
            side: BorderSide(color: v == selected ? c.primary : c.line),
            labelStyle: context.text.labelLarge?.copyWith(
              fontSize: 14,
              color: v == selected ? c.onPrimary : c.textPrimary,
            ),
            shape: const StadiumBorder(),
          ),
      ],
    );
  }
}

class _InvitationList extends ConsumerWidget {
  const _InvitationList({required this.groupId, required this.onRevoke});

  final String groupId;
  final ValueChanged<Invitation> onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitationsProvider(groupId));
    final myId = ref.watch(currentUserIdProvider);
    final isOwner = ref.watch(groupProvider(groupId)).value?.isOwner ?? false;
    final c = context.closerColors;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Invitations', style: context.text.titleLarge),
        const SizedBox(height: CloserSpacing.sm),
        switch (invites) {
          AsyncData(:final value) when value.isEmpty => Text(
            'No invitations yet.',
            style: context.text.bodyMedium,
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final inv in value)
                _InvitationTile(
                  invitation: inv,
                  now: now,
                  canRevoke:
                      inv.statusAt(now) == InviteStatus.valid &&
                      (isOwner || inv.createdBy == myId),
                  onRevoke: () => onRevoke(inv),
                ),
            ],
          ),
          AsyncError() => Text(
            'Invitations couldn’t be loaded.',
            style: context.text.bodyMedium?.copyWith(color: c.danger),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(CloserSpacing.md),
            child: LoadingState(),
          ),
        },
      ],
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
    required this.invitation,
    required this.now,
    required this.canRevoke,
    required this.onRevoke,
  });

  final Invitation invitation;
  final DateTime now;
  final bool canRevoke;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final status = invitation.statusAt(now);
    final (label, color) = switch (status) {
      InviteStatus.valid => ('Active', c.success),
      InviteStatus.revoked => ('Cancelled', c.textTertiary),
      InviteStatus.expired => ('Expired', c.textTertiary),
      InviteStatus.exhausted => ('Used up', c.textTertiary),
      _ => ('', c.textTertiary),
    };
    final uses = invitation.maxRedemptions == null
        ? '${invitation.redemptionCount} joined'
        : '${invitation.redemptionCount} of ${invitation.maxRedemptions} used';
    return Padding(
      padding: const EdgeInsets.only(bottom: CloserSpacing.xs),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          CloserSpacing.md,
          CloserSpacing.sm,
          CloserSpacing.xs,
          CloserSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: CloserRadii.mdAll,
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Code ••••-••${invitation.codeHint}',
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(width: CloserSpacing.xs),
                      Text(
                        label,
                        style: context.text.labelSmall?.copyWith(color: color),
                      ),
                    ],
                  ),
                  Text(
                    status == InviteStatus.valid
                        ? '$uses · ${expiryLabel(invitation.expiresAt, now)}'
                        : uses,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (canRevoke)
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(foregroundColor: c.danger),
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
