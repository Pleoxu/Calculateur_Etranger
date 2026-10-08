import 'dart:math' as math;

/// Constellations GNSS reconnues par le parser.
enum GnssConstellation { gps, glonass, galileo, beidou, qzss, navic, unknown }

/// État d'utilisation d'une constellation dans une solution GNS.
enum GnssMode {
  noFix,
  autonomous,
  differential,
  precise,
  rtkFixed,
  rtkFloat,
  estimated,
  manual,
  simulator,
  unknown,
}

/// Informations d'un satellite issues d'une phrase GSV.
class GnssSatelliteInfo {
  final GnssConstellation constellation;
  final int prn;
  final int? elevationDeg;
  final int? azimuthDeg;
  final int? snrDbHz;

  const GnssSatelliteInfo({
    required this.constellation,
    required this.prn,
    this.elevationDeg,
    this.azimuthDeg,
    this.snrDbHz,
  });

  @override
  String toString() {
    return 'GnssSatelliteInfo('
        'constellation: $constellation, '
        'prn: $prn, '
        'elevationDeg: $elevationDeg, '
        'azimuthDeg: $azimuthDeg, '
        'snrDbHz: $snrDbHz'
        ')';
  }
}

/// Snapshot GNSS consolidé à partir des phrases NMEA reçues.
///
/// Le parser conserve l'état entre les phrases :
/// - GNS / GGA : position, altitude, qualité, satellites, HDOP
/// - GSA       : type de fix, PDOP, HDOP, VDOP, satellites utilisés
/// - GSV       : satellites visibles par constellation
/// - RMC       : date/heure UTC, vitesse et route
class NmeaGnssFix {
  final double? latitude;
  final double? longitude;

  /// Altitude orthométrique / MSL lorsqu'elle est fournie par GGA/GNS.
  final double? altitudeMslMeters;

  /// Séparation géoïde - ellipsoïde lorsqu'elle est fournie.
  final double? geoidalSeparationMeters;

  /// Qualité GGA : 0 = invalide, 1 = autonome, 2 = DGPS, etc.
  final int? fixQuality;

  /// Type de fix GSA : 1 = aucun, 2 = 2D, 3 = 3D.
  final int? fixType;

  final int? satellitesUsed;
  final double? hdop;
  final double? vdop;
  final double? pdop;

  final DateTime? utc;

  /// Vitesse sol issue de RMC.
  final double? speedKnots;

  /// Route vraie issue de RMC.
  final double? courseTrueDeg;

  final bool rmcActive;

  /// Mode GNS par constellation lorsqu'il est disponible.
  final Map<GnssConstellation, GnssMode> constellationModes;

  /// Satellites visibles consolidés à partir de GSV.
  final Map<GnssConstellation, List<GnssSatelliteInfo>> satellitesInView;

  /// Dernier talker rencontré pour une phrase de position.
  final String? talkerId;

  const NmeaGnssFix({
    this.latitude,
    this.longitude,
    this.altitudeMslMeters,
    this.geoidalSeparationMeters,
    this.fixQuality,
    this.fixType,
    this.satellitesUsed,
    this.hdop,
    this.vdop,
    this.pdop,
    this.utc,
    this.speedKnots,
    this.courseTrueDeg,
    this.rmcActive = false,
    this.constellationModes = const <GnssConstellation, GnssMode>{},
    this.satellitesInView =
        const <GnssConstellation, List<GnssSatelliteInfo>>{},
    this.talkerId,
  });

  bool get hasValidPosition =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;

  bool get has3dFix => fixType == 3;

  bool get usesGps => _uses(GnssConstellation.gps);
  bool get usesGlonass => _uses(GnssConstellation.glonass);
  bool get usesGalileo => _uses(GnssConstellation.galileo);
  bool get usesBeidou => _uses(GnssConstellation.beidou);

  bool _uses(GnssConstellation c) {
    final mode = constellationModes[c];
    if (mode != null && mode != GnssMode.noFix && mode != GnssMode.unknown) {
      return true;
    }
    return satellitesInView[c]?.isNotEmpty ?? false;
  }

