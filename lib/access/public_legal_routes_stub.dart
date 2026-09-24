import 'package:flutter/material.dart';

List<Route<dynamic>> publicInitialRoutes(String initialRoute, Widget home) => [
  MaterialPageRoute<void>(builder: (_) => home),
];

Route<dynamic>? publicLegalRoute(RouteSettings settings) => null;
