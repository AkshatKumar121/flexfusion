import 'package:flutter/material.dart';

/// Shared observer for refreshing database-backed pages when they become
/// visible again after another route is popped.
final RouteObserver<ModalRoute<dynamic>> flexFusionRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// Add this mixin to read-only/data screens that should reload after returning
/// from a pushed route. Keep transient flows such as an active workout session
/// out of this mixin so their in-progress state is not reset.
mixin AutoRefreshOnReturn<T extends StatefulWidget> on State<T>
    implements RouteAware {
  ModalRoute<dynamic>? _observedRoute;

  Future<void> refreshAfterReturn();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _observedRoute) return;

    if (_observedRoute != null) {
      flexFusionRouteObserver.unsubscribe(this);
    }
    _observedRoute = route;
    if (route != null) {
      flexFusionRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    refreshAfterReturn();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  @override
  void dispose() {
    flexFusionRouteObserver.unsubscribe(this);
    _observedRoute = null;
    super.dispose();
  }
}
