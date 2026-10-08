import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/dialogs/tir_similaire_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('M252 similar-fire dialog displays the imposed M772 fuze', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showTirSimilaireDialog(
                  context: context,
                  dark: true,
                  initialCarreaux: 4,
                  initialFusee: TypeFusee.frappe,
                  fuseesDisponibles: const <TypeFusee>[TypeFusee.frappe],
                  imposedFuzeLabel: 'M772',
                );
              },
              child: const Text('Open similar fire'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open similar fire'));
    await tester.pumpAndSettle();

    expect(find.text('Previous fire fuze'), findsOneWidget);
    expect(
      find.text('M772 — defined by the M252 cartridge profile'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<TypeFusee>), findsNothing);
  });
}
