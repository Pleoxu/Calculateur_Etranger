import 'package:flutter/material.dart';

enum PowderTemperatureUnit { celsius, fahrenheit }

extension PowderTemperatureUnitX on PowderTemperatureUnit {
  String get symbol => this == PowderTemperatureUnit.celsius ? '°C' : '°F';

  double fromCelsius(double valueC) => switch (this) {
        PowderTemperatureUnit.celsius => valueC,
        PowderTemperatureUnit.fahrenheit => valueC * 9.0 / 5.0 + 32.0,
      };

  double toCelsius(double value) => switch (this) {
        PowderTemperatureUnit.celsius => value,
        PowderTemperatureUnit.fahrenheit => (value - 32.0) * 5.0 / 9.0,
      };
}

/// Captures only the temperature required by a MO81 cartridge-temperature
/// correction. The ballistic reference temperature is displayed but cannot be
/// changed: it belongs to the selected ammunition table, not to the operator.
Future<double?> showMo81PowderTemperatureDialog({
  required BuildContext context,
  required bool dark,
  required String charge,
  required double referenceTemperatureC,
  required double initialTemperatureC,
  PowderTemperatureUnit initialUnit = PowderTemperatureUnit.celsius,
}) async {
  var unit = initialUnit;
  var currentTemperatureC = initialTemperatureC;
  String? errorText;

  final result = await showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final surface =
              dark ? const Color(0xFF101318) : const Color(0xFFF8F9FB);
          final border =
              dark ? const Color(0xFF353941) : const Color(0xFFD7DBE0);
          final textPrimary =
              dark ? const Color(0xFFF5F5F6) : const Color(0xFF17191D);
          final textSecondary =
              dark ? const Color(0xFFC5C7CC) : const Color(0xFF5D626B);
          final accent = const Color(0xFF7F9C8F);
          final inputFill = dark ? const Color(0xFF11141A) : Colors.white;
          final currentCtrl = TextEditingController(
            text: _formatTemperature(unit.fromCelsius(currentTemperatureC)),
          );

          InputDecoration fieldDecoration({
            required String label,
            required String suffix,
            String? helper,
            String? error,
          }) {
            return InputDecoration(
              labelText: label,
              suffixText: suffix,
              helperText: helper,
              errorText: error,
              filled: true,
              fillColor: inputFill,
              labelStyle: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              suffixStyle: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: border, width: 1.4),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: accent, width: 1.7),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: border, width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.7,
                ),
              ),
            );
          }

          void updateTemperature(String text) {
            final raw = double.tryParse(text.trim().replaceAll(',', '.'));
            if (raw == null) return;
            currentTemperatureC = unit.toCelsius(raw);
          }

          void submit() {
            final raw = double.tryParse(
              currentCtrl.text.trim().replaceAll(',', '.'),
            );
            if (raw == null) {
              setState(() => errorText = 'Enter a numeric temperature.');
              return;
            }

            final temperatureC = unit.toCelsius(raw);
            if (!temperatureC.isFinite ||
                temperatureC < -40.0 ||
                temperatureC > 60.0) {
              setState(() {
                errorText =
                    'Expected -40 to +60 °C (${_formatTemperature(unit.fromCelsius(-40))} to '
                    '${_formatTemperature(unit.fromCelsius(60))} ${unit.symbol}).';
              });
              return;
            }
            Navigator.of(dialogContext).pop(temperatureC);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.fromLTRB(36, 32, 36, 30),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: border, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: Offset(0, 12),
                      color: Color(0x55000000),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Powder temperature',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Charge $charge',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<PowderTemperatureUnit>(
                      segments: const [
                        ButtonSegment(
                          value: PowderTemperatureUnit.celsius,
                          label: Text('°C'),
                        ),
                        ButtonSegment(
                          value: PowderTemperatureUnit.fahrenheit,
                          label: Text('°F'),
                        ),
                      ],
                      selected: <PowderTemperatureUnit>{unit},
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        if (next == unit) return;
                        setState(() {
                          unit = next;
                          errorText = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: _formatTemperature(
                          unit.fromCelsius(referenceTemperatureC),
                        ),
                      ),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: fieldDecoration(
                        label: 'Reference powder temperature',
                        suffix: unit.symbol,
                        helper: unit == PowderTemperatureUnit.celsius
                            ? '${_formatTemperature(PowderTemperatureUnit.fahrenheit.fromCelsius(referenceTemperatureC))} °F reference'
                            : '${_formatTemperature(PowderTemperatureUnit.celsius.fromCelsius(referenceTemperatureC))} °C reference',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: currentCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: fieldDecoration(
                        label: 'Current powder temperature',
                        suffix: unit.symbol,
                        error: errorText,
                      ),
                      onChanged: (value) {
                        updateTemperature(value);
                        if (errorText != null) setState(() => errorText = null);
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: BorderSide(color: border, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: dark
                                    ? const Color(0xFF2B2F35)
                                    : const Color(0xFFE1E4E8),
                                foregroundColor: dark
                                    ? const Color(0xFFF2F3F4)
                                    : Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return result;
}

String _formatTemperature(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
