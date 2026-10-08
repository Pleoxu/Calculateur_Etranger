//lib/domain/meteo/metcm_to_metb_transformer.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import '../entities/meteo_row.dart';

/// En-tête d'un message METCM
class MetcmHeader {
  final int octant; // 1-8
  final double latitudeDeg; // en degrés décimaux
  final double longitudeDeg; // en degrés décimaux
  final int jour; // 1-31

  /// IMPORTANT : champ heure au format HHD (HH + dixième d'heure)
  /// Exemple : 138 => 13:48 (8 * 6 min)
  final int heureMinute; // HHD (3 chiffres)

  final int dureeValidite; // 4, 9, ou 0 (4h, 12h, ou non précisée)
  final int altitudeStation; // en mètres
  final double pressionStation; // en hPa (corrigée si codée sur 3 chiffres)

  MetcmHeader({
    required this.octant,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.jour,
    required this.heureMinute,
    required this.dureeValidite,
    required this.altitudeStation,
    required this.pressionStation,
  });

  int get heure => heureMinute ~/ 10;
  int get minute => (heureMinute % 10) * 6;

  /// Pour compat/affichage HHMM
  int get heureMinuteHHMM => heure * 100 + minute;

  static double _decodePressure3Digits(int p) {
    // Règle METCM : si pression codée sur 3 chiffres et <200 => +1000
    if (p < 200) return (p + 1000).toDouble();
    return p.toDouble();
  }

  /// Parse l'en-tête METCM
  /// Format: "METCM3 483035 240944 018997"
  ///
  /// IMPORTANT : date/heure au format JJ HHD V (et PAS HHMM)
  /// Exemple : 181389 => jour 18, HHD=138 => 13:48, validité=9
  factory MetcmHeader.fromString(String header) {
    final parts = header.trim().split(RegExp(r'\s+'));

    if (parts.length < 4) {
      throw Exception('Invalid METCM header: $header');
    }

    // METCM3 -> octant 3
    final typeOctant = parts[0];
    if (!typeOctant.startsWith('METCM')) {
      throw Exception('Invalid METCM header: must start with METCM');
    }
    final octant = int.parse(typeOctant.substring(5));

    // 483035 -> latitude 48,3°N / longitude 03,5°E
    final coordStr = parts[1];
    if (coordStr.length != 6) {
      throw Exception('Invalid coordinate format: $coordStr');
    }

    // Latitude: 483 -> 48,3°
    final latInt = int.parse(coordStr.substring(0, 2));
    final latDec = int.parse(coordStr.substring(2, 3));
    final latitudeDeg = latInt + latDec / 10.0;

    // Longitude: 035 -> 03,5°
    final lonInt = int.parse(coordStr.substring(3, 5));
    final lonDec = int.parse(coordStr.substring(5, 6));
    final longitudeDeg = lonInt + lonDec / 10.0;

    // 240944 -> jour 24, HHD=094 => 09:24, durée 4h
    final dateTimeStr = parts[2];
    if (dateTimeStr.length != 6) {
      throw Exception('Invalid date/time format: $dateTimeStr');
    }

    final jour = int.parse(dateTimeStr.substring(0, 2));
    final heureMinute = int.parse(dateTimeStr.substring(2, 5)); // HHD
    final dureeValidite = int.parse(dateTimeStr.substring(5, 6));

    // 018997 -> altitude 180m, pression 997 hPa (ou 015 => 1015 hPa)
    final altPresStr = parts[3];
    if (altPresStr.length != 6) {
      throw Exception('Invalid altitude/pressure format: $altPresStr');
    }

    final altitudeCode = int.parse(altPresStr.substring(0, 3));
    final altitudeStation = altitudeCode * 10; // 018 -> 180m

    final pressionCode = int.parse(altPresStr.substring(3, 6));
    final pressionStation = _decodePressure3Digits(pressionCode);

    return MetcmHeader(
      octant: octant,
      latitudeDeg: latitudeDeg,
      longitudeDeg: longitudeDeg,
      jour: jour,
      heureMinute: heureMinute,
      dureeValidite: dureeValidite,
      altitudeStation: altitudeStation,
      pressionStation: pressionStation,
    );
  }

