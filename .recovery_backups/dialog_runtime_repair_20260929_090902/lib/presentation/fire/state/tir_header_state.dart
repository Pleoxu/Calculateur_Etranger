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
                systeme: Systeme.mo81M252,
                typeTir: TypeTir.appui,
                mo81MunitionLabel: 'M821A1',
                m252MunitionFamily: _firstM252Family(),
                dark: true,
              ),
        );

  static M252MunitionFamily? _firstM252Family() {
    if (M252MunitionFamily.values.isNotEmpty) {
      return M252MunitionFamily.values.first;
    }
    return null;
  }

  M252MunitionFamily? _parseM252Family(String? label) {
    if (label == null) return null;
    final normalized = label.replaceAll(' ', '').toLowerCase();
    for (final value in M252MunitionFamily.values) {
      if (value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    return _firstM252Family();
  }

  void setSysteme(Systeme systeme) {
    if (state.systeme == systeme) return;
    state = state.copyWith(
      systeme: systeme,
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

  void setMo81Munition(String? label) {
    final family = _parseM252Family(label);
    state = state.copyWith(
      mo81MunitionLabel: label,
      nullifyMo81MunitionLabel: label == null,
      m252MunitionFamily: family,
      nullifyM252MunitionFamily: family == null,
    );
  }

  void setDark(bool dark) {
    state = state.copyWith(dark: dark);
  }
}

final tirHeaderProvider =
    StateNotifierProvider<TirHeaderNotifier, TirHeaderState>((ref) {
  return TirHeaderNotifier();
});
