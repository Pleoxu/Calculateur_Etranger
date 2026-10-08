import 'package:calculateur_etranger/domain/fire/input/fire_request.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

/// Geometry shown in the fire-message map for a non-HE terminal effect.
///
/// The profile deliberately separates the calculated M772 deployment event
/// from the displayed footprint. A footprint is emitted only where an
/// effective diameter is available; RP M819 therefore remains a deployment
/// marker rather than a fabricated HE/smoke circle.
enum SpecialEffectDisplayKind { none, illumination, screening }

class SpecialEffectDisplayProfile {
  const SpecialEffectDisplayProfile._({
    required this.kind,
    this.initialFootprintRadiusM,
    this.finalFootprintRadiusM,
    this.startHeightAglM,
    this.endHeightAglM,
    this.burnDurationMinS,
    this.burnDurationMaxS,
    this.descentRateMps,
    this.effectiveDiameterM,
    this.eventLabel,
    this.footprintStatus,
    this.screeningPelletCount,
    this.screeningLengthMinM,
    this.screeningLengthMaxM,
    this.screeningWidthMinM,
    this.screeningWidthMaxM,
    this.screeningDurationMinS,
    this.screeningDurationMaxS,
  });

  const SpecialEffectDisplayProfile.none()
      : this._(kind: SpecialEffectDisplayKind.none);

  final SpecialEffectDisplayKind kind;
  final double? initialFootprintRadiusM;
  final double? finalFootprintRadiusM;
  final double? startHeightAglM;
  final double? endHeightAglM;
  final double? burnDurationMinS;
  final double? burnDurationMaxS;
  final double? descentRateMps;
  final double? effectiveDiameterM;
  final String? eventLabel;
  final String? footprintStatus;

  /// Nombre de pastilles RP éjectées par le M819.
  final int? screeningPelletCount;

  /// Bornes déclarées de l'écran RP M819, en mètres.
  final double? screeningLengthMinM;
  final double? screeningLengthMaxM;
  final double? screeningWidthMinM;
  final double? screeningWidthMaxM;

  /// Persistance déclarée de l'écran RP M819, en secondes.
  final double? screeningDurationMinS;
  final double? screeningDurationMaxS;

  bool get isIllumination => kind == SpecialEffectDisplayKind.illumination;
  bool get isScreening => kind == SpecialEffectDisplayKind.screening;

  bool get hasFootprint =>
      isIllumination &&
      initialFootprintRadiusM != null &&
      initialFootprintRadiusM! > 0.0;

  bool get hasScreeningEnvelope =>
      isScreening &&
      screeningPelletCount != null &&
      screeningPelletCount! > 1 &&
      screeningLengthMinM != null &&
      screeningLengthMaxM != null &&
      screeningWidthMinM != null &&
      screeningWidthMaxM != null &&
      screeningLengthMinM! > 0.0 &&
      screeningLengthMaxM! >= screeningLengthMinM! &&
      screeningWidthMinM! > 0.0 &&
      screeningWidthMaxM! >= screeningWidthMinM!;

  /// Milieu de la plage déclarée, employé seulement pour répartir visuellement
  /// les 36 points. Les deux polygones conservent les bornes réelles.
  double? get screeningPelletDisplayLengthM => hasScreeningEnvelope
      ? (screeningLengthMinM! + screeningLengthMaxM!) / 2.0
      : null;

  /// Resolves the profile for the current ballistic result.
  ///
  /// The 155 mm, MO-120 and MO81 LLR values are declared display parameters:
  /// 65 s at 5 m/s with their respective start heights. The M853A1 values
  /// remain the published values already carried by its M252 result.
  factory SpecialEffectDisplayProfile.fromRequest({
    required FireRequest request,
    required CalculResult? result,
  }) =>
      SpecialEffectDisplayProfile.fromContext(
        systeme: request.systeme,
        typeTir: request.typeTir,
        m252MunitionFamily: request.m252MunitionFamily,
        result: result,
      );

