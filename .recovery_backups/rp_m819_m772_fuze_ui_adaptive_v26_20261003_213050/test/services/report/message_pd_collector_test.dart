import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';
import 'package:calculateur_etranger/domain/report/message_pd_data.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/message_pd_preview_card.dart';
import 'package:calculateur_etranger/services/report/message_pd_collector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const result = CalculResult(
    portee: 2250.0,
    distanceTopoM: 2250.0,
    azimutMil: 3325.0,
    noireMil: 3325.0,
    aqeMil: 1292.3,
    tempsVolS: 44.0,
    charge: 'CH3',
    niveauMeteoBUsed: 5,
  );

  const request = FireRequest(
    systeme: Systeme.mo81M252,
    typeTir: TypeTir.appui,
    m252MunitionFamily: M252MunitionFamily.rpM819,
    fusee: TypeFusee.frappe,
    piece: FirePieceInput(
      utmX: 729350.0,
      utmY: 5153945.0,
      altitude: 345.0,
      utmZone: '30T',
    ),
    target: FireTargetInput(
      mode: FireTargetMode.daz,
      distanceM: 2250.0,
      azimutMil: 3325.0,
      altitude: 345.0,
    ),
    doctrine: FireDoctrineInput(
      nature: FireNature.ponctuel,
      shotPlan: FireShotPlanInput(nbCoups: 4, par: 1),
    ),
    salves: FireSalvoOptions(
      enabled: false,
      preferenceIdx: 0,
      lastSalveAroundPd: false,
    ),
    tirVertical: true,
    forcerCharge: false,
    masseEnabled: false,
    carreaux: 4,
    tirSimilaire: true,
    simCarreaux: 4,
    simFusee: TypeFusee.frappe,
    tAct: 25.0,
  );

  TirLineaireShot shot(double offsetM) => TirLineaireShot(
        nomPiece: 'PD',
        offsetM: offsetM,
        objX: 729075.0,
        objY: 5151712.0,
        resultat: result,
      );

  TirCompletOutput outputWithOffsets() => TirCompletOutput(
        resultatPrincipal: result,
        resultatPd: result,
        psOutputs: const <PieceSoutienOutput>[],
        shots: <TirLineaireShot>[
          shot(0.0),
          shot(12.0),
          shot(24.0),
          shot(36.0),
        ],
        firePlan: const FirePlan.empty(
          kind: FirePlanKind.ponctuel,
          azimutMilOut: 3325.0,
        ),
        pdOffset: 0.0,
        pdX: 729075.0,
        pdY: 5151712.0,
        prX: 729075.0,
        prY: 5151712.0,
      );

  test('M819 report keeps every calculated offset and uses English labels', () {
    final data = const MessagePdCollector().collect(
      request: request,
      output: outputWithOffsets(),
      utmZoneFallback: '30T',
    );

    expect(data.typeTir, 'Screening');
    expect(data.munition, 'RP M819');
    expect(data.fusee, 'Impact');
    expect(
      data.tirSimilaire,
      'Square Weight: 4 • Impact • Current T. 25 °C',
    );
    expect(data.pieceResults, hasLength(4));
    expect(
      data.pieceResults.map((entry) => entry.offsetM).toList(),
      <double?>[0.0, 12.0, 24.0, 36.0],
    );
  });

  testWidgets('report card displays the three additional PD offsets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const data = MessagePdData(
      pieceDirectriceDisponible: false,
      objectifDisponible: false,
      carteDisponible: false,
      distanceDisponible: false,
      azimutDisponible: false,
      deniveleeDisponible: false,
      noireDisponible: false,
      aqeDisponible: false,
      chargeDisponible: false,
      tempsDisponible: false,
      pieceResults: <MessagePieceResultData>[
        MessagePieceResultData(label: 'PD', offsetM: 0.0),
        MessagePieceResultData(label: 'PD', offsetM: 12.0),
        MessagePieceResultData(label: 'PD', offsetM: 24.0),
        MessagePieceResultData(label: 'PD', offsetM: 36.0),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 1600,
                child: MessagePdPreviewCard(
                  data: data,
                  card: const Color(0xFF15171D),
                  border: const Color(0xFF4D4F56),
                  textPrimary: Colors.white,
                  textSecondary: const Color(0xFFB8BBC3),
                  dark: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('OTHER GUNS / OFFSETS'), findsOneWidget);
    expect(find.text('Offset +12 m'), findsOneWidget);
    expect(find.text('Offset +24 m'), findsOneWidget);
    expect(find.text('Offset +36 m'), findsOneWidget);
  });
}
