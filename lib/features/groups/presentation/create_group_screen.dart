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
import '../application/group_providers.dart';
import 'group_widgets.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  GroupType? _type;
  DateTime? _startDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _nameHint => switch (_type) {
    GroupType.couple => 'e.g. My Love',
    GroupType.family => 'e.g. Our Family',
    GroupType.friends => 'e.g. Travel Crew',
    null => 'Group name',
  };

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_type == null) {
      setState(() => _error = 'Choose who this group is for.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(groupActionsProvider)
          .createGroup(
            name: _name.text,
            type: _type!,
            relationshipStartDate: _type == GroupType.couple
                ? _startDate
                : null,
          );
      if (!mounted) return;
      // Land on the new group with its invite screen on top.
      context.go(Routes.invite(id));
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a Group'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(CloserSpacing.gutter),
            children: [
              Text('Choose a group type', style: context.text.titleMedium),
              const SizedBox(height: CloserSpacing.sm),
              for (final t in GroupType.values) ...[
                GroupTypeOption(
                  type: t,
                  selected: _type == t,
                  onTap: () => setState(() {
                    _type = t;
                    _error = null;
                  }),
                ),
                const SizedBox(height: CloserSpacing.sm),
              ],
              const SizedBox(height: CloserSpacing.md),
              Text('Group name', style: context.text.titleMedium),
              const SizedBox(height: CloserSpacing.sm),
              CloserTextField(
                controller: _name,
                hint: _nameHint,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Give your group a name.';
                  if (value.length > 60) return 'Keep it under 60 characters.';
                  return null;
                },
              ),
              if (_type == GroupType.couple) ...[
                const SizedBox(height: CloserSpacing.lg),
                Text(
                  'Together since (optional)',
                  style: context.text.titleMedium,
                ),
                const SizedBox(height: CloserSpacing.sm),
                RelationshipDateField(
                  value: _startDate,
                  onChanged: (d) => setState(() => _startDate = d),
                ),
                if (_startDate != null) ...[
                  const SizedBox(height: CloserSpacing.xs),
                  Text(
                    daysTogetherLabel(
                      daysTogether(_startDate!, DateTime.now()),
                    ),
                    style: context.text.bodySmall?.copyWith(
                      color: context.closerColors.accentStrong,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: CloserSpacing.lg),
              Text('Cover photo (optional)', style: context.text.titleMedium),
              const SizedBox(height: CloserSpacing.xs),
              Text(
                'You can add a cover once photo sharing arrives in the next '
                'update. Until then we use a painted placeholder.',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: CloserSpacing.xl),
              FormErrorText(_error),
              CloserButton(
                label: 'Create Group',
                isLoading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
