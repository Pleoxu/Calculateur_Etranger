abstract interface class SelectionDataRow {
  double get distance;
  double get criterionValue;
  bool get alternateBranch;
}

abstract interface class SelectionDataTable<R extends SelectionDataRow> {
  List<R> get rows;
}
