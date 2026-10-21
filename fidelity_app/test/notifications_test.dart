import 'package:fidelity_app/features/notifications/data/notifications_repository.dart';
import 'package:fidelity_app/features/notifications/notifications_screen.dart';
import 'package:fidelity_app/features/notifications/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

class _FakeNotificationsRepository extends NotificationsRepository {
  List<AppNotification> items;
  int unread;
  final List<String> readIds = [];
  int readAllCalls = 0;
  final List<DateTime?> listCalls = [];
  bool failList = false;

  _FakeNotificationsRepository(this.items, {this.unread = 0});

  @override
  Future<List<AppNotification>> list({DateTime? before, int limit = 30}) async {
    listCalls.add(before);
    if (failList) throw Exception('sin red');
    if (before == null) return items.take(limit).toList();
    return items.where((n) => n.createdAt.isBefore(before)).take(limit).toList();
  }

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<void> markRead(String id) async => readIds.add(id);

  @override
  Future<void> markAllRead() async => readAllCalls++;
}

AppNotification note(
  String id, {
  String type = 'general',
  String title = 'Título',
  String body = 'Texto',
  bool read = false,
  DateTime? at,
  Map<String, dynamic> data = const {},
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      read: read,
      data: data,
      createdAt: at ?? DateTime.now(),
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppNotification', () {
    test('lee lo que manda el servidor', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'type': 'gift_card',
        'title': 'Café te regaló una gift card',
        'body': '20% de descuento',
        'data': {'route': '/my_gifts', 'campaign_id': 'c1'},
        'read': false,
        'createdAt': '2026-10-16T15:00:00.000Z',
      });

      expect(n.id, 'n1');
      expect(n.type, 'gift_card');
      expect(n.read, isFalse);
      expect(n.route, '/my_gifts');
      expect(n.data['campaign_id'], 'c1');
    });

    test('datos faltantes no rompen la bandeja', () {
      final n = AppNotification.fromJson({'id': 'n2'});

      expect(n.type, 'general');
      expect(n.title, '');
      expect(n.data, isEmpty);
      expect(n.route, isNull);
    });

    test('asRead conserva todo y solo cambia el estado', () {
      final n = note('n1', title: 'Hola').asRead();

      expect(n.read, isTrue);
      expect(n.title, 'Hola');
    });

    test('el icono sale del tipo y, si no, de la ruta', () {
      expect(note('1', type: 'gift_card').icon, Icons.card_giftcard_rounded);
      expect(note('2', type: 'claim_redeemed').icon, Icons.check_circle_outline_rounded);
      expect(note('3', data: {'route': '/points_approved'}).icon, Icons.stars_rounded);
      expect(note('4', data: {'route': '/business_dashboard/pending'}).icon, Icons.pending_actions_rounded);
      expect(note('5').icon, Icons.notifications_none_rounded);
    });
  });

  group('notificationDayLabel', () {
    final now = DateTime(2026, 10, 16, 15);

    test('hoy, ayer y fecha', () {
      expect(notificationDayLabel(DateTime(2026, 10, 16, 8), now), 'Hoy');
      expect(notificationDayLabel(DateTime(2026, 10, 15, 23, 59), now), 'Ayer');
      expect(notificationDayLabel(DateTime(2026, 10, 3, 10), now), '03/10/2026');
    });
  });

  group('NotificationsScreen', () {
    late _FakeNotificationsRepository repo;

    ProviderContainer? current;

    /// Desmonta la pantalla y libera el contenedor (cancela el temporizador del contador).
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      current?.dispose();
      current = null;
    }

    Future<ProviderContainer> open(
      WidgetTester tester,
      _FakeNotificationsRepository repository, {
      void Function(AppNotification)? onOpen,
    }) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = repository;

      final container = ProviderContainer(
        overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
      );
      current = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: spanishApp(NotificationsScreen(onOpen: onOpen)),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('agrupa los movimientos por día y marca los no leídos', (tester) async {
      final now = DateTime.now();
      await open(
        tester,
        _FakeNotificationsRepository([
          note('1', title: 'Punto aprobado', at: now),
          note('2', title: 'Premio alcanzado', at: now.subtract(const Duration(hours: 1)), read: true),
          note('3', title: 'Gift card cancelada', at: now.subtract(const Duration(days: 1))),
        ], unread: 2),
      );

      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('Punto aprobado'), findsOneWidget);
      expect(find.text('Premio alcanzado'), findsOneWidget);
      expect(find.text('Gift card cancelada'), findsOneWidget);
      // Dos no leídas: dos puntos.
      expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
      await close(tester);
    });

    testWidgets('tocar una no leída la marca como leída y abre su destino', (tester) async {
      AppNotification? opened;
      final container = await open(
        tester,
        _FakeNotificationsRepository([
          note('1', title: 'Te llegó una gift card', type: 'gift_card', data: {'route': '/my_gifts'}),
        ], unread: 1),
        onOpen: (n) => opened = n,
      );
      container.read(unreadCountProvider.notifier).set(1);

      await tester.tap(find.text('Te llegó una gift card'));
      await tester.pumpAndSettle();

      expect(repo.readIds, ['1']);
      expect(opened?.id, '1');
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(container.read(unreadCountProvider), 0);
      await close(tester);
    });

    testWidgets('tocar una ya leída no vuelve a marcarla', (tester) async {
      await open(
        tester,
        _FakeNotificationsRepository([note('1', title: 'Vieja', read: true)]),
      );

      await tester.tap(find.text('Vieja'));
      await tester.pumpAndSettle();

      expect(repo.readIds, isEmpty);
      await close(tester);
    });

    testWidgets('marcar todas como leídas', (tester) async {
      final container = await open(
        tester,
        _FakeNotificationsRepository([note('1'), note('2')], unread: 2),
      );
      container.read(unreadCountProvider.notifier).set(2);

      await tester.tap(find.byTooltip('Marcar todas como leídas'));
      await tester.pumpAndSettle();

      expect(repo.readAllCalls, 1);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(container.read(unreadCountProvider), 0);
      // Ya no queda nada por marcar: el botón desaparece.
      expect(find.byTooltip('Marcar todas como leídas'), findsNothing);
      await close(tester);
    });

    testWidgets('sin movimientos muestra el estado vacío', (tester) async {
      await open(tester, _FakeNotificationsRepository([]));

      expect(find.text('TODO AL DÍA'), findsOneWidget);
      await close(tester);
    });

    testWidgets('si falla la carga avisa y permite reintentar', (tester) async {
      final failing = _FakeNotificationsRepository([])..failList = true;
      await open(tester, failing);

      expect(find.text('ALGO SALIÓ MAL'), findsOneWidget);

      failing.failList = false;
      failing.items = [note('1', title: 'Ya cargó')];
      await tester.tap(find.text('REINTENTAR'));
      await tester.pumpAndSettle();

      expect(find.text('Ya cargó'), findsOneWidget);
      await close(tester);
    });

    testWidgets('al llegar al final pide la página siguiente', (tester) async {
      final now = DateTime.now();
      final items = [
        for (var i = 0; i < 35; i++)
          note('n$i', title: 'Mov $i', at: now.subtract(Duration(minutes: i))),
      ];
      await open(tester, _FakeNotificationsRepository(items));

      expect(repo.listCalls, hasLength(1));
      expect(repo.listCalls.first, isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -20000));
      await tester.pumpAndSettle();

      expect(repo.listCalls.length, 2);
      expect(repo.listCalls.last, isNotNull);
      await tester.scrollUntilVisible(
        find.text('Mov 34'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(); // deja terminar las animaciones de entrada
      expect(find.text('Mov 34'), findsOneWidget);
      await close(tester);
    });
  });

  group('NotificationBell', () {
    Future<void> pumpBell(WidgetTester tester, _FakeNotificationsRepository repo) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const Scaffold(body: Center(child: NotificationBell()))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra cuántas hay sin leer', (tester) async {
      await pumpBell(tester, _FakeNotificationsRepository([], unread: 5));

      expect(find.text('5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sin pendientes no muestra número', (tester) async {
      await pumpBell(tester, _FakeNotificationsRepository([], unread: 0));

      expect(find.text('0'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con más de 99 muestra 99+', (tester) async {
      await pumpBell(tester, _FakeNotificationsRepository([], unread: 250));

      expect(find.text('99+'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('al tocarla abre la bandeja', (tester) async {
      await pumpBell(tester, _FakeNotificationsRepository([note('1', title: 'Hola mundo')], unread: 1));

      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Hola mundo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
