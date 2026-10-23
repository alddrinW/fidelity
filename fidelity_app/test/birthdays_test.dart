import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:fidelity_app/core/widgets/birth_date_field.dart';
import 'package:fidelity_app/core/services/push_notification_service.dart';
import 'package:fidelity_app/features/birthdays/birthday_gift_screen.dart';
import 'package:fidelity_app/main.dart' show globalNavigatorKey;
import 'package:fidelity_app/features/birthdays/data/birthdays_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart';
import 'package:fidelity_app/features/campaigns/gift_cards_tab.dart';
import 'package:fidelity_app/features/campaigns/widgets/birthday_art.dart';
import 'package:fidelity_app/features/campaigns/widgets/gift_card_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

BirthdayItem _item(
  String id,
  String name,
  int daysUntil, {
  bool gifted = false,
  String businessId = 'b1',
  String businessName = 'Café Aurora',
  int month = 10,
  int day = 22,
}) =>
    BirthdayItem(
      userId: id,
      name: name,
      email: '$id@mail.com',
      businessId: businessId,
      businessName: businessName,
      month: month,
      day: day,
      daysUntil: daysUntil,
      gifted: gifted,
    );

class _FakeBirthdaysRepository extends BirthdaysRepository {
  BirthdayList list;
  final gifts = <Map<String, Object?>>[];
  final failFor = <String, String>{};

  _FakeBirthdaysRepository(this.list);

  @override
  Future<BirthdayList> upcoming({String? businessId}) async => list;

  @override
  Future<void> gift({
    required String businessId,
    required String userId,
    int? discountPercent,
    String? prizeLabel,
    String? startTime,
    String? endTime,
  }) async {
    if (failFor.containsKey(userId)) throw failFor[userId]!;
    gifts.add({
      'businessId': businessId,
      'userId': userId,
      'discountPercent': discountPercent,
      'prizeLabel': prizeLabel,
      'startTime': startTime,
      'endTime': endTime,
    });
  }
}

class _FakeCampaignsRepository extends CampaignsRepository {
  @override
  Future<List<Campaign>> mine() async => const [];
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('textos', () {
    test('cuándo es: hoy, mañana o en N días', () {
      expect(birthdayWhen(0), 'Hoy');
      expect(birthdayWhen(1), 'Mañana');
      expect(birthdayWhen(3), 'En 3 días');
    });

    test('la fecha solo lleva día y mes (nunca el año ni la edad)', () {
      expect(birthdayDate(_item('a', 'Ana', 0, month: 3, day: 14)), 'Cumple el 14 de Marzo');
    });

    test('se traducen al inglés, incluido el mes y la vigencia', () {
      expect(Translator.english.toEnglish('Cumple el 14 de Marzo'), 'Birthday: March 14');
      expect(Translator.english.toEnglish('En 3 días'), 'In 3 days');
      expect(Translator.english.toEnglish('VÁLIDA SOLO EL 22.10.26'), 'VALID ONLY ON 22.10.26');
      expect(Translator.english.toEnglish('Feliz cumpleaños, Ana'), 'Happy birthday, Ana');
    });

    test('las horas se mandan como HH:mm', () {
      expect(clockText(const TimeOfDay(hour: 8, minute: 5)), '08:05');
      expect(clockText(const TimeOfDay(hour: 22, minute: 30)), '22:30');
    });
  });

