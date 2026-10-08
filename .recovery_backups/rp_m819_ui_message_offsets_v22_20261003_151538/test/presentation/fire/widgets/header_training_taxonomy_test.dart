import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_header_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/tir_header_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildHeader({
    required TirHeaderState state,
    required TirHeaderNotifier notifier,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TirHeaderSection(
          header: state,
          headerN: notifier,
          card: const Color(0xFF15171D),
          border: const Color(0xFF4D4F56),
          textPrimary: Colors.white,
          textSecondary: const Color(0xFFB8BBC3),
          dark: true,
        ),
      ),
    );
  }

  testWidgets('M252 presents HE, Special Fires and Training separately', (
    tester,
  ) async {
    final notifier = TirHeaderNotifier();
    notifier.setSysteme(Systeme.mo81M252);

    await tester
        .pumpWidget(buildHeader(state: notifier.state, notifier: notifier));
    await tester.pump();

    expect(find.text('Close Support'), findsOneWidget);
    expect(find.text('Special Fires'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('M821'), findsOneWidget);
    expect(find.text('M821A1'), findsOneWidget);
    expect(find.text('M821A2'), findsOneWidget);
    expect(find.text('M889'), findsOneWidget);
    expect(find.text('M889A1'), findsOneWidget);
    expect(find.text('TP M879'), findsNothing);

    await tester.tap(find.text('Training'));
    await tester.pump();

    expect(find.text('TP M879'), findsOneWidget);
    final trainingChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('TP M879'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(trainingChip.onSelected, isNull);
    expect(notifier.state.m252MunitionFamily, M252MunitionFamily.m821a1);
    expect(notifier.state.typeTir, TypeTir.appui);
  });

  testWidgets('M252 Special Fires filters obscuration and illumination', (
    tester,
  ) async {
    final notifier = TirHeaderNotifier();
    notifier.setSysteme(Systeme.mo81M252);

    await tester
        .pumpWidget(buildHeader(state: notifier.state, notifier: notifier));
    await tester.pump();

    await tester.tap(find.text('Special Fires'));
    await tester.pump();

    expect(find.text('Special fire type'), findsOneWidget);
    expect(find.text('Aveuglement'), findsOneWidget);
    expect(find.text('Illumination'), findsOneWidget);
    expect(find.text('ILL M853A1'), findsOneWidget);
    expect(find.text('IR ILL M816'), findsOneWidget);
    expect(find.text('RP M819'), findsNothing);

    await tester.tap(find.text('Aveuglement'));
    await tester.pump();

    expect(find.text('RP M819'), findsOneWidget);
    expect(find.text('ILL M853A1'), findsNothing);
    expect(notifier.state.m252MunitionFamily, M252MunitionFamily.m821a1);
    expect(notifier.state.typeTir, TypeTir.appui);
  });

  testWidgets('CAESAR groups OSMC and OX below Training', (tester) async {
    const state = TirHeaderState(
      systeme: Systeme.caesar,
      typeTir: TypeTir.appui,
      typeMunition: TypeMunition.oeSemonceF6Fr,
    );
    final notifier = TirHeaderNotifier(state);

    await tester.pumpWidget(buildHeader(state: state, notifier: notifier));
    await tester.pump();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('OSMC 155 F6'), findsOneWidget);
    expect(find.text('OX 155 F1'), findsOneWidget);
    expect(find.text('Semonce'), findsNothing);
  });

  test('M252 header maps the IR illumination catalogue label explicitly', () {
    final notifier = TirHeaderNotifier();
    notifier.setSysteme(Systeme.mo81M252);

    notifier.setMo81Munition('IR ILL M816');

    expect(notifier.state.mo81MunitionLabel, 'IR ILL M816');
    expect(notifier.state.m252MunitionFamily, M252MunitionFamily.irIllM816);
  });
}
