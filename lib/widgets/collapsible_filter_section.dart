import 'package:flutter/material.dart';

class CollapsibleFilterSection extends StatelessWidget {
  final bool visible;
  final double visibility;
  final Widget child;

  const CollapsibleFilterSection({
    super.key,
    required this.visible,
    required this.visibility,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final easedVisibility = Curves.easeOut.transform(visibility);

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: visibility,
        child: Opacity(
          opacity: easedVisibility,
          child: Transform.translate(
            offset: Offset(0, -12 * (1 - easedVisibility)),
            child: IgnorePointer(
              ignoring: !visible,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
