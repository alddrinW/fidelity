import 'package:fidelity_app/core/l10n/app_language.dart';
import 'package:fidelity_app/features/banners/data/banners_repository.dart';
import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:fidelity_app/features/admin/admin_referral_locals_screen.dart';
import 'package:fidelity_app/features/cards/providers/my_cards_provider.dart';
import 'package:fidelity_app/features/games/data/weekly_game_repository.dart';
import 'package:fidelity_app/features/referrals/choose_local_screen.dart';
import 'package:fidelity_app/features/referrals/data/referrals_repository.dart';
import 'package:fidelity_app/features/referrals/invite_screen.dart';
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/referrals/points_text.dart';
import 'package:fidelity_app/features/referrals/redeem_referral_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fake_banners.dart';
import 'spanish_app.dart';

class _FakeReferrals extends ReferralsRepository {
  ReferralInfo infoValue;
  List<ReferralLocal> localsValue;
  List<ReferralAdminBusiness> adminValue;

  final redeemed = <String>[];
  final uses = <(String, int)>[];
  final toggled = <(String, bool)>[];
  final bulk = <(String, bool)>[];
  String? failWith;

  _FakeReferrals(
    this.infoValue, {
    this.localsValue = const [],
    this.adminValue = const [],
  });

  @override
  Future<ReferralInfo> me() async => infoValue;

  @override
  Future<List<ReferralLocal>> locals() async => localsValue;

  @override
  Future<ReferralUsed> use(String businessId, {int points = 1}) async {
    if (failWith != null) throw failWith!;
    uses.add((businessId, points));
    final local = localsValue.firstWhere((l) => l.id == businessId);
    infoValue = ReferralInfo(
      enabled: infoValue.enabled,
      code: infoValue.code,
      balance: infoValue.balance - points,
    );
    return ReferralUsed(
      businessName: local.name,
      used: points,
      balance: infoValue.balance,
      currentPoints: (local.currentPoints ?? 0) + points,
    );
  }

  @override
  Future<ReferralRedeemed> redeem(String code) async {
    if (failWith != null) throw failWith!;
    redeemed.add(code);
    return const ReferralRedeemed(friendPoints: 1, referrerName: 'Ana');
  }

  @override
  Future<List<ReferralAdminBusiness>> adminBusinesses({String? query}) async => adminValue;

  @override
  Future<void> setBusiness(String id, bool enabled) async => toggled.add((id, enabled));

  @override
  Future<void> setMany(List<String> ids, bool enabled) async => bulk.add((ids.join(','), enabled));
}

class _FakeCards extends MyCardsNotifier {
  int refreshed = 0;

  @override
  MyCardsState build() => MyCardsState(isLoading: false, cards: const []);

  @override
  Future<void> refreshCards({bool silent = false}) async => refreshed++;
}