  group('fecha de nacimiento', () {
    test('se muestra como dd/mm/aaaa y se manda como aaaa-mm-dd', () {
      final date = DateTime(1998, 3, 4);

      expect(BirthDate.format(date), '04/03/1998');
      expect(BirthDate.toApi(date), '1998-03-04');
    });

    test('se lee lo que guarda el servidor, con o sin hora', () {
      expect(BirthDate.parse('1998-03-14'), DateTime(1998, 3, 14));
      expect(BirthDate.parse('1998-03-14T00:00:00.000Z'), DateTime(1998, 3, 14));
      expect(BirthDate.parse(''), isNull);
      expect(BirthDate.parse(null), isNull);
      expect(BirthDate.parse('basura-xx-yy'), isNull);
    });

    testWidgets('el campo abre el calendario, muestra la fecha y se puede quitar', (tester) async {
      DateTime? value;
      await tester.pumpWidget(
        spanishApp(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BirthDateField(
                value: value,
                onChanged: (d) => setState(() => value = d),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Fecha de nacimiento (opcional)'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      // El calendario abre en una fecha por defecto: se elige el día 15 de ese mes.
      await tester.tap(find.text('15'));
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(value, isNotNull);
      expect(value!.day, 15);
      expect(find.textContaining('15/'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(find.textContaining('15/'), findsNothing);
    });
  });

  group('cheque de la plantilla de cumpleaños', () {
    Campaign birthday() => Campaign(
          id: 'p',
          type: CampaignType.giftCard,
          template: 'birthday',
          title: 'Feliz cumpleaños, Ana',
          description: 'Un regalo de Café Aurora por tu cumpleaños. Vale solo ese día.',
          phase: CampaignPhase.active,
          benefitType: CampaignBenefit.discountPercent,
          benefitValue: 15,
          businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
          endsAt: DateTime(2026, 10, 22, 23, 59),
        );

    testWidgets('lleva su propio diseño y dice que vale solo ese día', (tester) async {
      await tester.pumpWidget(
        spanishApp(Scaffold(body: GiftCardVoucher(campaign: birthday(), businessName: 'Café Aurora'))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayArt), findsOneWidget);
      expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
      expect(find.text('FELIZ CUMPLEAÑOS, ANA'), findsOneWidget);
      expect(find.text('15% DE DESCUENTO'), findsOneWidget);
      expect(find.textContaining('VÁLIDA SOLO EL'), findsOneWidget);
      expect(find.textContaining('VÁLIDA HASTA'), findsNothing);
    });

    testWidgets('una gift card normal no lleva el diseño de cumpleaños', (tester) async {
      final plain = Campaign(
        id: 'g',
        type: CampaignType.giftCard,
        title: 'Regalo',
        phase: CampaignPhase.active,
        businesses: const [CampaignBusinessRef(id: 'b1', name: 'Café Aurora')],
      );
      await tester.pumpWidget(spanishApp(Scaffold(body: GiftCardVoucher(campaign: plain))));
      await tester.pumpAndSettle();

      expect(find.byType(BirthdayArt), findsNothing);
      expect(plain.isBirthday, isFalse);
    });

    test('la plantilla viene del servidor', () {
      final c = Campaign.fromJson({
        'id': 'x',
        'type': 'gift_card',
        'title': 'Feliz cumpleaños, Ana',
        'template': 'birthday',
        'phase': 'active',
        'businesses': [],
      });

      expect(c.isBirthday, isTrue);
    });
  });

  group('plantilla: gift card de cumpleaños', () {
    late _FakeBirthdaysRepository repo;

    final sample = BirthdayList(
      items: [
        _item('hoy', 'Ana Pérez', 0),
        _item('pronto', 'Luis Mora', 3, month: 10, day: 25),
        _item('listo', 'Zoe Ríos', 1, gifted: true, month: 10, day: 23),
      ],
    );

    Future<void> open(WidgetTester tester, {BirthdayList? list, String? userId}) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeBirthdaysRepository(list ?? sample);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            birthdaysRepositoryProvider.overrideWithValue(repo),
            campaignsRepositoryProvider.overrideWithValue(_FakeCampaignsRepository()),
          ],
          child: spanishApp(
            BirthdayGiftScreen(initialUserId: userId, initialBusinessId: userId == null ? null : 'b1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el cheque ya viene con el diseño y el texto puestos', (tester) async {
      await open(tester);

      expect(find.byType(BirthdayArt), findsOneWidget);
      expect(find.text('FELIZ CUMPLEAÑOS, ANA'), findsOneWidget);
      expect(find.textContaining('Tú eliges el premio, a quién y la hora'), findsOneWidget);
    });

    testWidgets('solo ofrece a quienes todavía no tienen su regalo', (tester) async {
      await open(tester);

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(find.text('Zoe Ríos'), findsNothing);
    });

    testWidgets('sin nadie elegido no se puede enviar', (tester) async {
      await open(tester);

      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'ENVIAR REGALO'));
      expect(button.onPressed, isNull);
    });

    testWidgets('elegir a alguien y enviar: descuento, desde las 8:00 y todo el día', (tester) async {
      await open(tester);
      await tester.tap(find.text('Ana Pérez'));
      await tester.pumpAndSettle();
      expect(find.text('FELIZ CUMPLEAÑOS, ANA'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '15'), '25');
      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();

      expect(repo.gifts, [
        {
          'businessId': 'b1',
          'userId': 'hoy',
          'discountPercent': 25,
          'prizeLabel': null,
          'startTime': '08:00',
          'endTime': null,
        },
      ]);
      expect(find.text('Gift card de cumpleaños lista'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('venir desde la lista deja a ese cliente ya marcado', (tester) async {
      await open(tester, userId: 'pronto');

      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();

      expect(repo.gifts.single['userId'], 'pronto');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('varios elegidos: un regalo para cada uno y se cuenta cuántos', (tester) async {
      await open(tester);
      await tester.tap(find.text('Ana Pérez'));
      await tester.tap(find.text('Luis Mora'));
      await tester.pumpAndSettle();
      expect(find.text('ENVIAR 2 REGALOS'), findsOneWidget);

      await tester.tap(find.text('ENVIAR 2 REGALOS'));
      await tester.pumpAndSettle();

      expect(repo.gifts.map((g) => g['userId']), ['hoy', 'pronto']);
      expect(find.text('2 gift cards de cumpleaños listas'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('un mini premio pide su descripción', (tester) async {
      await open(tester, userId: 'hoy');

      await tester.tap(find.text('MINI PREMIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();
      expect(find.text('Describe el premio'), findsOneWidget);
      expect(repo.gifts, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, '').first, 'Un postre gratis');
      await tester.pumpAndSettle();
      // El cheque muestra el premio escrito.
      expect(find.text('UN POSTRE GRATIS'), findsOneWidget);
      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();

      expect(repo.gifts.single['prizeLabel'], 'Un postre gratis');
      expect(repo.gifts.single['discountPercent'], isNull);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('un porcentaje fuera de rango no se envía', (tester) async {
      await open(tester, userId: 'hoy');

      await tester.enterText(find.widgetWithText(TextFormField, '15'), '0');
      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();

      expect(find.text('Entre 1 y 100'), findsOneWidget);
      expect(repo.gifts, isEmpty);
    });

    testWidgets('la hora: por defecto desde las 08:00 y todo el día; se puede cambiar el inicio', (tester) async {
      await open(tester, userId: 'hoy');

      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Todo el día'), findsOneWidget);
      expect(find.textContaining('Vale solo el día del cumpleaños'), findsOneWidget);

      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      expect(find.text('Desde qué hora'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();
      expect(repo.gifts.single['startTime'], '08:00');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('si falla uno, muestra el motivo y deja marcado solo a ese para reintentar', (tester) async {
      await open(tester);
      repo.failFor['pronto'] = 'Ya le regalaste una gift card por este cumpleaños';
      await tester.tap(find.text('Ana Pérez'));
      await tester.tap(find.text('Luis Mora'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ENVIAR 2 REGALOS'));
      await tester.pumpAndSettle();

      expect(repo.gifts.map((g) => g['userId']), ['hoy']);
      expect(find.textContaining('Luis Mora: Ya le regalaste'), findsOneWidget);
      expect(find.text('ENVIAR REGALO'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('sin cumpleaños para regalar lo explica', (tester) async {
      await open(tester, list: const BirthdayList());

      expect(find.text('NADIE POR AHORA'), findsOneWidget);
    });
  });

  group('aviso de cumpleaños', () {
    testWidgets('al tocarlo (push o bandeja) abre la plantilla con ese cliente ya marcado', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeBirthdaysRepository(BirthdayList(items: [
        _item('hoy', 'Ana Pérez', 0),
        _item('pronto', 'Luis Mora', 3, month: 10, day: 25),
      ]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            birthdaysRepositoryProvider.overrideWithValue(repo),
            campaignsRepositoryProvider.overrideWithValue(_FakeCampaignsRepository()),
          ],
          child: MaterialApp(
            navigatorKey: globalNavigatorKey,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Scaffold(body: Text('inicio')),
          ),
        ),
      );

      PushNotificationService.openFromData({
        'type': 'birthday',
        'route': '/birthdays',
        'business_id': 'b1',
        'user_id': 'pronto',
      });
      await tester.pumpAndSettle();

      expect(find.text('GIFT CARD DE CUMPLEAÑOS'), findsOneWidget);
      // El cheque ya muestra a quien cumple años (el cliente viene marcado).
      expect(find.text('FELIZ CUMPLEAÑOS, LUIS'), findsOneWidget);
      await tester.tap(find.text('ENVIAR REGALO'));
      await tester.pumpAndSettle();
      expect(repo.gifts.single['userId'], 'pronto');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('pestaña Gift cards', () {
    testWidgets('ofrece la plantilla de cumpleaños y la abre', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeBirthdaysRepository(BirthdayList(items: [_item('hoy', 'Ana Pérez', 0)]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            birthdaysRepositoryProvider.overrideWithValue(repo),
            campaignsRepositoryProvider.overrideWithValue(_FakeCampaignsRepository()),
          ],
          child: spanishApp(const Scaffold(body: GiftCardsTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NUEVA GIFT CARD'), findsOneWidget);
      expect(find.text('CUMPLEAÑOS'), findsOneWidget);
      expect(find.textContaining('Plantilla lista'), findsOneWidget);

      await tester.tap(find.text('CUMPLEAÑOS'));
      await tester.pumpAndSettle();

      expect(find.text('GIFT CARD DE CUMPLEAÑOS'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
    });
  });
}
