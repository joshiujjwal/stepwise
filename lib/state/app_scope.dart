import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Exposes the [AppController] to the widget tree and rebuilds dependents when
/// it notifies. Use `AppScope.of(context)` to read + subscribe.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.notifier!;
  }
}
