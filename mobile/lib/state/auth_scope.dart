/// Provides the [AuthController] to the whole widget tree and rebuilds the
/// dependents when the session changes.
library;

import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  static AuthController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
}
