import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/closer_icons.dart';

/// Text field with Keeploom styling, a leading icon and an optional
/// show/hide toggle for passwords.
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

  @override
  State<CloserTextField> createState() => _CloserTextFieldState();
}

class _CloserTextFieldState extends State<CloserTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.hint,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        counterText: '',
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 22),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? CloserIcons.eye : CloserIcons.eyeOff),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
