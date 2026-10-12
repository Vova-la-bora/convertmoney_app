import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convertmoney_app/main.dart';

String? v(WidgetTester tester, Finder f) {
  return tester.widget<DropdownButton<String>>(f).value;
}

void main() {
  testWidgets('Пустая сумма', (WidgetTester tester) async {
    await tester.pumpWidget(Converter());
    await tester.tap(find.text('Конвертировать'));
    await tester.pump();
    expect(find.text('Введите сумму'), findsOneWidget);
  });

  testWidgets('Отрицательная сумма', (WidgetTester tester) async {
    await tester.pumpWidget(Converter());
    await tester.enterText(find.byType(TextField), '-50');
    await tester.tap(find.text('Конвертировать'));
    await tester.pump();
    expect(find.text('Сумма должна быть больше нуля'), findsOneWidget);
  });

  testWidgets('Смена валют местами', (WidgetTester tester) async {
    await tester.pumpWidget(Converter());
    Finder d = find.byType(DropdownButton<String>);
    expect(v(tester, d.first), 'EUR');
    expect(v(tester, d.last), 'RUB');
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();
    expect(v(tester, d.first), 'RUB');
    expect(v(tester, d.last), 'EUR');
  });
}
