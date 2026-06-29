import 'package:flutter/widgets.dart';

import 'engine_controller.dart';

/// Exposes the [EngineController] to the widget tree (model status + engine swap).
class EngineScope extends InheritedNotifier<EngineController> {
  const EngineScope({
    super.key,
    required EngineController controller,
    required super.child,
  }) : super(notifier: controller);

  static EngineController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EngineScope>();
    assert(scope != null, 'No EngineScope found in context');
    return scope!.notifier!;
  }

  /// Like [of] but returns null instead of asserting when no [EngineScope] is in
  /// the tree (e.g. hermetic widget tests that only provide an [AppScope]).
  static EngineController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EngineScope>()?.notifier;
  }
}
