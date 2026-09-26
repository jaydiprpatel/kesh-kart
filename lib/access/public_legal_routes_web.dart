import 'package:flutter/material.dart';
import 'package:kesh_kart/customer/legal_document_page.dart';

List<Route<dynamic>> publicInitialRoutes(String initialRoute, Widget home) {
  final page = _pageFor(initialRoute);
  return [
    MaterialPageRoute<void>(
      settings: RouteSettings(name: initialRoute),
      builder: (_) => page ?? home,
    ),
  ];
}

Route<dynamic>? publicLegalRoute(RouteSettings settings) {
  final page = _pageFor(settings.name);
  if (page == null) return null;
  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}

Widget? _pageFor(String? routeName) {
  switch (Uri.tryParse(routeName ?? '')?.path) {
    case '/privacy':
      return const LegalDocumentPage(document: LegalDocument.privacy);
    case '/terms':
      return const LegalDocumentPage(document: LegalDocument.terms);
    case '/delete-account':
      return const AccountDeletionPage();
  }
  return null;
}
