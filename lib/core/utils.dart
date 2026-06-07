// lib/core/utils.dart
// Shared utility functions used across the app.

/// Parse any dynamic value to int safely.
int parseInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Parse any dynamic value to double safely.
double? parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
