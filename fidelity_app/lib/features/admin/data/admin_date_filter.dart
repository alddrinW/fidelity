import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';

/// Periodos de tiempo que ofrece el panel de administración. Es el único
/// filtro de fechas del panel (antes cada pantalla tenía su propia copia).
enum AdminDateFilter {
  all('Todas'),
  today('Hoy'),
  week('Semana'),
  month('Mes'),
  year('Año'),
  custom('Personalizado');

  final String label;

  const AdminDateFilter(this.label);
}

/// Rango de fechas en UTC, alineado al día de Ecuador (UTC-5).
class AdminDateRange {
  final DateTime start;
  final DateTime end;

  const AdminDateRange(this.start, this.end);

  bool contains(DateTime date) {
    final utc = date.toUtc();
    return !utc.isBefore(start) && !utc.isAfter(end);
  }

  /// Resuelve un filtro a un rango. `all` devuelve null (sin límite). Un
  /// `custom` sin fechas elegidas equivale a "hoy".
  static AdminDateRange? resolve(
    AdminDateFilter filter, {
    DateTimeRange? custom,
  }) {
    final startOfDay = EcuadorDateUtils.getStartOfDayEcuadorUtc();
    final nowUtc = DateTime.now().toUtc();

    switch (filter) {
      case AdminDateFilter.all:
        return null;
      case AdminDateFilter.today:
        return AdminDateRange(startOfDay, EcuadorDateUtils.getEndOfDayEcuadorUtc());
      case AdminDateFilter.week:
        return AdminDateRange(startOfDay.subtract(const Duration(days: 7)), nowUtc);
      case AdminDateFilter.month:
        return AdminDateRange(startOfDay.subtract(const Duration(days: 30)), nowUtc);
      case AdminDateFilter.year:
        return AdminDateRange(startOfDay.subtract(const Duration(days: 365)), nowUtc);
      case AdminDateFilter.custom:
        if (custom == null) {
          return AdminDateRange(startOfDay, EcuadorDateUtils.getEndOfDayEcuadorUtc());
        }
        // Las 00:00 de Ecuador son las 05:00 UTC.
        final start = DateTime.utc(
          custom.start.year,
          custom.start.month,
          custom.start.day,
          5,
        );
        final end = DateTime.utc(
          custom.end.year,
          custom.end.month,
          custom.end.day,
          5,
        ).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return AdminDateRange(start, end);
    }
  }
}

String formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