  /// Convertit en en-tête MET B
  MetBHeader toMetBHeader() {
    final latDeg = latitudeDeg.floor();
    final latMin = ((latitudeDeg - latDeg) * 60).round();

    final lonDeg = longitudeDeg.floor();
    final lonMin = ((longitudeDeg - lonDeg) * 60).round();

    // Pression relative ‰ de P_OACI (1013.25 hPa)
    final pressionRelative = (pressionStation / 1013.25 * 1000).round();

    // Altitude en dizaines de mètres
    final altitudeCode = (altitudeStation / 10).round();

    return MetBHeader(
      octant: octant,
      latitudeDeg: latDeg,
      latitudeMin: latMin,
      longitudeDeg: lonDeg,
      longitudeMin: lonMin,
      jour: jour,
      heureMinute: heureMinute, // HHD conservé
      dureeValidite: dureeValidite,
      altitudeStation: altitudeCode,
      pressionRelative: pressionRelative,
    );
  }

  @override
  String toString() {
    final hh = heure.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');

    return 'METCM$octant ${latitudeDeg.toStringAsFixed(1)}°N ${longitudeDeg.toStringAsFixed(1)}°E '
        'Jour $jour ${hh}h$mm '
        'Validity ${dureeValidite}h Alt ${altitudeStation}m P ${pressionStation.toStringAsFixed(0)} hPa';
  }
}

/// En-tête d'un message MET B
class MetBHeader {
  final int octant; // 1-8
  final int latitudeDeg; // degrés entiers
  final int latitudeMin; // minutes
  final int longitudeDeg; // degrés entiers
  final int longitudeMin; // minutes
  final int jour; // 1-31

  /// IMPORTANT : champ heure au format HHD (HH + dixième d'heure)
  /// Exemple : 138 => 13:48
  final int heureMinute; // HHD (3 chiffres)

  final int dureeValidite; // 4, 9, ou 0
  final int altitudeStation; // code (altitude / 10)
  final int pressionRelative; // en ‰ de P_OACI (1013.25 hPa)

  MetBHeader({
    required this.octant,
    required this.latitudeDeg,
    required this.latitudeMin,
    required this.longitudeDeg,
    required this.longitudeMin,
    required this.jour,
    required this.heureMinute,
    required this.dureeValidite,
    required this.altitudeStation,
    required this.pressionRelative,
  });

  int get heure => heureMinute ~/ 10;
  int get minute => (heureMinute % 10) * 6;

  /// Parse l'en-tête MET B
  /// Format: "MET B 3 3 450 022 24 094 4 018 997"
  factory MetBHeader.fromString(String header) {
    final parts = header.trim().split(RegExp(r'\s+'));

    if (parts.length < 11) {
      throw Exception('Invalid MET B header: $header');
    }

    if (parts[0] != 'MET' || parts[1] != 'B') {
      throw Exception('Invalid MET B header: must start with MET B');
    }
    final octant = int.parse(parts[3]);

    final latDeg = int.parse(parts[4].substring(0, 2));
    final latMin = int.parse(parts[4].substring(2));
    final lonDeg = int.parse(parts[5].substring(0, 2));
    final lonMin = int.parse(parts[5].substring(2));

    final jour = int.parse(parts[6]);
    final heureMinute = int.parse(parts[7]); // HHD
    final dureeValidite = int.parse(parts[8]);

    final altitudeStation = int.parse(parts[9]);
    final pressionRelative = int.parse(parts[10]);

    return MetBHeader(
      octant: octant,
      latitudeDeg: latDeg,
      latitudeMin: latMin,
      longitudeDeg: lonDeg,
      longitudeMin: lonMin,
      jour: jour,
      heureMinute: heureMinute,
      dureeValidite: dureeValidite,
      altitudeStation: altitudeStation,
      pressionRelative: pressionRelative,
    );
  }

