import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_header_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the header exposes the supported default system',
    (tester) async {
      final notifier = TirHeaderNotifier();
      final selectedSystems = <Systeme>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TirHeaderSection(
              header: notifier.state,
              headerN: notifier,
              card: Colors.black,
              border: Colors.white24,
              textPrimary: Colors.white,
              textSecondary: Colors.white70,
              dark: true,
              onSystemeChanged: selectedSystems.add,
            ),
          ),
        ),
      );

      expect(
        find.widgetWithText(OutlinedButton, 'CAESAR'),
        findsOneWidget,
      );

      // Systems intentionally removed from this project must not reappear
      // in the selector as stale UI entries.
      expect(find.text('MO-120'), findsNothing);
      expect(find.text('MO81 LLR'), findsNothing);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'CAESAR'),
      );
      await tester.pump();

      expect(selectedSystems, hasLength(1));
      expect(
        selectedSystems.single,
        isIn(<Systeme>[
          Systeme.caesar,
          Systeme.caesarExport,
        ]),
      );

      expect(
        notifier.state.systeme,
        isIn(<Systeme>[
          Systeme.caesar,
          Systeme.caesarExport,
        ]),
      );

      notifier.dispose();
    },
  );
}
