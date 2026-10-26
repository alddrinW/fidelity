import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_selector.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_nav_row.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_pill_tab_bar.dart';
import '../../../core/widgets/app_quad_tab_bar.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../campaigns/campaigns_tab.dart';
import '../../campaigns/widgets/redeem_code_card.dart';
import '../../feedback/data/feedback_repository.dart';
import '../../feedback/feedback_inbox_screen.dart';
import '../branches/my_businesses_screen.dart';
import '../create_business_screen.dart';
import '../profile/business_profile_screen.dart';
import '../profile/campaign_settings_screen.dart';
import 'widgets/fido_guide_strip.dart';
import '../../campaigns/gift_cards_tab.dart';
import '../../games/games_tab.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/notifications_screen.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../qr_management/qr_management_screen.dart';
import '../rewards/rewards_management_screen.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_animated_toast.dart';
import 'widgets/pending_reward_notice.dart';
import 'widgets/tabs/tab_customers.dart';
import 'widgets/tabs/tab_pending_scans.dart';
import 'widgets/tabs/tab_statistics.dart';
import '../../../core/l10n/tr_text.dart';

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  /// Vista del **aprobador** (supervisor del local): solo escaneos pendientes,
  /// premios y opiniones. El dueño ve el panel completo.
  final bool approverMode;

  const BusinessDashboardScreen({
    super.key,
    this.initialIndex = 0,
    this.approverMode = false,
  });

  /// Canal para que servicios externos (ej. el push de notificaciones) pidan
  /// que el dashboard raíz —que ya está vivo— salte a una pestaña concreta.
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);

  /// Pide que el dashboard activo se mueva a la pestaña [index].
  static void goToTab(int index) => tabRequest.value = index;

  @override
  ConsumerState<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends ConsumerState<BusinessDashboardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static bool _welcomeShown = false;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(
      length: widget.approverMode ? 4 : 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    BusinessDashboardScreen.tabRequest.addListener(_onTabRequest);

    // El provider ya carga en su build() y se suscribe al realtime con canales
    // filtrados por business_id. Acá solo refrescamos si quedó viejo (ej. al
    // volver de una notificación push) y resolvemos la pestaña pedida.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).reloadIfStale();
      if (!widget.approverMode) _checkWelcomeMessage();
      _onTabRequest();
    });
  }

  void _onTabRequest() {
    var requested = BusinessDashboardScreen.tabRequest.value;
    if (requested == null) return;
    // Los pedidos usan los índices del panel del dueño (1 = Pendientes,
    // 2 = Premios); el aprobador no tiene la pestaña "Clientes".
    if (widget.approverMode) requested -= 1;
    if (mounted && requested >= 0 && requested < _tabController.length) {
      _tabController.animateTo(requested);
    }
    BusinessDashboardScreen.tabRequest.value = null; // consumido
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BusinessDashboardScreen.tabRequest.removeListener(_onTabRequest);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver del background refrescamos solo si los datos quedaron viejos,
      // evitando una recarga completa en cada resume.
      if (mounted) {
        ref.read(dashboardProvider.notifier).reloadIfStale();
      }
    }
  }

  /// Nombre y primer apellido del dueño, para el saludo.
  String _ownerDisplayName(String ownerName) {
    if (ownerName.isEmpty) return '';
    final parts = ownerName.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 ? '${parts[0]} ${parts[1]}' : parts[0];
  }

  void _checkWelcomeMessage() async {
    if (_welcomeShown) return;
    final repository = ref.read(authRepositoryProvider);
    final user = repository.currentUser;
    // Solo la primera vez que el dueño entra a su cuenta: el servidor recuerda
    // que ya la vio, aunque cierre sesión, vuelva a entrar o use otro dispositivo.
    if (user != null && !user.hasSeenWelcome) {
      _welcomeShown = true;
      if (mounted) _showWelcomeDialog();
      await repository.markWelcomeSeen();
    }
  }

  void _showWelcomeDialog() {
    final name = _ownerDisplayName(ref.read(dashboardProvider).ownerName);
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.storefront_outlined,
        title: '¡Bienvenido a Fidelity!',
        message: '${name.isEmpty ? '¡Hola!' : '¡Hola $name!'} Tu negocio fue registrado y activado. '
            'Lo primero: define tu campaña, es decir, qué premio entregas y cuántos puntos necesitan tus clientes.',
        hint: 'Podrás cambiarla cuando quieras desde el logo de tu negocio.',
        primaryLabel: 'Configurar mi campaña',
        onPrimary: _openCampaignSettings,
        secondaryLabel: 'Más tarde',
      ),
    );
  }

  /// Primera configuración de la campaña, ya con la cuenta activa.
  Future<void> _openCampaignSettings() async {
    final business = ref.read(dashboardProvider).business;
    if (business == null || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CampaignSettingsScreen(business: business)),
    );
    if (saved == true && mounted) {
      ref.read(dashboardProvider.notifier).loadData(silent: true);
    }
  }

  /// La bienvenida de Fido se cierra por sesión (no vuelve hasta reabrir la app).
  static bool _guideDismissed = false;

  /// Fido, en el encabezado del dueño, ofrece accesos directos según lo que
  /// esté pasando en su negocio.
  Widget _fidoGuide(DashboardState state, String ownerName) {
    if (widget.approverMode || _guideDismissed) return const SizedBox.shrink();

    final pending = state.pendingScans.length;
    final message = switch (pending) {
      0 => ownerName.isEmpty
          ? '¡Hola! ¿Qué hacemos hoy? Envía una gift card o revisa tus sucursales.'
          : '¡Hola $ownerName! ¿Qué hacemos hoy? Envía una gift card o revisa tus sucursales.',
      1 => 'Tienes 1 escaneo por aprobar. Apruébalo para que tu cliente sume su punto.',
      _ => 'Tienes $pending escaneos por aprobar. Apruébalos para que tus clientes sumen su punto.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: FidoGuideStrip(
        message: message,
        onDismiss: () => setState(() => _guideDismissed = true),
        actions: [
          if (pending > 0)
            FidoGuideAction(
              label: 'Aprobar escaneos',
              icon: Icons.pending_actions_rounded,
              onTap: () => _tabController.animateTo(1),
            ),
          FidoGuideAction(
            label: 'Enviar gift card',
            icon: Icons.card_giftcard_rounded,
            onTap: () => _openSection('Gift cards', const GiftCardsTab()),
          ),
          if (state.business?['id'] != null)
            FidoGuideAction(
              label: 'Minijuegos',
              icon: Icons.sports_esports_rounded,
              onTap: () => _openSection(
                'Minijuegos',
                GamesTab(businessId: state.business!['id'].toString()),
              ),
            ),
          FidoGuideAction(
            label: 'Crear campaña',
            icon: Icons.campaign_outlined,
            onTap: () => _openSection('Campañas', const CampaignsTab()),
          ),
          FidoGuideAction(
            label: 'Mis sucursales',
            icon: Icons.account_tree_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyBusinessesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openMyBusiness(Map<String, dynamic> business) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BusinessProfileScreen(business: business)),
    );
    if (result == true && mounted) {
      // Recarga silenciosa: evita el parpadeo de reconstruir todo el dashboard.
      ref.read(dashboardProvider.notifier).loadData(silent: true);
    }
  }

  Widget _feedbackTab(String businessId) {
    final repository = ref.read(feedbackRepositoryProvider);
    return FeedbackInboxBody(
      load: () => repository.listForBusiness(businessId),
      onResolve: repository.resolve,
      showUser: true,
      showBusiness: false,
    );
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.logout_rounded,
        title: '¿Cerrar sesión?',
        message: '¿Estás seguro de que deseas salir de tu cuenta?',
        primaryLabel: 'Cerrar sesión',
        onPrimary: () => ref.read(authStateProvider.notifier).logout(),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  /// Lo que el dueño crea y gestiona aparte del día a día: su código QR, sus
  /// gift cards y sus campañas. Se abre desde el botón "+" de la esquina.
  /// Abre una sección de "Crear y gestionar" como pantalla propia.
  void _openSection(String title, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _BusinessSectionScreen(title: title, child: child)),
    );
  }

  void _openMoreSections(Map<String, dynamic> business) {
    final businessId = business['id'].toString();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      // Con pantallas bajas la lista no cabe: se desplaza en vez de desbordarse.
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'CREAR Y GESTIONAR',
                style: AppTypography.display(size: 26),
              ),
            ),
            _SectionRow(
              icon: Icons.qr_code_2_rounded,
              label: 'Mi código QR',
              hint: 'Descargarlo o imprimirlo para tu local',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QRManagementScreen(businessId: businessId),
                  ),
                );
              },
            ),
            _SectionRow(
              icon: Icons.card_giftcard_rounded,
              label: 'Gift cards',
              hint: 'Regala descuentos y canjea los códigos',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _BusinessSectionScreen(
                      title: 'Gift cards',
                      child: GiftCardsTab(),
                    ),
                  ),
                );
              },
            ),
            _SectionRow(
              icon: Icons.sports_esports_rounded,
              label: 'Minijuegos',
              hint: 'Pídelos al administrador y mándalos a tus clientes',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openSection('Minijuegos', GamesTab(businessId: businessId));
              },
            ),
            _SectionRow(
              icon: Icons.campaign_outlined,
              label: 'Campañas',
              hint: 'Eventos y rutas para tus clientes',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _BusinessSectionScreen(
                      title: 'Campañas',
                      child: CampaignsTab(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    ref.listen<DashboardState>(dashboardProvider, (previous, next) {
      if (next.toastMessage != null && next.toastMessage != previous?.toastMessage) {
        if (next.toastMessage == 'ERROR_PENDING_REWARD') {
          showPendingRewardNotice(context);
        } else {
          DashboardAnimatedToast.show(context, next.toastMessage!, isError: next.toastIsError);
        }
      }
    });

    if (state.isLoading && state.business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final business = state.business;

    if (business == null && widget.approverMode) {
      return Scaffold(
        body: SafeArea(
          child: AppResponsiveBody(
            child: Column(
              children: [
                const Expanded(
                  child: AppEmptyState(
                    title: 'Sin local asignado',
                    message: 'Todavía no tienes un local asignado. Pídele al dueño que te agregue a su equipo.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
                  child: AppPrimaryButton(label: 'Cerrar sesión', onPressed: _confirmLogout),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (business == null) {
      return Scaffold(
        body: SafeArea(
          child: AppResponsiveBody(
            child: Column(
              children: [
                const Expanded(
                  child: AppEmptyState(
                    title: 'Sin negocio',
                    message: 'Registra tu local para empezar a fidelizar a tus clientes con puntos y premios.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
                  child: AppPrimaryButton(
                    label: 'Registrar mi local',
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
                      );
                      ref.read(dashboardProvider.notifier).loadData();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ownerName = _ownerDisplayName(state.ownerName);

    final labels = widget.approverMode
        ? const ['Pendientes', 'Premios', 'Opiniones', 'Canjear']
        : const ['Clientes', 'Pendientes', 'Métricas'];
    final icons = widget.approverMode
        ? const [
            Icons.pending_actions_rounded,
            Icons.card_giftcard_rounded,
            Icons.forum_outlined,
            Icons.qr_code_2_rounded,
          ]
        : const [
            Icons.people_alt_outlined,
            Icons.pending_actions_rounded,
            Icons.bar_chart_rounded,
          ];
    final badges = widget.approverMode
        ? [state.pendingScans.length, state.pendingRewards.length, 0, 0]
        : [0, state.pendingScans.length, 0];
    final views = widget.approverMode
        ? <Widget>[
            const TabPendingScans(),
            RewardsManagementScreen(businessId: business['id']),
            _feedbackTab(business['id'].toString()),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: const [RedeemCodeCard()],
            ),
          ]
        : <Widget>[
            const TabCustomers(),
            const TabPendingScans(),
            const TabStatistics(),
          ];

    // En pantallas anchas (navegador en PC) el menú pasa a una barra lateral.
    if (context.isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  _DashboardSidebar(
                    logoUrl: business['logo_url']?.toString(),
                    businessName: business['name'].toString(),
                    greeting: ownerName.isEmpty
                        ? null
                        : (widget.approverMode ? 'Hola, $ownerName · Aprobador' : 'Hola, $ownerName'),
                    subtitle: widget.approverMode ? null : '${state.customers.length} clientes activos',
                    controller: _tabController,
                    labels: labels,
                    icons: icons,
                    badges: badges,
                    onProfile: widget.approverMode ? null : () => _openMyBusiness(business),
                    onBusinesses: widget.approverMode
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyBusinessesScreen()),
                            ),
                    unreadNotifications: ref.watch(unreadCountProvider),
                    onNotifications: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    onLogout: _confirmLogout,
                  ),
                  const VerticalDivider(width: 1, thickness: 1, color: AppColors.black),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              _fidoGuide(state, ownerName),
                              Expanded(child: TabBarView(controller: _tabController, children: views)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!widget.approverMode)
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: _MoreButton(onPressed: () => _openMoreSections(business)),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AppResponsiveBody(
              maxWidth: 640,
              adaptive: true,
              child: Column(
                children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Mis negocios',
                      child: GestureDetector(
                        // El logo grande lleva a la gestión de los negocios.
                        onTap: widget.approverMode
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const MyBusinessesScreen()),
                                ),
                        child: Hero(
                          tag: 'business_logo',
                          child: _BusinessLogo(logoUrl: business['logo_url']?.toString()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ownerName.isNotEmpty)
                            Text(
                              widget.approverMode ? 'Hola, $ownerName · Aprobador' : 'Hola, $ownerName',
                              style: AppTypography.body(size: 14, weight: FontWeight.w300),
                            ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              business['name'].toString().toUpperCase(),
                              style: AppTypography.display(size: 30),
                            ),
                          ),
                          if (!widget.approverMode)
                            Text(
                              '${state.customers.length} clientes activos',
                              style: AppTypography.body(
                                size: 13,
                                weight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const NotificationBell(),
                    if (widget.approverMode)
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: _confirmLogout,
                      ),
                  ],
                ),
              ),
              _fidoGuide(state, ownerName),
              // El aprobador maneja sus cuatro secciones desde un cuadrado dividido
              // en cuatro partes; el dueño, desde pastillas.
              if (widget.approverMode)
                AppQuadTabBar(
                  controller: _tabController,
                  labels: labels,
                  icons: icons,
                  badges: badges,
                )
              else
                AppPillTabBar(controller: _tabController, labels: labels, badges: badges),
              const SizedBox(height: 16),
              Expanded(child: TabBarView(controller: _tabController, children: views)),
                ],
              ),
            ),
            // El botón "+": abre lo que el dueño crea y gestiona aparte.
            if (!widget.approverMode)
              Positioned(
                right: 24,
                bottom: 24,
                child: _MoreButton(onPressed: () => _openMoreSections(business)),
              ),
          ],
        ),
      ),
    );
  }
}

/// El botón "+" de la esquina inferior derecha: abre lo que el dueño crea
/// y gestiona aparte del día a día.
class _MoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Crear y gestionar',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Crear y gestionar',
        child: Material(
          color: AppColors.pink,
          shape: CircleBorder(side: BorderSide(color: AppColors.black, width: 1.4)),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(Icons.add_rounded, color: AppColors.black, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de la hoja "Crear y gestionar".
class _SectionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  const _SectionRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: AppNavRow(icon: icon, label: label, onTap: onTap),
    );
  }
}

/// Una sección del negocio abierta como pantalla (desde el botón "+").
class _BusinessSectionScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _BusinessSectionScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(title: title),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menú lateral del panel en pantallas anchas: negocio, pestañas con sus
/// avisos y accesos a "Mis negocios", idioma y cierre de sesión.
class _DashboardSidebar extends StatelessWidget {
  final String? logoUrl;
  final String businessName;
  final String? greeting;
  final String? subtitle;
  final TabController controller;
  final List<String> labels;
  final List<IconData> icons;
  final List<int> badges;
  final VoidCallback? onProfile;
  final VoidCallback? onBusinesses;
  final int unreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  const _DashboardSidebar({
    required this.logoUrl,
    required this.businessName,
    required this.greeting,
    required this.subtitle,
    required this.controller,
    required this.labels,
    required this.icons,
    required this.badges,
    required this.onProfile,
    required this.onBusinesses,
    required this.unreadNotifications,
    required this.onNotifications,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MouseRegion(
                  cursor: onProfile == null ? MouseCursor.defer : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onProfile,
                    child: _BusinessLogo(logoUrl: logoUrl),
                  ),
                ),
                const SizedBox(height: 12),
                if (greeting != null)
                  Text(greeting!, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
                Text(
                  businessName.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 28),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller.animation ?? controller,
              builder: (context, _) {
                final selected = controller.index;
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      _SidebarItem(
                        icon: icons[i],
                        label: labels[i],
                        badge: badges[i],
                        selected: i == selected,
                        onTap: () => controller.animateTo(i),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.black),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              children: [
                if (onBusinesses != null)
                  _SidebarItem(
                    icon: Icons.store_mall_directory_outlined,
                    label: 'Mis negocios',
                    badge: 0,
                    selected: false,
                    onTap: onBusinesses!,
                  ),
                _SidebarItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notificaciones',
                  badge: unreadNotifications,
                  selected: false,
                  onTap: onNotifications,
                ),
                const Align(alignment: Alignment.centerLeft, child: LanguageButton()),
                _SidebarItem(
                  icon: Icons.logout_rounded,
                  label: 'Cerrar sesión',
                  badge: 0,
                  selected: false,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.white : AppColors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.black : Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTypography.label(size: 13, tracking: 2.5, color: foreground),
                    ),
                  ),
                  if (badge > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(size: 11, tracking: 0, color: AppColors.black),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo del negocio en el encabezado; sin logo, un círculo negro con tienda.
class _BusinessLogo extends StatelessWidget {
  final String? logoUrl;

  const _BusinessLogo({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(logoUrl);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: image == null ? AppColors.black : AppColors.surfaceMuted,
        shape: BoxShape.circle,
        image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: image == null
          ? const Icon(Icons.storefront_outlined, color: AppColors.white, size: 30)
          : null,
    );
  }
}
