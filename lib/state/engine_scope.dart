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
}
