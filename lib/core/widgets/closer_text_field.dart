import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/closer_icons.dart';

/// Text field with Keeploom styling: a small label above a plain box (as on
/// the Keeploom concept) and an optional show/hide toggle for passwords.
/// [icon] is accepted for compatibility but no longer drawn.
class CloserTextField extends StatefulWidget {
  const CloserTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.inputFormatters,
    this.placeholder,
    this.showLabel = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Example text inside the empty box (e.g. "you@example.com").
  final String? placeholder;

  /// False puts [hint] inside the box instead of above it (e.g. a caption).
  final bool showLabel;

  @override
  State<CloserTextField> createState() => _CloserTextFieldState();
}

class _CloserTextFieldState extends State<CloserTextField> {
  late bool _hidden = widget.obscure;

  String? get _placeholder =>
      widget.placeholder ??
      switch (widget.hint) {
        'Email' => 'you@example.com',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    // The label sits above the box and is merged into the field's
    // semantics, so screen readers still announce it.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.hint,
                style: theme.titleSmall?.copyWith(fontSize: 13.5),
              ),
            ),
          TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            obscureText: _hidden,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            textCapitalization: widget.textCapitalization,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            autocorrect: !widget.obscure,
            enableSuggestions: !widget.obscure,
            style: theme.bodyLarge?.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.showLabel ? _placeholder : widget.hint,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              suffixIcon: widget.obscure
                  ? IconButton(
                      tooltip: _hidden ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _hidden ? CloserIcons.eye : CloserIcons.eyeOff,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