/// El banner ya diseñado (la imagen) de un archivo.
Finder bannerImage(String asset) => find.byWidgetPredicate(
      (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == asset,
    );

const _on = ReferralInfo(
  enabled: true,
  code: 'AMG-ABC234',
  link: 'https://api.fidelity.test/api/v1/invite/AMG-ABC234',
  referrerPoints: 1,
);

const _cafe = ReferralLocal(id: 'b1', name: 'Café Aurora', category: 'Cafeterías', pointsRequired: 10, currentPoints: 4);
const _pizza = ReferralLocal(id: 'b2', name: 'Pizzería Sol', pointsRequired: 8);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<_FakeReferrals> pump(
    WidgetTester tester,
    Widget screen,
    _FakeReferrals repo, {
    Size size = const Size(900, 2400),
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralsRepositoryProvider.overrideWithValue(repo),
          bannersRepositoryProvider.overrideWithValue(FakeBannersRepository()),
          myCardsProvider.overrideWith(_FakeCards.new),
          ...overrides,
        ],
        child: spanishApp(screen),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('textos', () {
    test('1 punto, 2 puntos', () {
      expect(pointsText(1), '1 punto');
      expect(pointsText(3), '3 puntos');
    });

    test('lo que se comparte invita a la app (no a un local) y lleva el enlace y el código', () {
      final text = inviteMessage(code: 'AMG-ABC234', friendPoints: 2, link: 'https://x.test/invite/AMG-ABC234');

      expect(text, contains('¡Únete a Fidelity!'));
      expect(text, contains('regístrate con mi código'));
      expect(text, contains('2 puntos de regalo'));
      expect(text, contains('AMG-ABC234'));
      expect(text, contains('Enlace: https://x.test/invite/AMG-ABC234'));
      expect(text, isNot(contains('local en')));
    });

    test('sin enlace comparte solo el código; sin puntos para el amigo no promete regalo', () {
      final text = inviteMessage(code: 'AMG-ABC234', friendPoints: 0);

      expect(text, isNot(contains('Enlace')));
      expect(text, isNot(contains('de regalo')));
      expect(text, contains('AMG-ABC234'));
    });

    test('sin lo nuevo, el servidor viejo da los valores por defecto (3 amigos, al registrarse, el amigo no gana)', () {
      final info = ReferralInfo.fromJson({'enabled': true});

      expect([info.friendsRequired, info.counted, info.trigger, info.friendPoints], [3, 0, 'registration', 0]);
      expect(info.countsOnFirstScan, isFalse);
      expect([info.inGroup, info.missing], [0, 3]);
    });

    test('se traducen al inglés', () {
      final t = Translator.english.toEnglish;
      expect(t('Los dos ganan 1 punto'), 'You both earn 1 point');
      expect(t('Llevas 4 de 10 puntos aquí'), 'You have 4 of 10 points here');
      expect(t('{} de {} locales participan'.replaceFirst('{}', '2').replaceFirst('{}', '5')), '2 of 5 businesses participate');
      expect(t('Usar 2 puntos aquí'), 'Use 2 points here');
      expect(t('¡Listo! Sumaste 1 punto en Café Aurora.'), 'Done! You added 1 point at Café Aurora.');
    });
  });

  group('modelos', () {
    test('ReferralInfo lee lo que trae el servidor', () {
      final info = ReferralInfo.fromJson({
        'enabled': true,
        'code': 'AMG-ABC234',
        'link': 'https://x.test/i',
        'referrerPoints': 2,
        'friendPoints': 1,
        'maxFriends': 20,
        'friendsRequired': 4,
        'counted': 6,
        'groupsPaid': 1,
        'trigger': 'first_scan',
        'invited': 3,
        'rewarded': 2,
        'balance': 4,
        'eligibleLocals': 5,
        'referredBy': {'name': 'Ana', 'status': 'pending', 'points': 1},
      });

      expect(info.link, 'https://x.test/i');
      expect(info.balance, 4);
      expect(info.eligibleLocals, 5);
      expect(info.referredBy?.isPending, isTrue);
      expect(info.visible, isTrue);
      expect([info.friendsRequired, info.counted, info.groupsPaid, info.trigger], [4, 6, 1, 'first_scan']);
      expect(info.countsOnFirstScan, isTrue);
      // 6 amigos en grupos de 4: 2 en el grupo actual, faltan 2.
      expect([info.inGroup, info.missing], [2, 2]);
    });

    test('apagado y sin saldo no se muestra; apagado pero con saldo sí (son suyos)', () {
      expect(const ReferralInfo(enabled: false).visible, isFalse);
      expect(const ReferralInfo(enabled: false, balance: 2).visible, isTrue);
    });

    test('ReferralLocal y ReferralAdminBusiness', () {
      final local = ReferralLocal.fromJson({'id': 'b1', 'name': 'Café', 'pointsRequired': 8, 'currentPoints': 3});
      expect((local.pointsRequired, local.currentPoints), (8, 3));
      expect(ReferralLocal.fromJson({'id': 'b2', 'name': 'X'}).currentPoints, isNull);

      final admin = ReferralAdminBusiness.fromJson({'id': 'b1', 'name': 'Café', 'enabled': true});
      expect(admin.enabled, isTrue);
      expect(admin.withEnabled(false).enabled, isFalse);
    });
  });

  group('pantalla Invitar amigos', () {
    testWidgets('invita a la app: muestra su código, lo que gana al juntar 3 amigos y el enlace', (tester) async {
      await pump(tester, const InviteScreen(), _FakeReferrals(_on));

      expect(find.text('INVITAR AMIGOS'), findsOneWidget);
      expect(find.text('INVITA A UN AMIGO A FIDELITY'), findsOneWidget);
      expect(find.text('AMG-ABC234'), findsOneWidget);
      expect(
        find.text('Invita a 3 amigos: cuando se registren con tu código, ganas 1 punto. Elige en qué local usarlo.'),
        findsOneWidget,
      );
      // El punto es solo para quien invita: no se le promete nada al amigo.
      expect(find.textContaining('Tu amigo también gana'), findsNothing);
      expect(find.text('COMPARTIR ENLACE'), findsOneWidget);
      expect(find.text('Copiar enlace'), findsOneWidget);
    });

    testWidgets('sin enlace (el servidor no tiene dirección pública) comparte solo el código', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234')),
      );

      expect(find.text('COMPARTIR MI CÓDIGO'), findsOneWidget);
      expect(find.text('COMPARTIR ENLACE'), findsNothing);
      expect(find.text('Copiar enlace'), findsNothing);
    });

    testWidgets('si el administrador le da puntos al amigo, también lo dice', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', referrerPoints: 2, friendPoints: 1)),
      );

      expect(find.textContaining('ganas 2 puntos'), findsOneWidget);
      expect(find.text('Tu amigo también gana 1 punto con su primer escaneo.'), findsOneWidget);
    });

    testWidgets('con otra cantidad de amigos y contando al primer escaneo', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', friendsRequired: 5, trigger: 'first_scan')),
      );

      expect(
        find.text('Invita a 5 amigos: cuando se registren y hagan su primer escaneo, ganas 1 punto. Elige en qué local usarlo.'),
        findsOneWidget,
      );
    });

    testWidgets('pide 1 solo amigo: lo dice en singular', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', friendsRequired: 1)),
      );

      expect(find.textContaining('Invita a un amigo:'), findsOneWidget);
      expect(find.text('Falta 1 amigo para ganar tu punto'), findsOneWidget);
    });

    testWidgets('al tocar el código lo copia, y el enlace también', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester, const InviteScreen(), _FakeReferrals(_on));

      await tester.tap(find.text('AMG-ABC234'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
      expect(copied.last, 'AMG-ABC234');
      expect(find.text('Código copiado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.text('Copiar enlace'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 1));
      expect(copied.last, 'https://api.fidelity.test/api/v1/invite/AMG-ABC234');
      await tester.pump(const Duration(seconds: 6));
    });

    group('el avance de sus amigos', () {
      Finder dots(String state) => find.byWidgetPredicate(
            (w) => w.key is ValueKey && (w.key as ValueKey).value.toString().endsWith('-$state'),
          );

      testWidgets('sin amigos: 0 de 3 y faltan 3', (tester) async {
        await pump(tester, const InviteScreen(), _FakeReferrals(_on));

        expect(find.text('TUS AMIGOS'), findsOneWidget);
        expect(find.text('0 / 3'), findsOneWidget);
        expect(find.text('Faltan 3 amigos para ganar tu punto'), findsOneWidget);
        expect(dots('cuenta'), findsNothing);
        expect(dots('falta'), findsNWidgets(3));
      });

      testWidgets('con 2 amigos: dos círculos llenos y falta 1', (tester) async {
        await pump(
          tester,
          const InviteScreen(),
          _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', invited: 2, counted: 2)),
        );

        expect(find.text('2 / 3'), findsOneWidget);
        expect(find.text('Falta 1 amigo para ganar tu punto'), findsOneWidget);
        expect(dots('cuenta'), findsNWidgets(2));
        expect(dots('falta'), findsOneWidget);
      });

      testWidgets('al completar el grupo arranca otro y dice lo que ya ganó', (tester) async {
        await pump(
          tester,
          const InviteScreen(),
          _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', invited: 4, counted: 4, groupsPaid: 1, balance: 1)),
        );

        // 4 amigos = un grupo completo y 1 del siguiente.
        expect(find.text('1 / 3'), findsOneWidget);
        expect(find.text('Faltan 2 amigos para ganar tu punto'), findsOneWidget);
        expect(find.text('Ya ganaste 1 punto con tus amigos.'), findsOneWidget);
      });

      testWidgets('con "primer escaneo", dice cuántos amigos aún no escanean', (tester) async {
        await pump(
          tester,
          const InviteScreen(),
          _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', invited: 3, counted: 1, trigger: 'first_scan')),
        );

        expect(find.text('2 amigos aún no hacen su primer escaneo'), findsOneWidget);
      });

      testWidgets('si solo el amigo gana (0 puntos para quien invita), no hay meta que mostrar', (tester) async {
        await pump(
          tester,
          const InviteScreen(),
          _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', referrerPoints: 0, friendPoints: 1)),
        );

        expect(find.text('TUS AMIGOS'), findsNothing);
      });
    });

    testWidgets('sin puntos de invitación: explica dónde aparecerán y no ofrece elegir local', (tester) async {
      await pump(tester, const InviteScreen(), _FakeReferrals(_on));

      expect(find.text('PUNTOS DE INVITACIÓN'), findsOneWidget);
      expect(find.text('Aquí aparecen los puntos que ganes al invitar amigos.'), findsOneWidget);
      expect(find.text('ELEGIR LOCAL'), findsNothing);
    });

    testWidgets('con puntos de invitación: muestra cuántos y el botón para elegir local', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', balance: 2), localsValue: [_cafe]),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('ELEGIR LOCAL'), findsOneWidget);

      await tester.tap(find.text('ELEGIR LOCAL'));
      await tester.pumpAndSettle();
      expect(find.text('Café Aurora'.toUpperCase()), findsOneWidget);
    });

    testWidgets('si llegó invitado y aún no escanea: ve de parte de quién y qué gana', (tester) async {
      await pump(
        tester,
        const InviteScreen(),
        _FakeReferrals(
          const ReferralInfo(
            enabled: true,
            code: 'AMG-ABC234',
            friendPoints: 1,
            referredBy: ReferredBy(name: 'Ana Pérez', status: 'pending', points: 1),
          ),
        ),
      );

      expect(
        find.text('Te invitó Ana Pérez: con tu primer escaneo en cualquier local ganas 1 punto de invitación'),
        findsOneWidget,
      );
      // Ya usó un código: no se ofrece escribir otro.
      expect(find.text('Tengo un código de un amigo'), findsNothing);
    });

    testWidgets('quien no llegó invitado puede escribir el código de un amigo', (tester) async {
      final repo = await pump(tester, const InviteScreen(), _FakeReferrals(_on));

      await tester.tap(find.text('Tengo un código de un amigo'));
      await tester.pumpAndSettle();
      expect(find.text('CÓDIGO DE UN AMIGO'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'amg-xyz789');
      await tester.tap(find.text('USAR CÓDIGO'));
      await tester.pumpAndSettle();

      expect(repo.redeemed, ['amg-xyz789']);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('apagado por el administrador (y sin saldo): lo explica', (tester) async {
      await pump(tester, const InviteScreen(), _FakeReferrals(const ReferralInfo(enabled: false)));

      expect(find.text('INVITACIONES APAGADAS'), findsOneWidget);
      expect(find.text('COMPARTIR ENLACE'), findsNothing);
    });

    testWidgets('apagado pero con puntos por usar: los puntos siguen siendo suyos', (tester) async {
      await pump(tester, const InviteScreen(), _FakeReferrals(const ReferralInfo(enabled: false, balance: 1), localsValue: [_cafe]));

      expect(find.text('INVITACIONES APAGADAS'), findsNothing);
      expect(find.text('ELEGIR LOCAL'), findsOneWidget);
      expect(find.text('COMPARTIR ENLACE'), findsNothing);
    });
  });

  group('elegir en qué local usar los puntos', () {
    testWidgets('solo salen los locales que el administrador marcó, con los puntos que lleva en cada uno', (tester) async {
      await pump(
        tester,
        const ChooseLocalScreen(),
        _FakeReferrals(const ReferralInfo(enabled: true, balance: 1), localsValue: [_cafe, _pizza]),
      );

      expect(find.text('ELEGIR LOCAL'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.text('PIZZERÍA SOL'), findsOneWidget);
      expect(find.text('Llevas 4 de 10 puntos aquí'), findsOneWidget);
      expect(find.text('Todavía no tienes tarjeta aquí'), findsOneWidget);
    });

    testWidgets('elige un local, confirma y se usa 1 punto ahí (y se actualizan sus tarjetas)', (tester) async {
      final repo = _FakeReferrals(const ReferralInfo(enabled: true, balance: 2), localsValue: [_cafe, _pizza]);
      await pump(tester, const ChooseLocalScreen(), repo);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      expect(find.text('Llevas 4 de 10 puntos aquí.'), findsOneWidget);
      expect(find.text('USAR 1 PUNTO AQUÍ'), findsOneWidget);

      await tester.tap(find.text('USAR 1 PUNTO AQUÍ'));
      await tester.pumpAndSettle();

      expect(repo.uses, [('b1', 1)]);
      expect(find.text('¡Listo! Sumaste 1 punto en Café Aurora.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('con varios puntos se elige cuántos usar en ese local', (tester) async {
      final repo = _FakeReferrals(const ReferralInfo(enabled: true, balance: 3), localsValue: [_cafe]);
      await pump(tester, const ChooseLocalScreen(), repo);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('USAR 2 PUNTOS AQUÍ'), findsOneWidget);
      expect(find.text('Tendrás 6 de 10 puntos'), findsOneWidget);

      await tester.tap(find.text('USAR 2 PUNTOS AQUÍ'));
      await tester.pumpAndSettle();

      expect(repo.uses, [('b1', 2)]);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('no se puede pasar de los puntos que tiene, ni bajar de 1', (tester) async {
      await pump(tester, const ChooseLocalScreen(), _FakeReferrals(const ReferralInfo(enabled: true, balance: 2), localsValue: [_cafe]));
      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('USAR 2 PUNTOS AQUÍ'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(find.text('USAR 1 PUNTO AQUÍ'), findsOneWidget);
    });

    testWidgets('si con los puntos completa su premio, se lo dice antes de confirmar', (tester) async {
      await pump(
        tester,
        const ChooseLocalScreen(),
        _FakeReferrals(
          const ReferralInfo(enabled: true, balance: 1),
          localsValue: [const ReferralLocal(id: 'b1', name: 'Café Aurora', pointsRequired: 10, currentPoints: 9)],
        ),
      );

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();

      expect(find.text('¡Con 1 punto completas tu premio!'), findsOneWidget);
    });

    testWidgets('en un local donde no tiene tarjeta, avisa que se la crea', (tester) async {
      await pump(tester, const ChooseLocalScreen(), _FakeReferrals(const ReferralInfo(enabled: true, balance: 1), localsValue: [_pizza]));

      await tester.tap(find.text('PIZZERÍA SOL'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Se creará tu tarjeta en este local'), findsOneWidget);
    });

    testWidgets('si el servidor lo rechaza, muestra el motivo y no cierra', (tester) async {
      final repo = _FakeReferrals(const ReferralInfo(enabled: true, balance: 1), localsValue: [_cafe]);
      await pump(tester, const ChooseLocalScreen(), repo);
      repo.failWith = 'Ese local no participa en los puntos de invitación';

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USAR 1 PUNTO AQUÍ'));
      await tester.pumpAndSettle();

      expect(find.text('Ese local no participa en los puntos de invitación'), findsOneWidget);
      expect(find.text('USAR 1 PUNTO AQUÍ'), findsOneWidget);
    });

    testWidgets('sin locales participantes: sus puntos se guardan', (tester) async {
      await pump(tester, const ChooseLocalScreen(), _FakeReferrals(const ReferralInfo(enabled: true, balance: 1)));

      expect(find.text('AÚN NO HAY LOCALES'), findsOneWidget);
      expect(find.textContaining('Tus puntos se guardan'), findsOneWidget);
    });

    testWidgets('sin puntos no se puede tocar ningún local', (tester) async {
      final repo = _FakeReferrals(const ReferralInfo(enabled: true, balance: 0), localsValue: [_cafe]);
      await pump(tester, const ChooseLocalScreen(), repo);

      await tester.tap(find.text('CAFÉ AURORA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('USAR'), findsNothing);
      expect(repo.uses, isEmpty);
    });
  });

  group('acceso en el inicio del cliente (banner de Fido)', () {
    const carousel = Scaffold(body: FidoBannerCarousel(autoPlay: false));

    testWidgets('con la regla de siempre (3 amigos, 1 punto) sale el banner diseñado y abre la pantalla', (tester) async {
      await pump(tester, carousel, _FakeReferrals(_on));

      expect(bannerImage(BannerImages.invite), findsOneWidget);
      // Es una imagen con su texto: no hay nube ni botón aparte.
      expect(find.text('INVITAR'), findsNothing);

      await tester.tap(bannerImage(BannerImages.invite));
      await tester.pumpAndSettle();
      expect(find.text('INVITA A UN AMIGO A FIDELITY'), findsOneWidget);
    });

    testWidgets('los dos banners del ingeniero salen juntos en el carrusel (aunque el juego esté apagado) y se pasan solos', (tester) async {
      await pump(
        tester,
        const Scaffold(body: FidoBannerCarousel()),
        _FakeReferrals(_on),
        overrides: [weeklyGameProvider.overrideWith((ref) async => const WeeklyStatus(state: 'off'))],
      );

      // Primero "Juega y gana" (el juego de la semana va antes), luego "Gana 1 punto".
      expect(find.byType(PageView), findsOneWidget);
      expect(bannerImage(BannerImages.play), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(bannerImage(BannerImages.invite), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('con amigos a medias sigue el mismo banner (la regla no cambió)', (tester) async {
      await pump(
        tester,
        carousel,
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', invited: 2, counted: 2)),
      );

      expect(bannerImage(BannerImages.invite), findsOneWidget);
    });

    testWidgets('si el administrador pide otra cantidad de amigos, la imagen ya no vale: sale la nube con el dato correcto', (tester) async {
      await pump(
        tester,
        carousel,
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', friendsRequired: 5)),
      );

      expect(bannerImage(BannerImages.invite), findsNothing);
      expect(find.text('INVITA A 5 AMIGOS'), findsOneWidget);
      expect(find.text('Cuando se registren los 5 con tu código, ganas 1 punto.'), findsOneWidget);
      expect(find.text('INVITAR'), findsOneWidget);
    });

    testWidgets('con otros puntos, también sale la nube', (tester) async {
      await pump(
        tester,
        carousel,
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', referrerPoints: 2)),
      );

      expect(bannerImage(BannerImages.invite), findsNothing);
      expect(find.text('Cuando se registren los 3 con tu código, ganas 2 puntos.'), findsOneWidget);
    });

    testWidgets('con amigos a medias y otra regla, la nube dice cómo va', (tester) async {
      await pump(
        tester,
        carousel,
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', friendsRequired: 5, invited: 2, counted: 2)),
      );

      expect(find.text('Van 2 de 5 amigos. Al completar, ganas 1 punto.'), findsOneWidget);
    });

    testWidgets('con la app en inglés no sale la imagen (trae el texto en español): sale la nube, que sí se traduce', (tester) async {
      await pump(
        tester,
        carousel,
        _FakeReferrals(_on),
        overrides: [initialLanguageProvider.overrideWithValue(AppLanguage.en)],
      );

      expect(bannerImage(BannerImages.invite), findsNothing);
      // (La prueba fija el idioma de los textos en español; lo que se comprueba es que cambia a la nube.)
      expect(find.text('INVITA A 3 AMIGOS'), findsOneWidget);
    });

    testWidgets('con puntos por usar, los anuncia y ofrece elegir el local', (tester) async {
      await pump(
        tester,
        const Scaffold(body: FidoBannerCarousel(autoPlay: false)),
        _FakeReferrals(const ReferralInfo(enabled: true, code: 'AMG-ABC234', balance: 2)),
      );

      expect(find.text('Tienes 2 puntos de invitación: elige en qué local usarlos.'), findsOneWidget);
      expect(find.text('ELEGIR LOCAL'), findsOneWidget);
      expect(bannerImage(BannerImages.invite), findsNothing);
    });

    testWidgets('apagado y sin puntos: no aparece', (tester) async {
      await pump(
        tester,
        const Scaffold(body: FidoBannerCarousel(autoPlay: false)),
        _FakeReferrals(const ReferralInfo(enabled: false)),
      );

      expect(find.text('INVITA A UN AMIGO'), findsNothing);
      expect(bannerImage(BannerImages.invite), findsNothing);
    });
  });

  group('usar el código de un amigo (diálogo)', () {
    late _FakeReferrals repo;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeReferrals(_on);
      await tester.pumpWidget(
        spanishApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRedeemReferralDialog(context, repo),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('explica que se invita a Fidelity y pide el código', (tester) async {
      await open(tester);

      expect(find.text('CÓDIGO DE UN AMIGO'), findsOneWidget);
      expect(find.textContaining('te invitó a Fidelity'), findsOneWidget);
    });

    testWidgets('un código muy corto no se envía', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'AB');
      await tester.tap(find.text('USAR CÓDIGO'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el código de tu amigo'), findsOneWidget);
      expect(repo.redeemed, isEmpty);
    });

    testWidgets('con un código bueno queda invitado y se avisa qué gana', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(TextFormField), 'amg-abc234');
      await tester.tap(find.text('USAR CÓDIGO'));
      await tester.pumpAndSettle();

      expect(repo.redeemed, ['amg-abc234']);
      expect(find.text('CÓDIGO DE UN AMIGO'), findsNothing);
      expect(find.text('¡Listo! Con tu primer escaneo ganas 1 punto de invitación'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('si el servidor lo rechaza, muestra el motivo y no cierra', (tester) async {
      await open(tester);
      repo.failWith = 'Ya usas Fidelity: el código es para quienes llegan por primera vez';

      await tester.enterText(find.byType(TextFormField), 'AMG-ABC234');
      await tester.tap(find.text('USAR CÓDIGO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya usas Fidelity'), findsOneWidget);
      expect(find.text('CÓDIGO DE UN AMIGO'), findsOneWidget);
    });
  });

  group('el administrador elige los locales', () {
    final admin = [
      const ReferralAdminBusiness(id: 'b1', name: 'Café Aurora', category: 'Cafeterías', enabled: true),
      const ReferralAdminBusiness(id: 'b2', name: 'Pizzería Sol', enabled: false),
      const ReferralAdminBusiness(id: 'b3', name: 'Panadería Luna', enabled: false),
    ];

    testWidgets('lista los locales activos con su interruptor y cuenta cuántos participan', (tester) async {
      await pump(tester, const AdminReferralLocalsScreen(), _FakeReferrals(_on, adminValue: admin));

      expect(find.text('LOCALES DE INVITACIONES'), findsOneWidget);
      expect(find.text('Café Aurora'), findsOneWidget);
      expect(find.text('Pizzería Sol'), findsOneWidget);
      expect(find.text('1 de 3 locales participan'), findsOneWidget);
      expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [true, false, false]);
    });

    testWidgets('marcar un local lo guarda y lo muestra al instante', (tester) async {
      final repo = _FakeReferrals(_on, adminValue: admin);
      await pump(tester, const AdminReferralLocalsScreen(), repo);

      await tester.tap(find.text('Pizzería Sol'));
      await tester.pumpAndSettle();

      expect(repo.toggled, [('b2', true)]);
      expect(find.text('2 de 3 locales participan'), findsOneWidget);
    });

    testWidgets('desmarcar uno que estaba marcado', (tester) async {
      final repo = _FakeReferrals(_on, adminValue: admin);
      await pump(tester, const AdminReferralLocalsScreen(), repo);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(repo.toggled, [('b1', false)]);
      expect(find.text('0 de 3 locales participan'), findsOneWidget);
    });

    testWidgets('"Marcar todos" marca de una vez solo los que faltan', (tester) async {
      final repo = _FakeReferrals(_on, adminValue: admin);
      await pump(tester, const AdminReferralLocalsScreen(), repo);

      await tester.tap(find.text('Marcar todos'));
      await tester.pumpAndSettle();

      expect(repo.bulk, [('b2,b3', true)]);
      expect(find.text('3 de 3 locales participan'), findsOneWidget);
    });

    testWidgets('"Quitar todos" desmarca los marcados', (tester) async {
      final repo = _FakeReferrals(_on, adminValue: admin);
      await pump(tester, const AdminReferralLocalsScreen(), repo);

      await tester.tap(find.text('Quitar todos'));
      await tester.pumpAndSettle();

      expect(repo.bulk, [('b1', false)]);
    });

    testWidgets('la búsqueda filtra, y marcar todos solo afecta a lo que se ve', (tester) async {
      final repo = _FakeReferrals(_on, adminValue: admin);
      await pump(tester, const AdminReferralLocalsScreen(), repo);

      await tester.enterText(find.byType(TextField), 'pan');
      await tester.pumpAndSettle();
      expect(find.text('Panadería Luna'), findsOneWidget);
      expect(find.text('Pizzería Sol'), findsNothing);

      await tester.tap(find.text('Marcar todos'));
      await tester.pumpAndSettle();
      expect(repo.bulk, [('b3', true)]);
    });

    testWidgets('sin coincidencias lo dice', (tester) async {
      await pump(tester, const AdminReferralLocalsScreen(), _FakeReferrals(_on, adminValue: admin));

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('SIN RESULTADOS'), findsOneWidget);
    });
  });
}