  /// Formate l'en-tête au format MET B
  String toLine() {
    final lat =
        '${latitudeDeg.toString().padLeft(2, '0')}${latitudeMin.toString().padLeft(2, '0')}';
    final lon =
        '${longitudeDeg.toString().padLeft(2, '0')}${longitudeMin.toString().padLeft(2, '0')}';

    // HHD => 3 chiffres
    final heure = heureMinute.toString().padLeft(3, '0');
    final alt = altitudeStation.toString().padLeft(3, '0');
    final pres = pressionRelative.toString().padLeft(3, '0');

    return 'MET B 3 $octant $lat $lon $jour $heure $dureeValidite $alt $pres';
  }

  @override
  String toString() {
    final altMeters = altitudeStation * 10;
    final pressionHPa = pressionRelative * 1013.25 / 1000;

    final hh = heure.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');

    final lat = '$latitudeDeg°$latitudeMin\' N';
    final lon = '$longitudeDeg°$longitudeMin\' E';

    return 'MET B Octant $octant $lat $lon '
        'Jour $jour ${hh}h$mm '
        'Validity $dureeValidite h Alt $altMeters m P $pressionRelative‰ '
        '(${pressionHPa.toStringAsFixed(1)} hPa)';
  }
}

/// Représente une couche atmosphérique METCM
class MetcmLayer {
  final int lineNumber;
  final double altitudeBas; // en mètres
  final double altitudeHaut; // en mètres
  final double directionDeg; // en degrés (converti depuis les millièmes)
  final int directionMils; // en millièmes (valeur d'origine)
  final double vitesse; // en nœuds
  final double temperature; // en Kelvin
  final double pression; // en hPa (corrigée si codée en 3 chiffres)

  MetcmLayer({
    required this.lineNumber,
    required this.altitudeBas,
    required this.altitudeHaut,
    required this.directionDeg,
    required this.directionMils,
    required this.vitesse,
    required this.temperature,
    required this.pression,
  });

  static double _decodePressure(double p) {
    if (p < 200) return p + 1000;
    return p;
  }

  /// Parse une ligne METCM au format "LL DDDFFF TTTPPPPPP"
  ///
  /// IMPORTANT : dans ce fichier, on conserve l'hypothèse que les lignes
  /// arrivent dans l'ordre et sans trou, donc lineNumber est utilisé comme index
  /// de MetcmRanges (c'est ton postulat).
  factory MetcmLayer.fromLine(String line, int lineNumber) {
    line = line.replaceAll(RegExp(r'\s+'), '');

    // DDD (indices 2..4) est en dizaines de mils (10 mils)
    final direction10Mils = int.parse(line.substring(2, 5));
    final directionMils = direction10Mils * 10;

    // Conversion : Dir_deg = Dir_mils * 360 / 6400
    final directionDeg = directionMils * 360.0 / 6400.0;

    final vitesse = int.parse(line.substring(5, 8));
    final temperature = int.parse(line.substring(8, 12)) / 10.0;

    final pressionRaw = int.parse(line.substring(12, 16)).toDouble();
    final pression = _decodePressure(pressionRaw);

    final ranges = MetcmRanges.ranges;
    if (lineNumber >= ranges.length) {
      throw Exception('Invalid METCM line number: $lineNumber');
    }
    final altitudeBas = ranges[lineNumber][0];
    final altitudeHaut = ranges[lineNumber][1];

    return MetcmLayer(
      lineNumber: lineNumber,
      altitudeBas: altitudeBas,
      altitudeHaut: altitudeHaut,
      directionDeg: directionDeg,
      directionMils: directionMils,
      vitesse: vitesse.toDouble(),
      temperature: temperature,
      pression: pression,
    );
  }

  double get altitudeMoyenne => (altitudeBas + altitudeHaut) / 2;

