import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan.dart';
import 'package:calculateur_etranger/domain/fire/results/fire_plan_kind.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';
import 'package:calculateur_etranger/services/messages/ct_piece_fire_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = CtPieceFirePayloadBuilder();

  test('projette les coordonnées et éléments calculés pour une pièce', () {
    final payload = builder.build(
      output: _outputWithShots(
        <TirLineaireShot>[
          TirLineaireShot(
            nomPiece: 'PD',
            offsetM: 0,
            objX: 712345.6,
            objY: 4876543.2,
            resultat: _result(
              noireMil: 1234.5,
              aqeMil: 987.6,
              tempsVolS: 24.12,
              charge: 'CH4',
            ),
          ),
        ],
      ),
      recipientId: 'pd',
    );

    expect(payload.title, 'Capsule PD');
    expect(payload.sections, hasLength(2));
    expect(_field(payload, 'Coordonnées pièce (UTM)'),
        'X=700000.0  Y=4800000.0  Z=120.0 m');
    expect(_field(payload, 'Noire'), '1234.5 mil');
    expect(_field(payload, 'AQE'), '987.6 mil');
    expect(_field(payload, 'Temps de vol'), '24.12 s');
    expect(_field(payload, 'Charge'), 'CH4');
  });

  test('libelle le temps comme tempage pour une munition éclairante', () {
    final payload = builder.build(
      output: _outputWithShots(
        <TirLineaireShot>[
          TirLineaireShot(
            nomPiece: 'PS1',
            offsetM: 20,
            objX: 712365.6,
            objY: 4876543.2,
            numeroSalve: 1,
            resultat: _result(
              noireMil: 1250.0,
              aqeMil: 1000.0,
              tempsVolS: 18.75,
              charge: 'CH3',
              typeAssets: 'OECL',
            ),
          ),
        ],
        pieces: const <PieceGeom>[
          PieceGeom(id: 'PS1', x: 700025.0, y: 4800025.0, isPd: false),
        ],
      ),
      recipientId: 'PS1',
    );

    expect(_field(payload, 'Tempage'), '18.75 s');
    expect(_fieldOrNull(payload, 'Temps de vol'), isNull);
  });

  test('conserve tous les tirs calculés destinés à la pièce', () {
    final payload = builder.build(
      output: _outputWithShots(
        <TirLineaireShot>[
          TirLineaireShot(
            nomPiece: 'PD',
            offsetM: 0,
            objX: 712345.6,
            objY: 4876543.2,
            resultat: _result(
              noireMil: 1200,
              aqeMil: 1000,
              tempsVolS: 20,
              charge: 'CH4',
            ),
          ),
          TirLineaireShot(
            nomPiece: 'PD',
            offsetM: 50,
            objX: 712395.6,
            objY: 4876543.2,
            numeroSalve: 2,
            resultat: _result(
              noireMil: 1210,
              aqeMil: 1005,
              tempsVolS: 20.5,
              charge: 'CH4',
            ),
          ),
          TirLineaireShot(
            nomPiece: 'PS1',
            offsetM: -50,
            objX: 712295.6,
            objY: 4876543.2,
            resultat: _result(
              noireMil: 1190,
              aqeMil: 995,
              tempsVolS: 19.5,
              charge: 'CH4',
            ),
          ),
        ],
      ),
      recipientId: 'PD',
    );

    expect(payload.sections, hasLength(3));
    expect(payload.sections[1].title, 'Tir 1');
    expect(payload.sections[2].title, 'Tir 2 • salve 2');
    expect(_field(payload, 'Charge'), 'CH4');
  });
}

String _field(dynamic payload, String label) {
  final value = _fieldOrNull(payload, label);
  if (value == null) {
    throw StateError('Champ introuvable : $label');
  }
  return value;
}

String? _fieldOrNull(dynamic payload, String label) {
  for (final section in payload.sections) {
    for (final field in section.fields) {
      if (field.label == label) return field.value;
    }
  }
  return null;
}

TirCompletOutput _outputWithShots(
  List<TirLineaireShot> shots, {
  List<PieceGeom> pieces = const <PieceGeom>[
    PieceGeom(id: 'PD', x: 700000.0, y: 4800000.0, z: 120.0, isPd: true),
  ],
}) {
  return TirCompletOutput(
    resultatPrincipal: null,
    resultatPd: null,
    psOutputs: const <PieceSoutienOutput>[],
    shots: shots,
    firePlan: FirePlan(
      kind: FirePlanKind.ponctuel,
      zoneLargeurM: 0,
      zoneProfondeurM: 0,
      azimutMilOut: 0,
      azimutLargeurMil: 0,
      azimutProfondeurMil: 0,
      nbPositions: 1,
      nbCoupsTotal: shots.length,
      gridNL: 1,
      gridNP: 1,
      allTargets: const <OffsetTarget>[],
      pieces: pieces,
      allocs: const <PieceAllocation>[],
      desiredShotsByPiece: const <String, int>{},
      isSpecial200x200: false,
      special200x200Plan: null,
      hasCrossings: false,
    ),
    pdOffset: 0,
    pdX: 0,
    pdY: 0,
    prX: 0,
    prY: 0,
  );
}

CalculResult _result({
  required double noireMil,
  required double aqeMil,
  required double tempsVolS,
  required String charge,
  String typeAssets = 'Appui',
}) {
  return CalculResult(
    portee: 10000,
    noireMil: noireMil,
    charge: charge,
    typeAssets: typeAssets,
    tempsVolS: tempsVolS,
    aqeMil: aqeMil,
    deriveMil: 0,
    rotzMilAbs: 0,
    wzMil: 0,
    totalCorrectionAzimutMil: 0,
    aeMil: 0,
    siteBrutMil: 0,
    corrSiteVraiMil: 0,
    siteTotalAsMil: 0,
    acsMil: 0,
    wxM: 0,
    rotxM: 0,
    masseM: 0,
    deltaV0M: 0,
    deltaTBM: 0,
    deltaPBM: 0,
    rtcM: 0,
    totalLongM: 0,
    latitudePieceDeg: null,
    distanceTopoM: 10000,
    azimutMil: 0,
    deniveleeM: 0,
    correctionSiteBM: null,
    niveauMeteoBUsed: null,
    deltaZStationM: null,
  );
}
