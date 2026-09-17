import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

/// Six-box OTP input driven by a single [controller].
class ShopOtpPinField extends StatefulWidget {
  const ShopOtpPinField({
    required this.controller,
    this.errorText,
    this.onCompleted,
    super.key,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback? onCompleted;

  @override
  State<ShopOtpPinField> createState() => _ShopOtpPinFieldState();
}

class _ShopOtpPinFieldState extends State<ShopOtpPinField> {
  final FocusNode _focus = FocusNode();
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.controller.text.length;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // TextEditingController notifies on selection-only changes too (e.g.
    // refocusing the hidden field while already at 6 digits), not just text
    // edits — only fire onCompleted on the actual <6 → 6 transition, or a
    // refocus/tap could re-trigger verify while it's already in flight.
    final int length = widget.controller.text.length;
    if (length >= 6 && _lastLength < 6) {
      widget.onCompleted?.call();
    }
    _lastLength = length;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String digits = widget.controller.text;
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(6, (int i) {
              final bool filled = i < digits.length;
              final bool active = i == digits.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled
                      ? AppColors.primaryBlue.withValues(alpha: 0.08)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? cs.error
                        : active
                            ? AppColors.primaryBlue
                            : cs.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Text(
                  filled ? digits[i] : '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 0,
          width: 0,
          child: TextField(
            focusNode: _focus,
            controller: widget.controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ],
      ],
    );
  }
}