  @override
  String toString() {
    return 'METCM[$lineNumber] ${altitudeBas.toInt()}-${altitudeHaut.toInt()}m: '
        'Dir=$directionMils mils (${directionDeg.toStringAsFixed(1)}°) '
        'V=$vitesse kt T=$temperature K P=$pression hPa';
  }
}

/// Définition des vraies tranches METCM
class MetcmRanges {
  static final List<List<double>> ranges = [
    [0, 200], // 00
    [0, 200], // 01
    [200, 500], // 02
    [500, 1000], // 03
    [1000, 1500], // 04
    [1500, 2000], // 05
    [2000, 2500], // 06
    [2500, 3000], // 07
    [3000, 3500], // 08
    [3500, 4000], // 09
    [4000, 4500], // 10
    [4500, 5000], // 11
    [5000, 6000], // 12
    [6000, 7000], // 13
    [7000, 8000], // 14
    [8000, 9000], // 15
    [9000, 10000], // 16
    [10000, 11000], // 17
    [11000, 12000], // 18
    [12000, 13000], // 19
    [13000, 14400], // 20
    [14000, 15000], // 21
    [15000, 16000], // 22
    [16000, 17000], // 23
    [17000, 18000], // 24
    [18000, 19000], // 25
    [19000, 20000], // 26
    [20000, 22000], // 27
    [22000, 24000], // 28
    [24000, 26000], // 29
    [26000, 28000], // 30
    [28000, 30000], // 31
  ];
}

/// Représente une tranche MET B
class MetBLayer {
  final int lineNumber;
  final double altitudeBas;
  final double altitudeHaut;

  /// Direction du vent en millièmes (mils) 0..6399
  int directionMils = 0;

  /// Vitesse du vent en nœuds
  int vitesse = 0;

  /// TTT : Température balistique relative en ‰
  int densiteTemp = 0;

  /// PPP : Densité balistique relative en ‰
  int densitePression = 0;

  // Pour le débogage
  List<String> sourceLayers = [];
  List<double> sourceWeights = [];

  MetBLayer({
    required this.lineNumber,
    required this.altitudeBas,
    required this.altitudeHaut,
  });

  double get altitudeMoyenne => (altitudeBas + altitudeHaut) / 2;

  /// Formate la ligne au format MET B : "LL DD FF TTT PPP"
  /// DD = centaines de mils (0..63)
  String toLine() {
    final ll = lineNumber.toString().padLeft(2, '0');

    final dd = (directionMils ~/ 100).toString().padLeft(2, '0');
    final ff = vitesse.toString().padLeft(2, '0');

    final tttEncoded = densiteTemp >= 1000 ? densiteTemp - 1000 : densiteTemp;
    final pppEncoded =
        densitePression >= 1000 ? densitePression - 1000 : densitePression;

    final ttt = tttEncoded.toString().padLeft(3, '0');
    final ppp = pppEncoded.toString().padLeft(3, '0');

    return '$ll $dd $ff $ttt $ppp';
  }

  /// Convertit en MeteoRow (direction en mils)
  MeteoRow toMeteoRow() {
    return MeteoRow(
      level: lineNumber,
      azimutMils: directionMils,
      vKn: vitesse,
      tempPermil: densiteTemp,
      pressPermil: densitePression,
      sourceType: 'METCM',
    );
  }

  String toDetailedString() {
    final sources = sourceLayers
        .asMap()
        .entries
        .map(
          (e) =>
              '${e.value} (${(sourceWeights[e.key] * 100).toStringAsFixed(1)}%)',
        )
        .join(', ');

    final tempPct = (densiteTemp / 10.0).toStringAsFixed(1);
    final densPct = (densitePression / 10.0).toStringAsFixed(1);

    return 'MET B[$lineNumber] ${altitudeBas.toInt()}-${altitudeHaut.toInt()}m: '
        'Dir=$directionMils mils V=$vitesse kt '
        'TTT=$densiteTemp‰ ($tempPct%) PPP=$densitePression‰ ($densPct%)\n'
        '  Sources: $sources';
  }
}

