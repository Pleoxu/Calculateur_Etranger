// lib/presentation/fire/state/tir_header_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/models/calcul_data.dart';

class TirHeaderState {
  final Systeme systeme;
  final TypeTir typeTir;
  final TypeMunition? typeMunition;
  final String? mo81MunitionLabel;
  final M252MunitionFamily? m252MunitionFamily;
  final bool dark;

  const TirHeaderState({
    required this.systeme,
    required this.typeTir,
    this.typeMunition,
    this.mo81MunitionLabel,
    this.m252MunitionFamily,
    this.dark = true,
  });

  TirHeaderState copyWith({
    Systeme? systeme,
    TypeTir? typeTir,
    TypeMunition? typeMunition,
    bool nullifyTypeMunition = false,
    String? mo81MunitionLabel,
    bool nullifyMo81MunitionLabel = false,
    M252MunitionFamily? m252MunitionFamily,
    bool nullifyM252MunitionFamily = false,
    bool? dark,
  }) {
    return TirHeaderState(
      systeme: systeme ?? this.systeme,
      typeTir: typeTir ?? this.typeTir,
      typeMunition:
          nullifyTypeMunition ? null : (typeMunition ?? this.typeMunition),
      mo81MunitionLabel: nullifyMo81MunitionLabel
          ? null
          : (mo81MunitionLabel ?? this.mo81MunitionLabel),
      m252MunitionFamily: nullifyM252MunitionFamily
          ? null
          : (m252MunitionFamily ?? this.m252MunitionFamily),
      dark: dark ?? this.dark,
    );
  }
}

class TirHeaderNotifier extends StateNotifier<TirHeaderState> {
  TirHeaderNotifier([TirHeaderState? initialState])
      : super(
          initialState ??
              TirHeaderState(
                // Aligner l'en-tête initial sur TirCompletState. Le moteur et
                // le formulaire démarrent tous deux sur CAESAR, système dont
                // les fonctions de tir sont disponibles.
                systeme: Systeme.caesar,
                typeTir: TypeTir.appui,
                dark: true,
              ),
        );

  static M252MunitionFamily? _firstM252Family() {
    // FT 81-AR-2 Part 6 applies CH0–CH4 to M821A1/M734 and M821A2/M734A1.
    // M821A1 is the first visible HE cartridge; its charge follows range.
    return M252MunitionFamily.m821a1;
  }

  static const Map<String, M252MunitionFamily> _m252FamiliesByLabel =
      <String, M252MunitionFamily>{
    // Compatibility with a stale pre-Part-6 UI label. The visible catalogue
    // exposes M821A1/M821A2; a legacy M821 label is normalized to M821A1.
    'M821': M252MunitionFamily.m821a1,
    'M821A1': M252MunitionFamily.m821a1,
    'M821A2': M252MunitionFamily.m821a2,
    'M889': M252MunitionFamily.m889,
    'M889A1': M252MunitionFamily.m889a1,
    'TPM879': M252MunitionFamily.tpM879,
    'RPM819': M252MunitionFamily.rpM819,
    'ILLM853A1': M252MunitionFamily.illM853a1,
  };

  M252MunitionFamily? _parseM252Family(String? label) {
    if (label == null) return null;
    final normalized = label.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return _m252FamiliesByLabel[normalized] ?? _firstM252Family();
  }

  void setSysteme(Systeme systeme) {
    // Re-selecting the unified M252 button starts a new M252 selection. A
    // previous CH3 chip (for example after hot reload) must not override the
    // M821/M734 CH0 default at 300 m.
    if (state.systeme == systeme && systeme != Systeme.mo81M252) return;
    final availableTypes = systeme.typesDisponibles;
    final typeTir = systeme == Systeme.mo81M252
        ? TypeTir.appui
        : (availableTypes.contains(state.typeTir)
            ? state.typeTir
            : availableTypes.first);
    state = state.copyWith(
      systeme: systeme,
      typeTir: typeTir,
      nullifyTypeMunition: true,
      mo81MunitionLabel: systeme == Systeme.mo81M252 ? 'M821A1' : null,
      nullifyMo81MunitionLabel: systeme != Systeme.mo81M252,
      m252MunitionFamily:
          systeme == Systeme.mo81M252 ? _firstM252Family() : null,
      nullifyM252MunitionFamily: systeme != Systeme.mo81M252,
    );
  }

  void setTypeTir(TypeTir typeTir) {
    if (state.typeTir == typeTir) return;
    state = state.copyWith(typeTir: typeTir);
  }

  void setTypeMunition(TypeMunition? munition) {
    state = state.copyWith(
      typeMunition: munition,
      nullifyTypeMunition: munition == null,
    );
  }

  M252MunitionFamily? setMo81Munition(String? label) {
    final family = _parseM252Family(label);
    state = state.copyWith(
      mo81MunitionLabel: label,
      nullifyMo81MunitionLabel: label == null,
      m252MunitionFamily: family,
      nullifyM252MunitionFamily: family == null,
    );
    return family;
  }

  void setDark(bool dark) {
    state = state.copyWith(dark: dark);
  }
}

final tirHeaderProvider =
    StateNotifierProvider<TirHeaderNotifier, TirHeaderState>((ref) {
  return TirHeaderNotifier();
});
