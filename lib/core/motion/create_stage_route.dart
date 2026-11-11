import 'package:flutter/material.dart';

/// The create rail expands into an empty stage. Reduce motion crossfades.
class CreateStageRoute<T> extends PageRouteBuilder<T> {
  CreateStageRoute({
    required WidgetBuilder builder,
    required Color color,
    Rect? origin,
  }) : super(
         transitionDuration: const Duration(milliseconds: 420),
         reverseTransitionDuration: const Duration(milliseconds: 280),
         pageBuilder: (context, animation, secondary) => builder(context),
         transitionsBuilder: (context, animation, secondary, child) {
           final reduce = MediaQuery.disableAnimationsOf(context);
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           if (reduce) {
             return ColoredBox(
               color: color,
               child: FadeTransition(opacity: curved, child: child),
             );
           }
           final size = MediaQuery.sizeOf(context);
           final center =
               origin?.center ?? Offset(size.width - 24, size.height * 0.55);
           final align = Alignment(
             ((center.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
             ((center.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
           );
           return ColoredBox(
             color: color,
             child: FadeTransition(
               opacity: curved,
               child: ScaleTransition(
                 scale: Tween<double>(begin: 0.12, end: 1).animate(curved),
                 alignment: align,
                 child: child,
               ),
             ),
           );
         },
       );
}
