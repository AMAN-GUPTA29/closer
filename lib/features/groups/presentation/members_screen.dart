import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';
import 'group_widgets.dart';

enum _MemberAction { makeOwner, remove }

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.groupId});

  final String groupId;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Group group,
    GroupMember member,
    _MemberAction action,
  ) async {
    final actions = ref.read(groupActionsProvider);
    final ok = await showConfirmationDialog(
      context,
      title: action == _MemberAction.remove
          ? 'Remove ${member.displayName}?'
          : 'Make ${member.displayName} the owner?',
      message: action == _MemberAction.remove
          ? '${member.displayName} will lose access to ${group.name} and its '
                'photos right away.'
          : 'They will manage invitations and settings. You’ll stay in the '
                'group as a member.',
      confirmLabel: action == _MemberAction.remove ? 'Remove' : 'Make owner',
      destructive: action == _MemberAction.remove,
    );
    if (!ok) return;
    try {
      if (action == _MemberAction.remove) {
        await actions.removeMember(group.id, member.userId);
      } else {
        await actions.transferOwnership(group.id, member.userId);
      }
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupProvider(groupId));
    final members = ref.watch(groupMembersProvider(groupId));
    final myId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
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
            value: members,
            onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
            builder: (list) => ListView(
              padding: const EdgeInsets.all(CloserSpacing.gutter),
              children: [
                Text(
                  g.type.maxMembers == null
                      ? '${list.length} ${list.length == 1 ? 'member' : 'members'}'
                      : '${list.length} of ${g.type.maxMembers} members',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: CloserSpacing.sm),
                SectionCard(
                  dividerIndent: 72,
                  children: [
                    for (final m in list)
                      _MemberTile(
                        member: m,
                        isMe: m.userId == myId,
                        canManage: g.isOwner && m.userId != myId,
                        onAction: (a) => _act(context, ref, g, m, a),
                      ),
                  ],
                ),
                const SizedBox(height: CloserSpacing.xl),
                if (!g.isFull)
                  CloserButton(
                    label: 'Invite people',
                    icon: const Icon(CloserIcons.invite),
                    onPressed: () => context.push(Routes.invite(groupId)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onAction,
  });

  final GroupMember member;
  final bool isMe;
  final bool canManage;
  final ValueChanged<_MemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: CloserSpacing.md,
        right: canManage ? CloserSpacing.xxs : CloserSpacing.md,
      ),
      minTileHeight: 68,
      leading: MemberAvatar(name: member.displayName, size: 44),
      title: Text(
        isMe ? '${member.displayName} (you)' : member.displayName,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        'Joined ${formatMediumDate(member.joinedAt.toLocal())}',
        style: context.text.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.isOwner)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CloserSpacing.sm,
                vertical: CloserSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: CloserRadii.pillAll,
              ),
              child: Text(
                'Owner',
                style: context.text.labelMedium?.copyWith(
                  color: c.accentStrong,
                ),
              ),
            ),
          if (canManage)
            PopupMenuButton<_MemberAction>(
              tooltip: 'Options for ${member.displayName}',
              onSelected: onAction,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _MemberAction.makeOwner,
                  child: Text('Make owner'),
                ),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text('Remove from group'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