  factory SpecialEffectDisplayProfile.fromContext({
    required Systeme systeme,
    required TypeTir typeTir,
    required M252MunitionFamily? m252MunitionFamily,
    required CalculResult? result,
  }) {
    if (result == null) return const SpecialEffectDisplayProfile.none();

    final isM819 = systeme == Systeme.mo81M252 &&
        m252MunitionFamily == M252MunitionFamily.rpM819;
    if (isM819) {
      return const SpecialEffectDisplayProfile._(
        kind: SpecialEffectDisplayKind.screening,
        eventLabel: 'M772 ejection / RP pellet release',
        footprintStatus: 'M772 ejection at the objective • 36 RP pellets shown '
            'in a line on both sides of the event • screening envelope '
            '50–60 m long × 75–90 m wide • expected persistence 2–3 min. The inner '
            'and outer outlines show the declared bounds, not a probability '
            'law or a precise pellet-impact distribution.',
        screeningPelletCount: 36,
        screeningLengthMinM: 50.0,
        screeningLengthMaxM: 60.0,
        screeningWidthMinM: 75.0,
        screeningWidthMaxM: 90.0,
        screeningDurationMinS: 120.0,
        screeningDurationMaxS: 180.0,
      );
    }

    final isM853A1 = systeme == Systeme.mo81M252 &&
        m252MunitionFamily == M252MunitionFamily.illM853a1;
    if (isM853A1) {
      final details = result.details;
      final startHeight =
          _asDouble(details['illuminationBurstHeightAglM']) ?? 475.0;
      final diameter =
          _asDouble(details['illuminationEffectiveDiameterM']) ?? 1200.0;
      final duration = _durationRange(details['illuminationBurnDurationS']);
      return _illumination(
        startHeightAglM: startHeight,
        effectiveDiameterM: diameter,
        burnDurationMinS: duration.minS ?? 50.0,
        burnDurationMaxS: duration.maxS ?? 60.0,
        descentRateMps: 5.0,
        eventLabel: 'M772 functioning / 1st deployment',
      );
    }

    final isIllumination = typeTir == TypeTir.eclairant || result.isOECL;
    if (!isIllumination) return const SpecialEffectDisplayProfile.none();

    switch (systeme) {
      case Systeme.caesar:
        return _illumination(
          startHeightAglM: 600.0,
          effectiveDiameterM: 600.0,
          burnDurationMinS: 65.0,
          burnDurationMaxS: 65.0,
          descentRateMps: 5.0,
          eventLabel: 'Illumination deployment',
        );
      case Systeme.mo120:
      case Systeme.mepac:
        return _illumination(
          startHeightAglM: 500.0,
          effectiveDiameterM: 600.0,
          burnDurationMinS: 65.0,
          burnDurationMaxS: 65.0,
          descentRateMps: 5.0,
          eventLabel: 'Illumination deployment',
        );
      case Systeme.mo81Lrr:
        return _illumination(
          startHeightAglM: 450.0,
          effectiveDiameterM: 600.0,
          burnDurationMinS: 65.0,
          burnDurationMaxS: 65.0,
          descentRateMps: 5.0,
          eventLabel: 'Illumination deployment',
        );
      case Systeme.mo81M252:
        return const SpecialEffectDisplayProfile.none();
    }
  }

  static SpecialEffectDisplayProfile _illumination({
    required double startHeightAglM,
    required double effectiveDiameterM,
    required double burnDurationMinS,
    required double burnDurationMaxS,
    required double descentRateMps,
    required String eventLabel,
  }) {
    final endHeightAglM = (startHeightAglM - descentRateMps * burnDurationMaxS)
        .clamp(0.0, startHeightAglM)
        .toDouble();
    final initialRadiusM = effectiveDiameterM / 2.0;

    return SpecialEffectDisplayProfile._(
      kind: SpecialEffectDisplayKind.illumination,
      initialFootprintRadiusM: initialRadiusM,
      // The source publishes a nominal illuminated diameter, not a law of
      // luminous intensity over altitude. Keep one qualified footprint and
      // expose the 65 s / descent envelope as text rather than fabricate a
      // smaller final circle from an unqualified geometric assumption.
      finalFootprintRadiusM: null,
      startHeightAglM: startHeightAglM,
      endHeightAglM: endHeightAglM,
      burnDurationMinS: burnDurationMinS,
      burnDurationMaxS: burnDurationMaxS,
      descentRateMps: descentRateMps,
      effectiveDiameterM: effectiveDiameterM,
      eventLabel: eventLabel,
    );
  }

  static double? _asDouble(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static ({double? minS, double? maxS}) _durationRange(Object? raw) {
    if (raw is num && raw.isFinite) {
      final value = raw.toDouble();
      return (minS: value, maxS: value);
    }
    if (raw is Iterable) {
      final values = raw
          .whereType<num>()
          .map((value) => value.toDouble())
          .where((value) => value.isFinite)
          .toList();
      if (values.isNotEmpty) {
        values.sort();
        return (minS: values.first, maxS: values.last);
      }
    }
    return (minS: null, maxS: null);
  }
}
