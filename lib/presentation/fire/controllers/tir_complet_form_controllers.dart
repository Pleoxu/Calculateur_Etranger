import 'package:flutter/material.dart';

/// Regroupe les contrôleurs de saisie et les FocusNode de l'écran de tir.
///
/// Cette classe ne contient aucune logique métier. Elle possède uniquement
/// le cycle de vie des objets de formulaire utilisés par l'interface.
class TirCompletFormControllers {
  final zoneCtrl = TextEditingController();
  final xCtrl = TextEditingController();
  final yCtrl = TextEditingController();
  final zCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lonCtrl = TextEditingController();
  final altCtrl = TextEditingController();

  final distCtrl = TextEditingController();
  final azCtrl = TextEditingController();
  final altObjCtrl = TextEditingController();
  final xObjCtrl = TextEditingController();
  final yObjCtrl = TextEditingController();
  final zObjCtrl = TextEditingController();

  final obsXCtrl = TextEditingController();
  final obsYCtrl = TextEditingController();
  final obsZCtrl = TextEditingController();
  final obsDistCtrl = TextEditingController();
  final obsAzCtrl = TextEditingController();
  final obsAltObjCtrl = TextEditingController();
  final obsXObjCtrl = TextEditingController();
  final obsYObjCtrl = TextEditingController();
  final obsZObjCtrl = TextEditingController();

  final latPieceDegCtrl = TextEditingController();
  final deltaAltMetCtrl = TextEditingController();

  // Validation différée : pas de rouge pendant la frappe.
  final zoneFocus = FocusNode();
  final xFocus = FocusNode();
  final yFocus = FocusNode();
  final zFocus = FocusNode();
  final latFocus = FocusNode();
  final lonFocus = FocusNode();
  final altFocus = FocusNode();

  final distFocus = FocusNode();
  final azFocus = FocusNode();
  final altObjFocus = FocusNode();
  final xObjFocus = FocusNode();
  final yObjFocus = FocusNode();
  final zObjFocus = FocusNode();

  void dispose() {
    for (final focus in [
      zoneFocus,
      xFocus,
      yFocus,
      zFocus,
      latFocus,
      lonFocus,
      altFocus,
      distFocus,
      azFocus,
      altObjFocus,
      xObjFocus,
      yObjFocus,
      zObjFocus,
    ]) {
      focus.dispose();
    }

    for (final controller in [
      zoneCtrl,
      xCtrl,
      yCtrl,
      zCtrl,
      latCtrl,
      lonCtrl,
      altCtrl,
      distCtrl,
      azCtrl,
      altObjCtrl,
      xObjCtrl,
      yObjCtrl,
      zObjCtrl,
      latPieceDegCtrl,
      deltaAltMetCtrl,
      obsXCtrl,
      obsYCtrl,
      obsZCtrl,
      obsDistCtrl,
      obsAzCtrl,
      obsAltObjCtrl,
      obsXObjCtrl,
      obsYObjCtrl,
      obsZObjCtrl,
    ]) {
      controller.dispose();
    }
  }
}
