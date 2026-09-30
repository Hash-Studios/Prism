import 'package:Prism/core/router/not_found_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('not found page explains the problem and offers a way home', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotFoundPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('This page does not exist'), findsOneWidget);
    expect(find.text('The link you opened is invalid or no longer available.'), findsOneWidget);
    expect(find.text('Go home'), findsOneWidget);
  });
}
