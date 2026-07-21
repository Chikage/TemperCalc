import 'package:flutter/material.dart';

class AppDisplayScale extends StatelessWidget {
  const AppDisplayScale({
    required this.percent,
    required this.child,
    super.key,
  });

  final int percent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (percent == 100) return child;
    final scale = percent / 100;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }
        final size = Size(
          constraints.maxWidth / scale,
          constraints.maxHeight / scale,
        );
        final mediaQuery = MediaQuery.maybeOf(context);
        final scaledChild = mediaQuery == null
            ? child
            : MediaQuery(
                data: mediaQuery.copyWith(
                  size: size,
                  padding: _divide(mediaQuery.padding, scale),
                  viewPadding: _divide(mediaQuery.viewPadding, scale),
                  viewInsets: _divide(mediaQuery.viewInsets, scale),
                  systemGestureInsets: _divide(
                    mediaQuery.systemGestureInsets,
                    scale,
                  ),
                ),
                child: child,
              );
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(size: size, child: scaledChild),
            ),
          ),
        );
      },
    );
  }
}

EdgeInsets _divide(EdgeInsets value, double divisor) => EdgeInsets.fromLTRB(
  value.left / divisor,
  value.top / divisor,
  value.right / divisor,
  value.bottom / divisor,
);
