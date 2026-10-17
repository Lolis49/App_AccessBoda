
class ImportResult {
  final int inserted;
  final int updated;
  final int unchanged;

  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.unchanged,
  });
}