/// Constantes atmosphériques
class AtmosphereConstants {
  static const double t0 = 288.15; // K
  static const double p0 = 1013.25; // hPa
  static const double l = 0.0065; // K/m
  static const double exponent = 5.255;

  // Tropopause ISA
  static const double tropopauseAlt = 11000; // m
  static const double tropopauseTemp = 216.65; // K
}

/// Calculateur de transformation METCM → MET B
class MeteoTransformer {
  static final List<List<double>> metBRanges = [
    [0, 100], // 00
    [100, 350], // 01
    [350, 750], // 02
    [750, 1000], // 03
    [1000, 1750], // 04
    [1750, 2500], // 05
    [2500, 3500], // 06
    [3500, 4500], // 07
    [4500, 5500], // 08
    [6600, 7000], // 09
    [7000, 9000], // 10
    [9000, 11000], // 11
    [11000, 13000], // 12
    [13000, 15000], // 13
    [15000, 17000], // 14
    [17000, 19000], // 15
  ];

  static double temperatureStandard(double altitude) {
    if (altitude <= AtmosphereConstants.tropopauseAlt) {
      return AtmosphereConstants.t0 - AtmosphereConstants.l * altitude;
    }
    return AtmosphereConstants.tropopauseTemp;
  }

  static double pressionStandard(double altitude) {
    if (altitude <= AtmosphereConstants.tropopauseAlt) {
      final ratio =
          1 - (AtmosphereConstants.l * altitude / AtmosphereConstants.t0);
      return AtmosphereConstants.p0 * pow(ratio, AtmosphereConstants.exponent);
    }

    final p11km = AtmosphereConstants.p0 *
        pow(
          1 -
              AtmosphereConstants.l *
                  AtmosphereConstants.tropopauseAlt /
                  AtmosphereConstants.t0,
          AtmosphereConstants.exponent,
        );

    return p11km *
        exp(-0.0001577 * (altitude - AtmosphereConstants.tropopauseAlt));
  }

  static double calculateOverlap(
    double zBas,
    double zHaut,
    double ZBas,
    double ZHaut,
  ) {
    final overlap = min(zHaut, ZHaut) - max(zBas, ZBas);
    return overlap > 0 ? overlap : 0;
  }

  /// Convertit direction (degrés) et vitesse en composantes cartésiennes (u, v)
  static Map<String, double> windToComponents(
    double directionDeg,
    double vitesse,
  ) {
    final dirRad = directionDeg * pi / 180.0;
    return {'u': -vitesse * sin(dirRad), 'v': -vitesse * cos(dirRad)};
  }

  /// Convertit composantes cartésiennes (u, v) en direction (degrés) et vitesse
  /// Convention "wind from" (cohérente avec windToComponents)
  static Map<String, double> componentsToWind(double u, double v) {
    final vitesse = sqrt(u * u + v * v);

    // Vent nul : pas de direction significative
    if (vitesse < 1e-9) {
      return {'direction': 0.0, 'vitesse': 0.0};
    }

    var directionDeg = atan2(-u, -v) * 180.0 / pi;
    directionDeg = directionDeg % 360;
    if (directionDeg < 0) directionDeg += 360;

    return {'direction': directionDeg, 'vitesse': vitesse};
  }

  /// Transforme les données METCM en MeteoRow
  static List<MeteoRow> transformToMeteoRows(List<MetcmLayer> metcmLayers) {
    final metBLayers = transform(metcmLayers, verbose: false);
    return metBLayers.map((layer) => layer.toMeteoRow()).toList();
  }