  NmeaGnssFix copyWith({
    double? latitude,
    double? longitude,
    double? altitudeMslMeters,
    double? geoidalSeparationMeters,
    int? fixQuality,
    int? fixType,
    int? satellitesUsed,
    double? hdop,
    double? vdop,
    double? pdop,
    DateTime? utc,
    double? speedKnots,
    double? courseTrueDeg,
    bool? rmcActive,
    Map<GnssConstellation, GnssMode>? constellationModes,
    Map<GnssConstellation, List<GnssSatelliteInfo>>? satellitesInView,
    String? talkerId,
  }) {
    return NmeaGnssFix(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMslMeters: altitudeMslMeters ?? this.altitudeMslMeters,
      geoidalSeparationMeters:
          geoidalSeparationMeters ?? this.geoidalSeparationMeters,
      fixQuality: fixQuality ?? this.fixQuality,
      fixType: fixType ?? this.fixType,
      satellitesUsed: satellitesUsed ?? this.satellitesUsed,
      hdop: hdop ?? this.hdop,
      vdop: vdop ?? this.vdop,
      pdop: pdop ?? this.pdop,
      utc: utc ?? this.utc,
      speedKnots: speedKnots ?? this.speedKnots,
      courseTrueDeg: courseTrueDeg ?? this.courseTrueDeg,
      rmcActive: rmcActive ?? this.rmcActive,
      constellationModes: constellationModes ?? this.constellationModes,
      satellitesInView: satellitesInView ?? this.satellitesInView,
      talkerId: talkerId ?? this.talkerId,
    );
  }

  @override
  String toString() {
    return 'NmeaGnssFix('
        'lat: $latitude, '
        'lon: $longitude, '
        'altMSL: $altitudeMslMeters, '
        'fixQuality: $fixQuality, '
        'fixType: $fixType, '
        'satUsed: $satellitesUsed, '
        'HDOP: $hdop, '
        'VDOP: $vdop, '
        'PDOP: $pdop, '
        'GPS: $usesGps, '
        'GLONASS: $usesGlonass, '
        'Galileo: $usesGalileo, '
        'BeiDou: $usesBeidou'
        ')';
  }
}

/// Parser NMEA 0183 orienté GNSS multi-constellations.
///
/// Phrases prises en charge :
/// - GGA
/// - GNS
/// - GSA
/// - GSV
/// - RMC
///
/// Talkers reconnus :
/// GP = GPS
/// GL = GLONASS
/// GA = Galileo
/// GB / BD = BeiDou
/// GN = solution GNSS combinée
/// GQ = QZSS
/// GI = NavIC
class Nmea0183Parser {
  Nmea0183Parser({this.requireChecksum = true});

  /// Si true, une phrase sans checksum ou avec checksum invalide est rejetée.
  final bool requireChecksum;

  NmeaGnssFix _fix = const NmeaGnssFix();

  /// Buffer GSV par constellation, le temps d'un cycle multi-phrases.
  final Map<GnssConstellation, _GsvCycle> _gsvCycles =
      <GnssConstellation, _GsvCycle>{};

  NmeaGnssFix get currentFix => _fix;

  void reset() {
    _fix = const NmeaGnssFix();
    _gsvCycles.clear();
  }

