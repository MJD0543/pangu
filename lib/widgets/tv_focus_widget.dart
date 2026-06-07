// lib/widgets/tv_focus_widget.dart
// Reusable focus wrappers for Android TV / Smart TV D-pad navigation.
// Provides visible focus indicators and orderly focus traversal.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any widget with a visible focus border glow — essential for TV
/// where the user navigates with a D-pad and needs to see which element
/// is currently focused.
class TvFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadiusGeometry? borderRadius;
  final Color? focusColor;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.focusColor,
  });

  @override
  State<TvFocusWrapper> createState() => _TvFocusWrapperState();
}

class _TvFocusWrapperState extends State<TvFocusWrapper> {
  late final FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode(debugLabel: 'tv_focus');
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.focusColor ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        _node.requestFocus();
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: (widget.borderRadius ?? BorderRadius.circular(10))
              .resolve(Directionality.of(context)),
          border: _focused
              ? Border.all(color: glow, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
          boxShadow: _focused
              ? [BoxShadow(color: glow.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// An icon-button sized and styled for TV remote navigation.
/// Larger hit target + visible focus ring.
class TvIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? tooltip;

  const TvIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.focusNode,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusWrapper(
      focusNode: focusNode,
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Global TV-back-button handler.
/// Call `onBackPressed` to simulate a system back press.
class TvBackHandler extends StatelessWidget {
  final Widget child;
  const TvBackHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.goBack): () {
          // Android TV back key
          _maybePop(context);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _maybePop(context);
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  void _maybePop(BuildContext ctx) {
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    }
  }
}

/// Wrap a scrollable grid to handle TV D-pad focus traversal correctly.
/// Prevents focus from getting "stuck" at the edges.
class TvGridFocusWrapper extends StatelessWidget {
  final Widget child;
  const TvGridFocusWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: child,
    );
  }
}
