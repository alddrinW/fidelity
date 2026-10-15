import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelity_app/features/admin/data/admin_date_filter.dart';
import 'package:fidelity_app/features/admin/data/admin_repository.dart';

void main() {
  group('AdminDashboardStats.fromJson', () {
    test('aplana las métricas anidadas del backend', () {
      final stats = AdminDashboardStats.fromJson({
        'users': {'total': 10, 'clients': 8, 'businessOwners': 1, 'admins': 1},
        'businesses': {'total': 5, 'active': 3, 'inactive': 2},
        'scans': {'total': 40, 'approved': 30, 'pending': 4},
        'rewards': {'total': 9, 'pending': 4, 'claimed': 5},
        'transfers': {'total': 1},
      });

      expect(stats.clients, 8);
      expect(stats.businesses, 5);
      expect(stats.inactiveBusinesses, 2);
      expect(stats.scans, 40);
      expect(stats.pendingScans, 4);
      expect(stats.rewards, 9);
      expect(stats.claimedRewards, 5);
    });

    test('una respuesta vacía o incompleta da ceros', () {
      final stats = AdminDashboardStats.fromJson({'businesses': 'raro'});

      expect(stats.businesses, 0);
      expect(stats.clients, 0);
      expect(stats.rewards, 0);
    });
  });

  group('AdminDateRange', () {
    test('"todas" no limita el rango', () {
      expect(AdminDateRange.resolve(AdminDateFilter.all), isNull);
    });

    test('"hoy" cubre exactamente un día de Ecuador', () {
      final range = AdminDateRange.resolve(AdminDateFilter.today)!;

      expect(range.end.difference(range.start), const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
      expect(range.start.hour, 5); // 00:00 en Ecuador = 05:00 UTC
    });

    test('un rango personalizado incluye el último día completo', () {
      final range = AdminDateRange.resolve(
        AdminDateFilter.custom,
        custom: DateTimeRange(start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 2)),
      )!;

      expect(range.start, DateTime.utc(2026, 3, 1, 5));
      expect(range.end, DateTime.utc(2026, 3, 3, 4, 59, 59, 999));
    });

    test('contains respeta los límites y convierte a UTC', () {
      final range = AdminDateRange(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 31));

      expect(range.contains(DateTime.utc(2026, 1, 1)), isTrue);
      expect(range.contains(DateTime.utc(2026, 1, 31)), isTrue);
      expect(range.contains(DateTime.utc(2025, 12, 31, 23, 59)), isFalse);
      expect(range.contains(DateTime.utc(2026, 2, 1)), isFalse);
    });
  });
}
