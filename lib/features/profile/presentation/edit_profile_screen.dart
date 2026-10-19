import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_widgets.dart' show FormErrorText;
import '../../groups/presentation/group_widgets.dart';
import '../../journal/application/content_providers.dart';
import '../../notifications/domain/notification_models.dart';
import '../../photos/application/photo_providers.dart';
import 'profile_widgets.dart';
import 'username_field.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(CloserIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.profile),
        ),
      ),
      body: SafeArea(
        child: AsyncBody(
          value: profile,
          onRetry: () => ref.invalidate(myProfileProvider),
          builder: (p) => _EditForm(profile: p),
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _username = TextEditingController(
    text: widget.profile.username ?? '',
  );
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      final raw = await ref.read(photoPickerProvider)(PhotoSource.gallery);
      if (raw == null) return;
      // Reuse the photo pipeline; the 480 px thumbnail is a good avatar size.
      final prepared = await ref.read(imageProcessorProvider).prepare(raw);
      await ref.read(profileActionsProvider).setAvatar(prepared.thumbnail);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That photo couldn’t be used.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await ref.read(profileActionsProvider).removeAvatar();
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(profileActionsProvider);
      final username = Validators.normalizeUsername(_username.text);
      if (username != widget.profile.username) {
        await actions.setUsername(username);
      }
      await actions.rename(_name.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = ref.watch(myProfileProvider).value?.avatarPath != null;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(CloserSpacing.gutter),
        children: [
          Center(
            child: Stack(
              children: [
                MyAvatar(
                  fallbackName: widget.profile.displayName,
                  size: 104,
                  brand: true,
                ),
                if (_photoBusy) const Positioned.fill(child: LoadingState()),
              ],
            ),
          ),
          const SizedBox(height: CloserSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _photoBusy ? null : _changePhoto,
                icon: const Icon(CloserIcons.camera, size: 18),
                label: Text(hasPhoto ? 'Change photo' : 'Add a photo'),
              ),
              if (hasPhoto)
                TextButton(
                  onPressed: _photoBusy ? null : _removePhoto,
                  child: const Text('Remove photo'),
                ),
            ],
          ),
          Text(
            'Your photo and name are visible only to people in your groups.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: CloserSpacing.xl),
          Text('Display name', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          CloserTextField(
            controller: _name,
            hint: 'Your name',
            icon: CloserIcons.user,
            validator: Validators.displayName,
            maxLength: Validators.maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: CloserSpacing.lg),
          Text('Username', style: context.text.titleMedium),
          const SizedBox(height: CloserSpacing.sm),
          UsernameField(
            controller: _username,
            current: widget.profile.username,
          ),
          const SizedBox(height: CloserSpacing.xl),
          FormErrorText(_error),
          CloserButton(label: 'Save', isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
