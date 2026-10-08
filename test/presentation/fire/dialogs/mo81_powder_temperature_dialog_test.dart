import 'package:calculateur_etranger/presentation/fire/dialogs/mo81_powder_temperature_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'M252 powder dialog exposes only reference and current temperature',
    (tester) async {
      double? selectedTemperatureC;
      const referenceC = 21.11111111111111;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  selectedTemperatureC = await showMo81PowderTemperatureDialog(
                    context: context,
                    dark: true,
                    charge: 'CH3',
                    referenceTemperatureC: referenceC,
                    initialTemperatureC: referenceC,
                    initialUnit: PowderTemperatureUnit.fahrenheit,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Powder temperature'), findsOneWidget);
      expect(find.text('Reference powder temperature'), findsOneWidget);
      expect(find.text('Current powder temperature'), findsOneWidget);
      expect(find.text('Ref. V0'), findsNothing);
      expect(find.text('Previous fire fuze'), findsNothing);
      expect(find.textContaining('Carreaux'), findsNothing);

      final currentField = find.byType(TextField).last;
      await tester.enterText(currentField, '32');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(selectedTemperatureC, closeTo(0.0, 0.0001));
    },
  );
}
