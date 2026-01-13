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
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onKeyEvent: (node, event) {
        if (widget.onTap != null &&
            event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
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