  /// Transforme les données METCM en MET B
  static List<MetBLayer> transform(
    List<MetcmLayer> metcmLayers, {
    bool verbose = false,
  }) {
    final metBLayers = <MetBLayer>[];

    for (var i = 0; i < metBRanges.length; i++) {
      final range = metBRanges[i];
      final zBas = range[0];
      final zHaut = range[1];

      final metB = MetBLayer(
        lineNumber: i,
        altitudeBas: zBas,
        altitudeHaut: zHaut,
      );

      final overlappingLayers = <MetcmLayer>[];
      final weights = <double>[];
      var totalWeight = 0.0;

      for (final metcm in metcmLayers) {
        // IMPORTANT : Exclure METCM ligne 00 (réservée pour NRBC)
        if (metcm.lineNumber == 0) continue;

        final overlap = calculateOverlap(
          zBas,
          zHaut,
          metcm.altitudeBas,
          metcm.altitudeHaut,
        );

        if (overlap > 0) {
          final weight = overlap / (zHaut - zBas);
          overlappingLayers.add(metcm);
          weights.add(weight);
          totalWeight += weight;

          if (verbose) {
            metB.sourceLayers.add(
              'METCM${metcm.lineNumber.toString().padLeft(2, '0')}',
            );
            metB.sourceWeights.add(weight);
          }
        }
      }

      if (overlappingLayers.isEmpty) continue;

      // Normaliser les poids
      for (var j = 0; j < weights.length; j++) {
        weights[j] /= totalWeight;
        if (verbose && metB.sourceWeights.isNotEmpty) {
          metB.sourceWeights[j] = weights[j];
        }
      }

      // Vent moyen (méthode vectorielle)
      var uMoy = 0.0;
      var vMoy = 0.0;

      for (var j = 0; j < overlappingLayers.length; j++) {
        final layer = overlappingLayers[j];
        final components = windToComponents(layer.directionDeg, layer.vitesse);
        uMoy += weights[j] * components['u']!;
        vMoy += weights[j] * components['v']!;
      }

      final wind = componentsToWind(uMoy, vMoy);

      // Dir_mils = Dir_deg * 6400 / 360
      final dirMils = (wind['direction']! * 6400.0 / 360.0).round() % 6400;
      metB.directionMils = dirMils; // mils réels
      metB.vitesse = wind['vitesse']!.round();

      // Température & pression moyennes pondérées
      var tempMoy = 0.0;
      var pressMoy = 0.0;

      for (var j = 0; j < overlappingLayers.length; j++) {
        tempMoy += weights[j] * overlappingLayers[j].temperature;
        pressMoy += weights[j] * overlappingLayers[j].pression;
      }

      final altMoy = metB.altitudeMoyenne; // centre de tranche
      final tempStd = temperatureStandard(altMoy);
      final pressStd = pressionStandard(altMoy);

      // TTT (temp relative en ‰)
      final tempBalistique = tempMoy / tempStd;
      metB.densiteTemp = (tempBalistique * 1000).round();

      // PPP (densité relative ISA via rho ~ P/T) en ‰
      final densiteBalistique = (pressMoy / tempMoy) / (pressStd / tempStd);
      metB.densitePression = (densiteBalistique * 1000).round();

      metBLayers.add(metB);
    }

    return metBLayers;
  }
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: dart meteo_transform.dart <fichier_metcm>');
    return;
  }

  final path = arguments[0];
  final file = File(path);

  if (!file.existsSync()) {
    print('Error: File $path does not exist.');
    return;
  }

  final lines = file.readAsLinesSync();
  final metcmLayers = <MetcmLayer>[];

  var currentLine = 0;
  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('METCM')) continue;

    try {
      metcmLayers.add(MetcmLayer.fromLine(line, currentLine));
      currentLine++;
    } catch (e) {
      print('Error parsing line $currentLine: $e');
    }
  }

  final metBLayers = MeteoTransformer.transform(metcmLayers, verbose: true);

  print('\n--- MET B RESULT ---');
  for (final layer in metBLayers) {
    print(layer.toLine());
  }

  print('\n--- CALCULATION DETAILS ---');
  for (final layer in metBLayers) {
    print(layer.toDetailedString());
  }
}
