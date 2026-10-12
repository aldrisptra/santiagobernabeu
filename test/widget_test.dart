import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:santiago_bernabeu/main.dart';

void main() {
  testWidgets('Login page shows title and login button', (WidgetTester tester) async {
    await tester.pumpWidget(const SantiagoBernabeuApp());

    expect(find.text('SANTIAGO BERNABÉU'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
