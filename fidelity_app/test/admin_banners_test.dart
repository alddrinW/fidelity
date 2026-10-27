import 'package:fidelity_app/core/l10n/app_language.dart';
import 'package:fidelity_app/features/admin/admin_banners_screen.dart';
import 'package:fidelity_app/features/banners/data/banners_repository.dart';
import 'package:fidelity_app/features/campaigns/data/campaigns_repository.dart' show Campaign;
import 'package:fidelity_app/features/cards/widgets/fido_banner_carousel.dart';
import 'package:fidelity_app/features/card_sales/data/card_sales_repository.dart';
import 'package:fidelity_app/features/games/data/games_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_banners.dart';
import 'spanish_app.dart';

/// Una imagen de 1 × 1 píxel, para que los banners tengan algo que mostrar.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

ClientBanner _client(String id, {BannerAction action = BannerAction.none, bool blend = true, String image = _png, String? link}) =>
    ClientBanner(id: id, title: 'Banner $id', imageUrl: image, action: action, blendWhite: blend, linkUrl: link);

AdminBanner _admin(
  String id, {
  bool active = true,
  BannerAction action = BannerAction.none,
  DateTime? startsAt,
  DateTime? endsAt,
  String? imageEn,
}) =>
    AdminBanner(
      id: id,
      title: 'Banner $id',
      imageUrl: _png,
      imageUrlEn: imageEn,
      action: action,
      isActive: active,
      startsAt: startsAt,
      endsAt: endsAt,
    );

class _NoGames extends GamesRepository {
  @override
  Future<List<GameInvite>> myInvites() async => const [];
}

class _NoSales extends CardSalesRepository {
  @override
  Future<List<Campaign>> offers() async => const [];
}

