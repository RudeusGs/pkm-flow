import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in widget tree.');
    return scope!.dependencies;
  }

  static AppDependencies read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope was not found in widget tree.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => dependencies != oldWidget.dependencies;
}
