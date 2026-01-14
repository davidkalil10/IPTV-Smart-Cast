import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FocusableActionWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showFocusHighlight;

  const FocusableActionWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.showFocusHighlight = false,
  });

  @override
  State<FocusableActionWrapper> createState() => _FocusableActionWrapperState();
}

class _FocusableActionWrapperState extends State<FocusableActionWrapper> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() {
            _isFocused = hasFocus;
          });
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            if (widget.onTap != null) {
              widget.onTap!();
              return true;
            }
            return false;
          },
        ),
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: (widget.showFocusHighlight && _isFocused)
                ? Colors.tealAccent.withOpacity(0.2)
                : Colors.transparent,
            border: Border.all(
              color: (widget.showFocusHighlight && _isFocused)
                  ? Colors.tealAccent
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
