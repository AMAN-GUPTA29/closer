import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/group_type.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_widgets.dart'
    show FormErrorText, OrDivider;
import '../../groups/application/group_providers.dart';
import '../domain/invitation_models.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.initialSecret});

  /// Code or link token from a deep link.
  final String? initialSecret;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _code = TextEditingController();
  String? _secret;
  InvitePreview? _preview;
  bool _checking = false;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A secret from a deep link (query parameter or pending link) wins.
    // The pending invite is cleared after the first frame: providers must
    // not be modified while the widget tree is building.
    final pending = ref.read(pendingInviteProvider);
    final secret = widget.initialSecret ?? pending;
    if (secret != null &&
        secret.isNotEmpty &&
        InviteCodes.looksLikeCode(secret)) {
      _code.text = InviteCodes.format(secret);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pending != null) ref.read(pendingInviteProvider.notifier).clear();
      if (secret != null && secret.isNotEmpty) _check(secret);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check(String secret) async {
    setState(() {
      _checking = true;
      _error = null;
      _preview = null;
      _secret = secret;
    });
    try {
      final preview = await ref
          .read(groupActionsProvider)
          .previewInvitation(secret);
      if (mounted) setState(() => _preview = preview);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _submitCode() {
    final value = _code.text;
    if (!InviteCodes.looksLikeCode(value)) {
      setState(() => _error = 'Invitation codes have 8 letters and numbers.');
      return;
    }
    FocusScope.of(context).unfocus();
    _check(InviteCodes.normalize(value));
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final secret = InviteCodes.extractSecret(data?.text ?? '');
    if (!mounted) return;
    if (secret == null) {
      setState(
        () => _error =
            'There’s no Keeploom invite link or code on your clipboard. Copy '
            'the invite message first.',
      );
      return;
    }
    if (InviteCodes.looksLikeCode(secret)) {
      _code.text = InviteCodes.format(secret);
    }
    await _check(secret);
  }

  Future<void> _join() async {
    final secret = _secret;
    if (secret == null) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(groupActionsProvider)
          .redeemInvitation(secret);
      if (!mounted) return;
      if (result.isMember && result.groupId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.status == InviteStatus.joined
                  ? 'Welcome to ${_preview?.groupName ?? 'the group'}!'
                  : 'You’re already in this group.',
            ),
          ),
        );
        context.go(Routes.group(result.groupId!));
      } else {
        setState(() => _preview = InvitePreview(status: result.status));
      }
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a group'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CloserSpacing.gutter),
          children: [
            Semantics(
              header: true,
              child: Text('Got an invite?', style: context.text.headlineMedium),
            ),
            const SizedBox(height: CloserSpacing.xs),
            Text(
              'Enter the code someone in the group sent you. You’ll see the '
              'group before you join.',
              style: context.text.bodyMedium?.copyWith(fontSize: 14.5),
            ),
            const SizedBox(height: CloserSpacing.lg),
            CloserTextField(
              controller: _code,
              hint: 'Invitation code',
              placeholder: 'ABCD-EF23',
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submitCode(),
              maxLength: 12,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 -]')),
              ],
            ),
            const SizedBox(height: CloserSpacing.sm),
            Tooltip(
              message: 'Check code',
              child: CloserButton(
                label: 'Continue',
                onPressed: _checking ? null : _submitCode,
              ),
            ),
            const OrDivider(),
            CloserButton.secondary(
              label: 'Paste invite link',
              onPressed: _checking ? null : _pasteLink,
            ),
            const SizedBox(height: CloserSpacing.xl),
            FormErrorText(_error),
            if (_checking)
              const Padding(
                padding: EdgeInsets.all(CloserSpacing.xl),
                child: LoadingState(message: 'Checking invitation'),
              )
            else if (preview != null)
              _PreviewSection(
                preview: preview,
                joining: _joining,
                onJoin: _join,
                onOpen: preview.groupId == null
                    ? null
                    : () => context.go(Routes.group(preview.groupId!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.preview,
    required this.joining,
    required this.onJoin,
    required this.onOpen,
  });

  final InvitePreview preview;
  final bool joining;
  final VoidCallback onJoin;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final problem = preview.status.problem;
    if (preview.groupName == null) {
      return Semantics(
        liveRegion: true,
        child: NoticeCard(
          title: 'Can’t join with this invitation',
          message: problem ?? 'This invitation can’t be used.',
        ),
      );
    }
    final c = context.closerColors;
    final type = preview.groupType ?? GroupType.friends;
    final members = preview.memberCount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Group preview', style: context.text.titleMedium),
        const SizedBox(height: CloserSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: CloserRadii.xlAll,
            boxShadow: CloserElevation.medium,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CloserPhoto(
                  placeholderVariant: (preview.groupName!.length) % 4,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(CloserSpacing.md),
                child: Row(
                  children: [
                    Icon(type.icon, color: type.tint(c), size: 26),
                    const SizedBox(width: CloserSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.groupName!,
                            style: context.text.titleLarge,
                          ),
                          Text(
                            '${type.label} · $members '
                            '${members == 1 ? 'member' : 'members'}',
                            style: context.text.bodySmall,
                          ),
                          if (preview.relationshipStartDate != null)
                            Text(
                              daysTogetherLabel(
                                daysTogether(
                                  preview.relationshipStartDate!,
                                  DateTime.now(),
                                ),
                              ),
                              style: context.text.labelSmall?.copyWith(
                                color: c.accentStrong,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CloserSpacing.lg),
        if (preview.status == InviteStatus.alreadyMember)
          CloserButton(label: 'Open group', onPressed: onOpen)
        else if (problem != null)
          NoticeCard(title: 'Can’t join right now', message: problem)
        else ...[
          Text(
            'Photos are only visible once you join.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: CloserSpacing.sm),
          CloserButton(
            label: 'Join Group',
            isLoading: joining,
            onPressed: onJoin,
          ),
        ],
      ],
    );
  }
}
