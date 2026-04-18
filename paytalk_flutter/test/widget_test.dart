import 'package:flutter_test/flutter_test.dart';
import 'package:paytalk_flutter/main.dart';

void main() {
  testWidgets('PayTalk app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PayTalkApp());
    expect(find.text('PayTalk'), findsWidgets);
  });
}
