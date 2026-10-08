import 'package:calculateur_etranger/domain/fire/models/tir_complet_input.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/controllers/tir_complet_controller.dart';
import 'package:calculateur_etranger/presentation/fire/state/tir_complet_state.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/linear_fire_config_card.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/nature_tir_switch_doctrine.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/options_tir_list.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/zonal_fire_config_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the fire state notifier persists each direct switch value', () {
    final notifier = TirCompletNotifier();

    notifier
      ..setTirVertical(true)
      ..setMasseEnabled(true)
      ..setObservateurEnabled(true)
      ..setAutrePiecesEnabled(true)
      ..setChargeForceeString(' ch1/2 ');

    expect(notifier.state.tirVertical, isTrue);
    expect(notifier.state.masseEnabled, isTrue);
    expect(notifier.state.observateurEnabled, isTrue);
    expect(notifier.state.autrePieces, isTrue);
    expect(notifier.state.forcerCharge, isTrue);
    expect(notifier.state.chargeForcee, isNull);
    expect(notifier.state.chargeForceeStr, 'CH1/2');

    notifier.clearChargeForcee();
    expect(notifier.state.forcerCharge, isFalse);
    expect(notifier.state.chargeForcee, isNull);
    expect(notifier.state.chargeForceeStr, isNull);
  });

  testWidgets('a doctrine switch has a full standard touch target',
      (tester) async {
    bool? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NatureTirSwitchDoctrine(
            value: false,
            onChanged: (value) => changed = value,
            activeThumbColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.black12,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(NatureTirSwitchDoctrine)).height, 48);
    await tester.tap(find.byType(Switch));
    expect(changed, isTrue);
  });

  testWidgets('a tap on the vertical-fire option card updates its switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: _OptionsHarness()),
    );

    final title = Systeme.caesar.labelTirVertical;
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text(title));
    await tester.pump();

    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .where((control) => control.value),
      isNotEmpty,
    );
  });

  testWidgets('a tap on the vertical-fire switch updates the state once', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: _OptionsHarness()),
    );

    final title = find.text(Systeme.caesar.labelTirVertical);
    final card =
        find.ancestor(of: title, matching: find.byType(GestureDetector));
    final control = find.descendant(of: card, matching: find.byType(Switch));

    expect(control, findsOneWidget);
    await tester.tap(control);
    await tester.pump();

    expect(tester.widget<Switch>(control).value, isTrue);
  });

  testWidgets('linear mobile-gun card toggles from its descriptive row', (
    tester,
  ) async {
    final changes = <LinearFireConfigResult>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LinearFireConfigCard(
              dark: false,
              totalCoups: 8,
              allPieces: const ['PD', 'PS1', 'PS2'],
              sectionSize: 3,
              initialMode: LinearFiringMode.sectionWithPd,
              initialSelectedRoles: const ['PD', 'PS1', 'PS2'],
              coupsParPiece: const {'PD': 2, 'PS1': 3, 'PS2': 3},
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('External mobile gun'));
    await tester.tap(find.text('External mobile gun'));
    await tester.pump();

    expect(changes, isNotEmpty);
    expect(changes.last.mode, LinearFiringMode.sectionWithoutPd);
  });

  testWidgets('zonal mobile-gun card toggles from its descriptive row', (
    tester,
  ) async {
    final changes = <ZonalFireConfigResult>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZonalFireConfigCard(
              dark: false,
              totalCoups: 8,
              allPieces: const ['PD', 'PS1', 'PS2'],
              sectionSize: 3,
              initialMode: ZonalFireMode.sectionWithPd,
              initialSelection: const ['PD', 'PS1', 'PS2'],
              initialNomade: false,
              coupsParPiece: const {'PD': 2, 'PS1': 3, 'PS2': 3},
              onChanged: changes.add,
              onValidate: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('External mobile gun'));
    await tester.tap(find.text('External mobile gun'));
    await tester.pump();

    expect(changes, isNotEmpty);
    expect(changes.last.mode, ZonalFireMode.sectionWithoutPd);
    expect(changes.last.nomadeExterne, isTrue);
  });
}

class _OptionsHarness extends ConsumerWidget {
  const _OptionsHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tirCompletProvider);
    final notifier = ref.read(tirCompletProvider.notifier);

    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OptionsTirList(
            st: state,
            stN: notifier,
            controller: TirCompletController(ref),
            card: Colors.white,
            border: Colors.black12,
            textPrimary: Colors.black,
            textSecondary: Colors.black54,
            dark: false,
            deltaAltMetCtrl: TextEditingController(),
            zCtrl: TextEditingController(),
            distCtrl: TextEditingController(),
            systeme: Systeme.caesar,
            onOpenNature: () {},
            onOpenAutresPieces: () {},
          ),
        ),
      ),
    );
  }
}
