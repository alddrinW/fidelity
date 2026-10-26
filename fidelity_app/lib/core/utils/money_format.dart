/// Centavos como dólares: `25` -> `$0.25`, `1234` -> `$12.34`.
String centsText(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

/// Lo que escribe el dueño ("0.25", "1,5", "$2") como centavos, o `null` si no es un monto.
int? centsFromInput(String raw) {
  final cleaned = raw.trim().replaceAll('\$', '').replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}
