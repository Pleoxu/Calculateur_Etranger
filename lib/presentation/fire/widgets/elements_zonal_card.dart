import 'package:flutter/material.dart';
import 'package:calculateur_etranger/domain/fire/models/tir_complet_output.dart';
import 'package:calculateur_etranger/presentation/fire/widgets/elements_tir_card.dart';

class ElementsZonalCard extends StatelessWidget {
  final TirCompletOutput output;

  const ElementsZonalCard({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return ElementsTirCard(output: output, title: 'Zonal fire elements');
  }
}