void main() {
  group('los banners del administrador en el carrusel del cliente', () {
    Future<void> open(
      WidgetTester tester,
      FakeBannersRepository banners, {
      VoidCallback? onScan,
      VoidCallback? onOffers,
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gamesRepositoryProvider.overrideWithValue(_NoGames()),
            cardSalesRepositoryProvider.overrideWithValue(_NoSales()),
            bannersRepositoryProvider.overrideWithValue(banners),
            ...overrides,
          ],
          child: spanishApp(
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: FidoBannerCarousel(autoPlay: false, onScan: onScan, onOpenOffers: onOffers),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder adminImage() => find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage);

    testWidgets('sin banners del administrador y sin nada que decir, no ocupa espacio', (tester) async {
      await open(tester, FakeBannersRepository());

      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('sale la imagen que subió el administrador', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('a')]));

      expect(adminImage(), findsOneWidget);
    });

    testWidgets('varios: el carrusel los muestra en el orden del administrador, con sus puntitos', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('a'), _client('b'), _client('c')]));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.bySemanticsLabel('Banner a'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Banner b'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Banner c'), findsOneWidget);
    });

    testWidgets('con banners del administrador ya no salen los dos diseños que vienen con la app', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('a')]));

      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('banner_')),
        findsNothing,
      );
    });

    testWidgets('con "fundir con el fondo" se difuminan los bordes; sin él, esquinas redondeadas', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('a', blend: true)]));
      expect(find.ancestor(of: adminImage(), matching: find.byType(ShaderMask)), findsNWidgets(2));
      expect(find.ancestor(of: adminImage(), matching: find.byType(ClipRRect)), findsNothing);

      await open(tester, FakeBannersRepository(client: [_client('a', blend: false)]));
      expect(find.ancestor(of: adminImage(), matching: find.byType(ShaderMask)), findsNothing);
      expect(find.ancestor(of: adminImage(), matching: find.byType(ClipRRect)), findsOneWidget);
    });

    testWidgets('la acción "escanear" abre el escáner', (tester) async {
      var scans = 0;
      await open(tester, FakeBannersRepository(client: [_client('a', action: BannerAction.scan)]), onScan: () => scans++);

      await tester.tap(adminImage());
      expect(scans, 1);
    });

    testWidgets('la acción "tarjetas en venta" lleva a Explorar', (tester) async {
      var offers = 0;
      await open(tester, FakeBannersRepository(client: [_client('a', action: BannerAction.offers)]), onOffers: () => offers++);

      await tester.tap(adminImage());
      expect(offers, 1);
    });

    testWidgets('sin acción no se puede tocar (no es un botón)', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('a')]));

      final semantics = tester.getSemantics(find.bySemanticsLabel('Banner a'));
      expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    });

    testWidgets('un banner con una imagen que no se puede leer se salta', (tester) async {
      await open(tester, FakeBannersRepository(client: [_client('mala', image: 'no-es-una-imagen'), _client('buena')]));

      expect(find.bySemanticsLabel('Banner mala'), findsNothing);
      expect(find.bySemanticsLabel('Banner buena'), findsOneWidget);
    });

    testWidgets('pide los banners en el idioma de la app', (tester) async {
      final repo = FakeBannersRepository(client: [_client('a')]);
      await open(tester, repo, overrides: [initialLanguageProvider.overrideWithValue(AppLanguage.en)]);

      expect(repo.languages, contains('en'));
    });
  });

  group('el panel del administrador', () {
    Future<void> open(WidgetTester tester, FakeBannersRepository repo) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bannersRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(const AdminBannersScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('sin banners explica que salen los dos que vienen con la app', (tester) async {
      await open(tester, FakeBannersRepository());

      expect(find.textContaining('Aún no subes ningún banner'), findsOneWidget);
      expect(find.text('NUEVO BANNER'), findsOneWidget);
      expect(find.textContaining('2000 × 648'), findsOneWidget);
    });

    testWidgets('lista los banners con su estado y a dónde llevan', (tester) async {
      final now = DateTime.now();
      await open(
        tester,
        FakeBannersRepository(admin: [
          _admin('vivo', action: BannerAction.invite, imageEn: _png),
          _admin('apagado', active: false),
          _admin('futuro', startsAt: now.add(const Duration(days: 3))),
          _admin('pasado', endsAt: now.subtract(const Duration(days: 1))),
        ]),
      );

      expect(find.text('Banner vivo'), findsOneWidget);
      expect(find.text('Se ve ahora'), findsOneWidget);
      expect(find.text('Apagado'), findsOneWidget);
      expect(find.text('Programado'), findsOneWidget);
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.text('Al tocarlo: Invitar amigos'), findsOneWidget);
      expect(find.text('Con versión en inglés'), findsOneWidget);
    });

    testWidgets('en inglés todo el panel sale traducido', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bannersRepositoryProvider.overrideWithValue(
              FakeBannersRepository(admin: [
                _admin('a', action: BannerAction.weeklyGame, imageEn: _png, endsAt: now.add(const Duration(days: 2))),
              ]),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: [Locale('es'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: AdminBannersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('NEW BANNER'), findsOneWidget);
      expect(find.text('Showing now'), findsOneWidget);
      expect(find.text('When tapped: Game of the week'), findsOneWidget);
      expect(find.text('With English version'), findsOneWidget);
      expect(find.textContaining('Shows until'), findsOneWidget);
      expect(find.textContaining('Here you choose what your customers see'), findsOneWidget);
    });

    testWidgets('apagar un banner lo guarda', (tester) async {
      final repo = FakeBannersRepository(admin: [_admin('a')]);
      await open(tester, repo);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repo.updated['a'], {'isActive': false});
    });

    testWidgets('subir y bajar guardan el orden nuevo; el primero no sube y el último no baja', (tester) async {
      final repo = FakeBannersRepository(admin: [_admin('a'), _admin('b'), _admin('c')]);
      await open(tester, repo);

      final ups = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
      final downs = find.widgetWithIcon(IconButton, Icons.arrow_downward_rounded);
      expect(tester.widget<IconButton>(ups.first).onPressed, isNull);
      expect(tester.widget<IconButton>(downs.last).onPressed, isNull);

      await tester.tap(downs.first); // a baja: b, a, c
      await tester.pumpAndSettle();
      expect(repo.reorders.last, ['b', 'a', 'c']);

      await tester.tap(ups.last); // c sube: a, c, b
      await tester.pumpAndSettle();
      expect(repo.reorders.last, ['a', 'c', 'b']);
    });

    testWidgets('eliminar pide confirmación y luego borra', (tester) async {
      final repo = FakeBannersRepository(admin: [_admin('a')]);
      await open(tester, repo);

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Seguro que quieres eliminar "Banner a"?'), findsOneWidget);
      expect(repo.removed, isEmpty);

      await tester.tap(find.text('ELIMINAR'));
      await tester.pumpAndSettle();
      expect(repo.removed, ['a']);
    });
  });

  group('el formulario de un banner', () {
    Future<void> open(WidgetTester tester, FakeBannersRepository repo, {AdminBanner? banner}) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bannersRepositoryProvider.overrideWithValue(repo)],
          child: spanishApp(AdminBannerFormScreen(banner: banner)),
        ),
      );
      await tester.pump();
    }

    testWidgets('explica cada paso, con las medidas de la imagen', (tester) async {
      await open(tester, FakeBannersRepository());

      for (final step in [
        'PASO 1 · LA IMAGEN',
        'PASO 2 · VERSIÓN EN INGLÉS',
        'PASO 3 · NOMBRE',
        'PASO 4 · QUÉ PASA AL TOCARLO',
        'PASO 5 · CÓMO SE VE',
        'PASO 6 · CUÁNDO SE VE',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.textContaining('2000 × 648 px'), findsOneWidget);
    });

    testWidgets('no se puede publicar sin imagen ni sin nombre', (tester) async {
      final repo = FakeBannersRepository();
      await open(tester, repo);

      await tester.tap(find.text('PUBLICAR BANNER'));
      await tester.pump();
      expect(find.text('Sube la imagen del banner.'), findsOneWidget);
      expect(repo.created, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('al editar trae lo guardado y guarda los cambios', (tester) async {
      final repo = FakeBannersRepository();
      await open(tester, repo, banner: _admin('a', action: BannerAction.scan));

      expect(find.widgetWithText(TextField, 'Banner a'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Banner a'), 'Promo nueva');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final body = repo.updated['a']!;
      expect(body['title'], 'Promo nueva');
      expect(body['imageUrl'], _png);
      expect(body['action'], 'scan');
      expect(body['linkUrl'], '');
      expect(body['blendWhite'], true);
      expect(body['isActive'], true);
      expect(body['startsAt'], isNull);
      expect(body['endsAt'], isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('con la acción "abrir un enlace" pide el enlace y solo acepta http(s)', (tester) async {
      final repo = FakeBannersRepository();
      await open(tester, repo, banner: _admin('a', action: BannerAction.link));

      expect(find.text('https://…'), findsOneWidget);
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      expect(find.text('El enlace debe empezar con http:// o https://'), findsOneWidget);
      expect(repo.updated, isEmpty);
      await tester.pump(const Duration(seconds: 5));

      await tester.enterText(find.widgetWithText(TextField, ''), 'https://fidelity.example/promo');
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.updated['a']!['linkUrl'], 'https://fidelity.example/promo');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('quitar la versión en inglés la manda vacía', (tester) async {
      final repo = FakeBannersRepository();
      await open(tester, repo, banner: _admin('a', imageEn: _png));

      await tester.tap(find.text('QUITAR'));
      await tester.pump();
      await tester.tap(find.text('GUARDAR CAMBIOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.updated['a']!['imageUrlEn'], '');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
