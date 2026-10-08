// lib/presentation/fire/widgets/positions_pieces_dialog.dart

import 'package:flutter/material.dart';

import 'package:calculateur_etranger/presentation/theme/tir_tokens.dart';

import 'package:calculateur_etranger/services/radio/position_repository.dart';
import 'package:calculateur_etranger/services/radio/radio_import_service.dart';
import 'package:calculateur_etranger/services/radio/radio_position_mapper.dart';
import 'package:calculateur_etranger/services/simulation/radio_position_simulator.dart';

class PiecePositionDraft {
  final String nom;
  final double? distanceM;
  final double? azimutMil;

  /// Différence d'altitude par rapport à la PD.
  final double? deltaZPd;

  /// Altitude absolue historique conservée pour compatibilité.
  final double? zPS;

  const PiecePositionDraft({
    required this.nom,
    this.distanceM,
    this.azimutMil,
    this.deltaZPd,
    this.zPS,
  });

  PiecePositionDraft copyWith({
    String? nom,
    double? distanceM,
    double? azimutMil,
    double? deltaZPd,
    double? zPS,
    bool clearDistanceM = false,
    bool clearAzimutMil = false,
    bool clearDeltaZPd = false,
    bool clearZPS = false,
  }) {
    return PiecePositionDraft(
      nom: nom ?? this.nom,
      distanceM: clearDistanceM ? null : (distanceM ?? this.distanceM),
      azimutMil: clearAzimutMil ? null : (azimutMil ?? this.azimutMil),
      deltaZPd: clearDeltaZPd ? null : (deltaZPd ?? this.deltaZPd),
      zPS: clearZPS ? null : (zPS ?? this.zPS),
    );
  }
}

class PositionsPiecesDialog extends StatefulWidget {
  final bool dark;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color mint;
  final List<PiecePositionDraft> initial;

  const PositionsPiecesDialog({
    super.key,
    required this.dark,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.mint,
    required this.initial,
  });

  static Future<List<PiecePositionDraft>?> show(
    BuildContext context, {
    required bool dark,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color mint,
    required List<PiecePositionDraft> initial,
  }) {
    // Plein ecran volontaire : sur iPhone, le pave numerique masque les
    // derniers champs et les boutons des dialogues classiques. Ici les boutons
    // Annuler / OK restent dans l'AppBar, donc toujours accessibles.
    return Navigator.of(
      context,
      rootNavigator: false,
    ).push<List<PiecePositionDraft>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PositionsPiecesDialog(
          dark: dark,
          surface: surface,
          border: border,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          mint: mint,
          initial: initial,
        ),
      ),
    );
  }

  @override
  State<PositionsPiecesDialog> createState() => _PositionsPiecesDialogState();
}

class _PositionsPiecesDialogState extends State<PositionsPiecesDialog> {
  late List<PiecePositionDraft> _draft;
  late List<TextEditingController> _distCtrls;
  late List<TextEditingController> _azCtrls;
  late List<TextEditingController> _deltaZCtrls;