  /// Parse une ligne NMEA.
  ///
  /// Retourne le snapshot consolidé après traitement, ou null si :
  /// - la ligne est vide,
  /// - le checksum est invalide,
  /// - la phrase n'est pas prise en charge,
  /// - la phrase est malformée.
  NmeaGnssFix? parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty || !line.startsWith(r'$')) return null;

    final star = line.indexOf('*');
    if (requireChecksum) {
      if (star < 0 || star + 2 >= line.length) return null;
      if (!isChecksumValid(line)) return null;
    } else if (star >= 0 && !isChecksumValid(line)) {
      return null;
    }

    final payload = star >= 0 ? line.substring(1, star) : line.substring(1);
    final fields = payload.split(',');
    if (fields.isEmpty || fields.first.length < 5) return null;

    final id = fields.first.toUpperCase();
    final talker = id.substring(0, 2);
    final sentence = id.substring(2);

    try {
      switch (sentence) {
        case 'GGA':
          _parseGga(fields, talker);
          break;
        case 'GNS':
          _parseGns(fields, talker);
          break;
        case 'GSA':
          _parseGsa(fields, talker);
          break;
        case 'GSV':
          _parseGsv(fields, talker);
          break;
        case 'RMC':
          _parseRmc(fields, talker);
          break;
        default:
          return null;
      }

      return _fix;
    } catch (_) {
      // Une trame malformée ne doit jamais casser le flux GNSS.
      return null;
    }
  }

  void _parseGga(List<String> f, String talker) {
    if (f.length < 10) return;

    final lat = _parseCoordinate(f[2], f[3], isLatitude: true);
    final lon = _parseCoordinate(f[4], f[5], isLatitude: false);
    final quality = _intOrNull(f[6]);
    final sats = _intOrNull(f[7]);
    final hdop = _doubleOrNull(f[8]);
    final alt = _doubleOrNull(f[9]);
    final geoid = f.length > 11 ? _doubleOrNull(f[11]) : null;

    if (lat == null || lon == null) return;

    _fix = _fix.copyWith(
      latitude: lat,
      longitude: lon,
      altitudeMslMeters: alt,
      geoidalSeparationMeters: geoid,
      fixQuality: quality,
      satellitesUsed: sats,
      hdop: hdop,
      talkerId: talker,
    );

    _markTalkerConstellation(talker);
  }

  void _parseGns(List<String> f, String talker) {
    if (f.length < 10) return;

    final lat = _parseCoordinate(f[2], f[3], isLatitude: true);
    final lon = _parseCoordinate(f[4], f[5], isLatitude: false);
    final modeField = f[6].trim().toUpperCase();
    final sats = _intOrNull(f[7]);
    final hdop = _doubleOrNull(f[8]);
    final alt = _doubleOrNull(f[9]);
    final geoid = f.length > 10 ? _doubleOrNull(f[10]) : null;

    final modes = Map<GnssConstellation, GnssMode>.from(
      _fix.constellationModes,
    );

    if (modeField.isNotEmpty) {
      const order = <GnssConstellation>[
        GnssConstellation.gps,
        GnssConstellation.glonass,
        GnssConstellation.galileo,
        GnssConstellation.beidou,
        GnssConstellation.qzss,
        GnssConstellation.navic,
      ];

      for (var i = 0; i < math.min(modeField.length, order.length); i++) {
        modes[order[i]] = _modeFromChar(modeField[i]);
      }
    }

    if (lat != null && lon != null) {
      _fix = _fix.copyWith(
        latitude: lat,
        longitude: lon,
        altitudeMslMeters: alt,
        geoidalSeparationMeters: geoid,
        satellitesUsed: sats,
        hdop: hdop,
        constellationModes: Map.unmodifiable(modes),
        talkerId: talker,
      );
    } else {
      _fix = _fix.copyWith(
        satellitesUsed: sats,
        hdop: hdop,
        constellationModes: Map.unmodifiable(modes),
        talkerId: talker,
      );
    }

    _markTalkerConstellation(talker);
  }

  void _parseGsa(List<String> f, String talker) {
    // Format classique :
    // 0 id, 1 mode M/A, 2 type fix, 3..14 PRN,
    // 15 PDOP, 16 HDOP, 17 VDOP, [18 system id]
    if (f.length < 18) return;

    final fixType = _intOrNull(f[2]);
    final pdop = _doubleOrNull(f[15]);
    final hdop = _doubleOrNull(f[16]);
    final vdop = _doubleOrNull(f[17]);

    _fix = _fix.copyWith(
      fixType: fixType,
      pdop: pdop,
      hdop: hdop,
      vdop: vdop,
      talkerId: talker,
    );

    _markTalkerConstellation(talker);
  }

  void _parseGsv(List<String> f, String talker) {
    if (f.length < 4) return;

    final totalMessages = _intOrNull(f[1]);
    final messageNumber = _intOrNull(f[2]);
    final totalVisible = _intOrNull(f[3]);

    if (totalMessages == null ||
        messageNumber == null ||
        totalMessages <= 0 ||
        messageNumber <= 0) {
      return;
    }

    final constellation = _constellationFromTalker(talker);
    if (constellation == GnssConstellation.unknown) return;

    if (messageNumber == 1 || !_gsvCycles.containsKey(constellation)) {
      _gsvCycles[constellation] = _GsvCycle(
        totalMessages: totalMessages,
        totalVisible: totalVisible ?? 0,
      );
    }

    final cycle = _gsvCycles[constellation]!;
    cycle.totalMessages = totalMessages;
    cycle.totalVisible = totalVisible ?? cycle.totalVisible;

    // Blocs de 4 champs : PRN, élévation, azimut, SNR.
    // Des champs supplémentaires (ex. signal ID) peuvent exister en fin de trame.
    for (var i = 4; i + 3 < f.length; i += 4) {
      final prn = _intOrNull(f[i]);
      if (prn == null) break;

      cycle.satellites.add(
        GnssSatelliteInfo(
          constellation: constellation,
          prn: prn,
          elevationDeg: _intOrNull(f[i + 1]),
          azimuthDeg: _intOrNull(f[i + 2]),
          snrDbHz: _intOrNull(f[i + 3]),
        ),
      );
    }

    if (messageNumber >= totalMessages) {
      final all = Map<GnssConstellation, List<GnssSatelliteInfo>>.from(
        _fix.satellitesInView,
      );

      all[constellation] = List.unmodifiable(cycle.satellites);
      _fix = _fix.copyWith(
        satellitesInView: Map.unmodifiable(all),
        talkerId: talker,
      );

      _gsvCycles.remove(constellation);
    }
  }

  void _parseRmc(List<String> f, String talker) {
    // 0 id
    // 1 UTC
    // 2 status A/V
    // 3 lat
    // 4 N/S
    // 5 lon
    // 6 E/W
    // 7 speed knots
    // 8 course true
    // 9 date ddmmyy
    if (f.length < 10) return;

    final active = f[2].trim().toUpperCase() == 'A';
    final lat = _parseCoordinate(f[3], f[4], isLatitude: true);
    final lon = _parseCoordinate(f[5], f[6], isLatitude: false);
    final speed = _doubleOrNull(f[7]);
    final course = _doubleOrNull(f[8]);
    final utc = _parseUtcDateTime(f[1], f[9]);

    if (active && lat != null && lon != null) {
      _fix = _fix.copyWith(
        latitude: lat,
        longitude: lon,
        utc: utc,
        speedKnots: speed,
        courseTrueDeg: course,
        rmcActive: true,
        talkerId: talker,
      );
    } else {
      _fix = _fix.copyWith(
        utc: utc,
        speedKnots: speed,
        courseTrueDeg: course,
        rmcActive: active,
        talkerId: talker,
      );
    }

    _markTalkerConstellation(talker);
  }

  void _markTalkerConstellation(String talker) {
    final constellation = _constellationFromTalker(talker);
    if (constellation == GnssConstellation.unknown ||
        constellation == GnssConstellation.qzss ||
        constellation == GnssConstellation.navic) {
      return;
    }

    final modes = Map<GnssConstellation, GnssMode>.from(
      _fix.constellationModes,
    );

    // Ne remplace pas un mode GNS plus précis.
    modes.putIfAbsent(constellation, () => GnssMode.autonomous);

    _fix = _fix.copyWith(constellationModes: Map.unmodifiable(modes));
  }

  static GnssConstellation _constellationFromTalker(String talker) {
    switch (talker.toUpperCase()) {
      case 'GP':
        return GnssConstellation.gps;
      case 'GL':
        return GnssConstellation.glonass;
      case 'GA':
        return GnssConstellation.galileo;
      case 'GB':
      case 'BD': // rencontré sur certains équipements BeiDou plus anciens
        return GnssConstellation.beidou;
      case 'GQ':
        return GnssConstellation.qzss;
      case 'GI':
        return GnssConstellation.navic;
      case 'GN':
      default:
        return GnssConstellation.unknown;
    }
  }

  static GnssMode _modeFromChar(String c) {
    switch (c.toUpperCase()) {
      case 'N':
        return GnssMode.noFix;
      case 'A':
        return GnssMode.autonomous;
      case 'D':
        return GnssMode.differential;
      case 'P':
        return GnssMode.precise;
      case 'R':
        return GnssMode.rtkFixed;
      case 'F':
        return GnssMode.rtkFloat;
      case 'E':
        return GnssMode.estimated;
      case 'M':
        return GnssMode.manual;
      case 'S':
        return GnssMode.simulator;
      default:
        return GnssMode.unknown;
    }
  }

  static double? _parseCoordinate(
    String value,
    String hemisphere, {
    required bool isLatitude,
  }) {
    final raw = double.tryParse(value.trim());
    if (raw == null) return null;

    final degreesDigits = isLatitude ? 2 : 3;
    final text = value.trim();
    if (text.length < degreesDigits + 2) return null;

    final degrees = int.tryParse(text.substring(0, degreesDigits));
    final minutes = double.tryParse(text.substring(degreesDigits));
    if (degrees == null || minutes == null || minutes < 0 || minutes >= 60) {
      return null;
    }

    var decimal = degrees + minutes / 60.0;

    final h = hemisphere.trim().toUpperCase();
    if (h == 'S' || h == 'W') decimal = -decimal;

    if (isLatitude && (decimal < -90 || decimal > 90)) return null;
    if (!isLatitude && (decimal < -180 || decimal > 180)) return null;

    return decimal;
  }

  static DateTime? _parseUtcDateTime(String time, String date) {
    final t = time.trim();
    final d = date.trim();

    if (t.length < 6 || d.length != 6) return null;

    final hour = int.tryParse(t.substring(0, 2));
    final minute = int.tryParse(t.substring(2, 4));
    final secondsDouble = double.tryParse(t.substring(4));

    final day = int.tryParse(d.substring(0, 2));
    final month = int.tryParse(d.substring(2, 4));
    final yy = int.tryParse(d.substring(4, 6));

    if (hour == null ||
        minute == null ||
        secondsDouble == null ||
        day == null ||
        month == null ||
        yy == null) {
      return null;
    }

    final second = secondsDouble.floor();
    final millisecond = ((secondsDouble - second) * 1000).round();

    // Convention pratique :
    // 00..79 => 2000..2079
    // 80..99 => 1980..1999
    final year = yy <= 79 ? 2000 + yy : 1900 + yy;

    try {
      return DateTime.utc(year, month, day, hour, minute, second, millisecond);
    } catch (_) {
      return null;
    }
  }

  static int? _intOrNull(String value) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static double? _doubleOrNull(String value) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// Vérifie le checksum XOR NMEA entre '$' et '*'.
  static bool isChecksumValid(String sentence) {
    final line = sentence.trim();
    if (!line.startsWith(r'$')) return false;

    final star = line.indexOf('*');
    if (star < 0 || star + 2 >= line.length) return false;

    var checksum = 0;
    for (var i = 1; i < star; i++) {
      checksum ^= line.codeUnitAt(i);
    }

    final expectedText = line.substring(star + 1).trim();
    if (expectedText.length < 2) return false;

    final expected = int.tryParse(expectedText.substring(0, 2), radix: 16);

    return expected != null && checksum == expected;
  }
}

class _GsvCycle {
  _GsvCycle({required this.totalMessages, required this.totalVisible});

  int totalMessages;
  int totalVisible;
  final List<GnssSatelliteInfo> satellites = <GnssSatelliteInfo>[];
}
