import 'package:flutter/material.dart';

/// Opens the app side drawer from nested screens (profile, wallet, etc.).
class AppDrawerOpener {
  static GlobalKey<ScaffoldState>? _mainScaffoldKey;

  static void registerMainScaffoldKey(GlobalKey<ScaffoldState> key) {
    _mainScaffoldKey = key;
  }

  static void unregisterMainScaffoldKey(GlobalKey<ScaffoldState> key) {
    if (_mainScaffoldKey == key) {
      _mainScaffoldKey = null;
    }
  }

  /// Opens the nearest scaffold drawer for [context], then falls back to main nav.
  static void open(BuildContext context) {
    final localState = _nearestScaffoldWithDrawer(context);
    if (localState != null) {
      localState.openDrawer();
      return;
    }

    final mainState = _mainScaffoldKey?.currentState;
    if (mainState?.hasDrawer ?? false) {
      mainState!.openDrawer();
    }
  }

  /// Walks up from [context] and returns the closest scaffold that has a drawer.
  static ScaffoldState? _nearestScaffoldWithDrawer(BuildContext context) {
    ScaffoldState? found;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScaffoldState) {
        final state = element.state as ScaffoldState;
        if (state.hasDrawer) {
          found = state;
          return false;
        }
      }
      return true;
    });
    return found;
  }
}
