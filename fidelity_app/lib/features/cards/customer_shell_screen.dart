import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_pill_tab_bar.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/my_gifts_screen.dart';
import '../profile/user_profile_screen.dart';
import '../scanner/scanner_screen.dart';
import 'customer_explore_view.dart';
import 'customer_home_view.dart';
import 'customer_navigation.dart';
import 'providers/my_cards_provider.dart';
import 'widgets/customer_greeting.dart';

/// Panel de usuario (el cliente).
///
/// Es la pantalla con barra inferior: los destinos dependen de lo que el
/// usuario tiene (tarjetas, regalos) y en el centro está la acción de
/// escanear. En pantallas anchas la barra se convierte en un menú lateral.
class CustomerShellScreen extends ConsumerStatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  ConsumerState<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends ConsumerState<CustomerShellScreen> {
  /// La pestaña activa. Se guarda por pestaña (no por índice) para que la
  /// barra pueda cambiar de destinos sin descolocar la selección.
  CustomerTab _tab = CustomerTab.home;

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myCardsProvider);
    final cards = state.cards.length;
    final gifts = ref.watch(myClaimsProvider).valueOrNull?.length ?? 0;

    // Los destinos que el usuario puede usar: "Regalos" solo si ya tiene
    // tarjetas de regalo o premios por reclamar.
    final destinations = customerDestinations(cardCount: cards, giftCount: gifts);

    // Las pantallas de cada destino, en el mismo orden. La clave mantiene el
    // estado de cada pestaña aunque la lista de destinos cambie.
    final tabs = <(CustomerTab, Widget)>[
      (
        CustomerTab.home,
        CustomerHomeView(
          key: const ValueKey('home'),
          onExplore: () => setState(() => _tab = CustomerTab.explore),
        ),
      ),
      (CustomerTab.explore, const CustomerExploreView(key: ValueKey('explore'))),
      if (gifts > 0) (CustomerTab.gifts, const MyGiftsView(key: ValueKey('gifts'))),
    ];

    // Si el destino activo ya no existe (el usuario dejó de tener regalos,
    // por ejemplo), se vuelve al inicio.
    var tab = _tab;
    if (!tabs.any((t) => t.$1 == tab)) tab = CustomerTab.home;

    final tabIndex = tabs.indexWhere((t) => t.$1 == tab);
    final selectedIndex = destinations.indexWhere((d) => d.tab == tab);

    void onSelected(int index) {
      final destination = destinations[index];
      if (destination.isAction) {
        _openScanner();
        return;
      }
      setState(() => _tab = destination.tab!);
    }

    final body = IndexedStack(
      index: tabIndex,
      children: [for (final t in tabs) t.$2],
    );

    // En pantallas anchas el menú lateral reemplaza la barra inferior.
    if (context.isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _CustomerRail(
              destinations: destinations,
              selectedTab: tab,
              onSelected: onSelected,
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.black),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: _ScanButton(onPressed: _openScanner),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // El saludo arriba y las pestañas debajo, como en el panel del dueño.
                CustomerGreeting(
                  displayName: _displayName(state.userName),
                  avatarUrl: state.avatarUrl,
                  onAvatarTap: _openProfile,
                  summary: greetingSummary(state.cards),
                ),
                AppPillTabBar(
                  labels: [for (final destination in destinations) destination.label],
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                ),
                const SizedBox(height: 16),
                Expanded(child: body),
              ],
            ),
            // Escanear vive en la esquina: es la acción, no un destino.
            Positioned(
              right: 24,
              bottom: 24,
              child: _ScanButton(onPressed: _openScanner),
            ),
          ],
        ),
      ),
    );
  }

  /// "juan diego" (el nombre y el apellido).
  String _displayName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  /// Abre el perfil del cliente (con la foto y el nombre).
  Future<void> _openProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
    if (result == true && mounted) {
      // Esperamos a que termine la animación de vuelta (Hero) ANTES de
      // refrescar, para no reconstruir el avatar a mitad del vuelo.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          ref.read(myCardsProvider.notifier).refreshCards(silent: true);
        }
      });
    }
  }
}

/// El botón flotante de escanear: un círculo rosa en la esquina inferior.
class _ScanButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScanButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Escanear',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Escanear',
        child: Material(
          color: AppColors.pink,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox(
              width: 60,
              height: 60,
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.black,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menú lateral del panel de usuario en pantallas anchas (navegador en PC).
class _CustomerRail extends StatelessWidget {
  final List<CustomerDestination> destinations;
  final CustomerTab selectedTab;
  final ValueChanged<int> onSelected;

  const _CustomerRail({
    required this.destinations,
    required this.selectedTab,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              _RailItem(
                destination: destinations[i],
                selected: destinations[i].tab == selectedTab,
                onTap: () => onSelected(i),
              ),
              if (i < destinations.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un destino del menú lateral.
class _RailItem extends StatelessWidget {
  final CustomerDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAction = destination.isAction;

    if (isAction) {
      return Semantics(
        button: true,
        label: destination.label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.pink,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 1.4),
            ),
            child: Icon(destination.icon, color: AppColors.black, size: 26),
          ),
        ),
      );
    }

    final foreground = selected ? AppColors.white : AppColors.black;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.black : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? (destination.selectedIcon) : destination.icon,
                  size: 22,
                  color: foreground,
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 10,
                    weight: selected ? FontWeight.w600 : FontWeight.w300,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
