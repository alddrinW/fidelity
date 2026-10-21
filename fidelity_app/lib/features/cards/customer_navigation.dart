import 'package:flutter/material.dart';

/// Las pantallas del panel de usuario (el cliente).
enum CustomerTab {
  /// Inicio: saludo, novedades y los escaneos registrados.
  home,

  /// Explorar: negocios donde puede escanear y campañas vigentes.
  explore,

  /// Mis regalos: tarjetas de regalo y premios de ruta.
  gifts,
}

/// Un destino de la barra inferior del panel de usuario.
class CustomerDestination {
  final CustomerTab? tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isAction;

  const CustomerDestination({
    this.tab,
    required this.label,
    required this.icon,
    this.selectedIcon = Icons.circle_outlined,
    this.isAction = false,
  });

  const CustomerDestination.action({
    required this.label,
    required this.icon,
  })  : tab = null,
        selectedIcon = Icons.circle_outlined,
        isAction = true;
}

/// Los destinos del panel de usuario según lo que el usuario tiene.
///
/// La barra es simple: Inicio, Explorar y (si tiene) Regalos. El perfil se
/// abre desde la foto del saludo, y escanear es el botón flotante de la
/// esquina.
List<CustomerDestination> customerDestinations({
  required int cardCount,
  required int giftCount,
}) {
  return [
    const CustomerDestination(
      tab: CustomerTab.home,
      label: 'Inicio',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    const CustomerDestination(
      tab: CustomerTab.explore,
      label: 'Explorar',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    if (giftCount > 0)
      const CustomerDestination(
        tab: CustomerTab.gifts,
        label: 'Regalos',
        icon: Icons.card_giftcard_outlined,
        selectedIcon: Icons.card_giftcard_rounded,
      ),
  ];
}
