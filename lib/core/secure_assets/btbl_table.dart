class BtblRow {
  const BtblRow({
    required this.distance,
    required this.denivelee,
    required this.correctionSite,
    required this.niveauMeteo,
    required this.tirMontagne,
  });

  final int distance;
  final int denivelee;
  final int correctionSite;
  final int niveauMeteo;
  final bool tirMontagne;
}

class BtblTable {
  const BtblTable({required this.id, required this.rows});

  final String id;
  final List<BtblRow> rows;
}
