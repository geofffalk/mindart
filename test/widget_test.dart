import 'package:flutter_test/flutter_test.dart';

import 'package:mindart_flutter/main.dart';

void main() {
  testWidgets('App launches and shows MindArt title', (WidgetTester tester) async {
    await tester.pumpWidget(const MindArtApp());

    expect(find.text('MindArt'), findsOneWidget);
  });
}
