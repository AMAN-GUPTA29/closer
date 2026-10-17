import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/closer_icons.dart';
import '../../../core/theme/closer_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../journal/application/content_providers.dart';

enum UsernameCheck { idle, checking, available, taken }

/// Username input with a live "available / taken" hint (signed-in only).
class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    this.current,
    this.checkAvailability = true,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;

  /// The user's current username (always counts as available).
  final String? current;

  /// Off during sign-up: there is no session to ask the server with yet.
  final bool checkAvailability;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  Timer? _debounce;
  UsernameCheck _check = UsernameCheck.idle;
  String _checked = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!widget.checkAvailability) return;
    final v = Validators.normalizeUsername(widget.controller.text);
    if (v == _checked) return;
    _debounce?.cancel();
    if (Validators.username(v) != null) {
      setState(() => _check = UsernameCheck.idle);
      return;
    }
    if (v == widget.current) {
      setState(() {
        _checked = v;
        _check = UsernameCheck.available;
      });
      return;
    }
    setState(() => _check = UsernameCheck.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final ok = await ref.read(contentBackendProvider).usernameAvailable(v);
        if (!mounted ||
            Validators.normalizeUsername(widget.controller.text) != v) {
          return;
        }
        setState(() {
          _checked = v;
          _check = ok ? UsernameCheck.available : UsernameCheck.taken;
        });
      } catch (_) {
        if (mounted) setState(() => _check = UsernameCheck.idle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.closerColors;
    final (text, color) = switch (_check) {
      UsernameCheck.checking => ('Checking…', c.textTertiary),
      UsernameCheck.available => ('Available', c.success),
      UsernameCheck.taken => ('Taken: try another one', c.danger),
      UsernameCheck.idle => (
        'Letters, numbers, dots and underscores. 3–20 characters.',
        c.textTertiary,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CloserTextField(
          controller: widget.controller,
          hint: 'Username',
          icon: CloserIcons.atSign,
          validator: (v) {
            final e = Validators.username(v);
            if (e != null) return e;
            if (_check == UsernameCheck.taken &&
                Validators.normalizeUsername(v ?? '') == _checked) {
              return 'That username is taken. Try another one.';
            }
            return null;
          },
          maxLength: 21,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.newUsername],
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
        ),
        const SizedBox(height: CloserSpacing.xxs),
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