  bool _radioPulse = false;
  bool _radioImporting = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial.map((e) => e).toList();
    _rebuildControllersFromDraft(disposeOld: false);
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _distCtrls) {
      c.dispose();
    }
    for (final c in _azCtrls) {
      c.dispose();
    }
    for (final c in _deltaZCtrls) {
      c.dispose();
    }
  }

  void _rebuildControllersFromDraft({bool disposeOld = true}) {
    if (disposeOld) {
      _disposeControllers();
    }

    _distCtrls = _draft
        .map(
          (p) => TextEditingController(
            text: p.distanceM == null ? '' : p.distanceM!.toStringAsFixed(0),
          ),
        )
        .toList();

    _azCtrls = _draft
        .map(
          (p) => TextEditingController(
            text: p.azimutMil == null ? '' : p.azimutMil!.toStringAsFixed(0),
          ),
        )
        .toList();

    _deltaZCtrls = _draft
        .map(
          (p) => TextEditingController(
            text: p.deltaZPd == null ? '' : p.deltaZPd!.toStringAsFixed(0),
          ),
        )
        .toList();
  }

  double? _parseRequiredNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  double? _parseOptionalNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _importRadioPositions() async {
    if (_radioImporting) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _radioImporting = true;
    });

    final service = RadioImportService(
      simulator: RadioPositionSimulator(),
      repository: PositionRepository(),
      mapper: const RadioPositionMapper(),
    );

    try {
      final pieces = await service.importSimulation();

      if (!mounted) return;

      setState(() {
        final byName = {for (final p in pieces) p.nom.trim().toUpperCase(): p};

        _draft = _draft.map((existing) {
          final radio = byName[existing.nom.trim().toUpperCase()];
          if (radio == null) return existing;

          return PiecePositionDraft(
            nom: existing.nom,
            distanceM: radio.distanceM,
            azimutMil: radio.azimutMil,
            deltaZPd: existing.deltaZPd,
            zPS: radio.zPS,
          );
        }).toList();

        _rebuildControllersFromDraft();

        _radioPulse = true;
        _radioImporting = false;
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _radioPulse = false;
        });
      });
    } catch (e) {
      debugPrint('[RADIO IMPORT ERROR] $e');

      if (!mounted) return;

      setState(() {
        _radioPulse = false;
        _radioImporting = false;
      });
    } finally {
      await service.dispose();
    }
  }

  void _submitOk() {
    FocusScope.of(context).unfocus();

    final out = <PiecePositionDraft>[];

    for (int i = 0; i < _draft.length; i++) {
      final distance = _parseRequiredNum(_distCtrls[i].text);
      final azimut = _parseRequiredNum(_azCtrls[i].text);

      if (distance == null || azimut == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_draft[i].nom} : renseigner la distance et l\'azimut avant validation.',
            ),
          ),
        );
        return;
      }

      out.add(
        PiecePositionDraft(
          nom: _draft[i].nom,
          distanceM: distance,
          azimutMil: azimut,
          deltaZPd: _parseOptionalNum(_deltaZCtrls[i].text),
          zPS: _draft[i].zPS,
        ),
      );
    }

    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.dark ? const Color(0xFF0E0F12) : const Color(0xFFF4F5F7);
    final fieldFill = widget.dark ? const Color(0xFF111318) : Colors.white;

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: fieldFill,
          labelStyle: TextStyle(color: widget.textSecondary),
          floatingLabelStyle: TextStyle(color: widget.textSecondary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TirRadius.m),
            borderSide: BorderSide(color: widget.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TirRadius.m),
            borderSide: const BorderSide(
              color: TirColors.confirmForeground,
              width: 1.4,
            ),
          ),
        );

    Widget numberField({
      required TextEditingController controller,
      required String label,
      TextInputAction action = TextInputAction.next,
    }) {
      return TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        textInputAction: action,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        cursorColor: widget.textPrimary,
        style: TextStyle(color: widget.textPrimary),
        decoration: deco(label),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: widget.textPrimary,
        elevation: 0,
        title: const Text('Positions PS'),
        leading: IconButton(
          tooltip: 'Annuler',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            tooltip: 'Masquer le clavier',
            onPressed: () => FocusScope.of(context).unfocus(),
            icon: const Icon(Icons.keyboard_hide_outlined),
          ),
          IconButton(
            tooltip: 'Transmission radio',
            onPressed: _radioImporting ? null : _importRadioPositions,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                _radioImporting ? Icons.sync : Icons.wifi_tethering,
                key: ValueKey('${_radioPulse}_$_radioImporting'),
                color: _radioPulse
                    ? TirColors.confirmForeground
                    : widget.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _submitOk,
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: TirSpacing.s),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          itemCount: _draft.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Position des pièces secondaires',
                    style: TextStyle(
                      color: widget.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Renseigner chaque PS par rapport à la pièce directrice (PD).',
                    style: TextStyle(color: widget.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: TirSpacing.m),
                  Divider(color: widget.border),
                ],
              );
            }

            if (index == _draft.length + 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: FilledButton(
                  onPressed: _submitOk,
                  style: FilledButton.styleFrom(
                    backgroundColor: TirColors.confirmBackground,
                    foregroundColor: TirColors.confirmForeground,
                    minimumSize: const Size.fromHeight(TirSizes.actionHeight),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: const Text('Valider'),
                ),
              );
            }

            final i = index - 1;
            final isLast = i == _draft.length - 1;

            return Card(
              color: widget.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TirRadius.l),
                side: BorderSide(color: widget.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(TirSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _draft[i].nom,
                      style: TextStyle(
                        color: widget.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    numberField(
                      controller: _distCtrls[i],
                      label: 'Distance / PD (m)',
                    ),
                    const SizedBox(height: 10),
                    numberField(
                      controller: _azCtrls[i],
                      label: 'Azimut / PD (mil)',
                    ),
                    const SizedBox(height: 10),
                    numberField(
                      controller: _deltaZCtrls[i],
                      label: 'ΔZ / PD (m)',
                      action:
                          isLast ? TextInputAction.done : TextInputAction.next,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
