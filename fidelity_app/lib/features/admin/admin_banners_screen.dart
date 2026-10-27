import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_text_field.dart';
import '../banners/data/banners_repository.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../campaigns/widgets/schedule_row.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';

/// Medidas de las imágenes de los banners (para el diseñador).
const double kBannerRatio = 2000 / 648;

/// Banners del inicio del cliente: el administrador sube las imágenes ya diseñadas,
/// decide cuáles se ven, en qué orden y hasta cuándo, y a dónde lleva cada una.
class AdminBannersScreen extends ConsumerStatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  ConsumerState<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends ConsumerState<AdminBannersScreen> {
  bool _busy = false;

  void _toast(String message, {bool isError = false}) {
    if (mounted) DashboardAnimatedToast.show(context, message, isError: isError);
  }

  /// Hace un cambio y vuelve a cargar la lista.
  Future<void> _run(Future<void> Function() action, String errorMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(adminBannersProvider);
      ref.invalidate(clientBannersProvider);
      await ref.read(adminBannersProvider.future);
    } catch (_) {
      _toast(errorMessage, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([AdminBanner? banner]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminBannerFormScreen(banner: banner)),
    );
    if (saved == true) {
      ref.invalidate(adminBannersProvider);
      ref.invalidate(clientBannersProvider);
      _toast(banner == null ? 'Banner publicado' : 'Banner actualizado');
    }
  }

  Future<void> _move(List<AdminBanner> all, int from, int to) {
    final ids = all.map((b) => b.id).toList();
    ids.insert(to, ids.removeAt(from));
    return _run(() => ref.read(bannersRepositoryProvider).reorder(ids), 'No se pudo cambiar el orden');
  }

  void _confirmDelete(AdminBanner banner) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Eliminar banner',
        message: '¿Seguro que quieres eliminar "${banner.title}"?',
        hint: 'Los clientes dejarán de verlo. Si solo quieres ocultarlo un tiempo, apágalo.',
        primaryLabel: 'Eliminar',
        onPrimary: () => _run(() => ref.read(bannersRepositoryProvider).remove(banner.id), 'No se pudo eliminar el banner'),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(adminBannersProvider);

    return AdminPageFrame(
      title: 'Banners',
      bottom: AppPrimaryButton(label: 'Nuevo banner', onPressed: _busy ? null : () => _edit()),
      body: banners.when(
        loading: () => const AdminLoading(),
        error: (_, __) => AppEmptyState.error(message: 'No se pudieron cargar los banners. Desliza para reintentar.'),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminBannersProvider);
            await ref.read(adminBannersProvider.future);
          },
          color: AppColors.black,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                'Aquí eliges qué ven tus clientes en el carrusel de su inicio. Sube la imagen ya diseñada, '
                'decide a dónde lleva al tocarla y en qué orden sale. Mide 2000 × 648 px (proporción 3.09:1).',
                style: AppTypography.body(size: 14, weight: FontWeight.w300, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                AppCard(
                  child: Text(
                    'Aún no subes ningún banner. Mientras tanto, los clientes ven los dos diseños que vienen con la app '
                    '(Invita amigos y Juega y gana). Al subir el primero, solo verán los tuyos.',
                    style: AppTypography.body(size: 15, weight: FontWeight.w300),
                  ),
                )
              else
                for (var i = 0; i < list.length; i++) ...[
                  _BannerTile(
                    banner: list[i],
                    busy: _busy,
                    onUp: i == 0 ? null : () => _move(list, i, i - 1),
                    onDown: i == list.length - 1 ? null : () => _move(list, i, i + 1),
                    onActive: (on) => _run(
                      () => ref.read(bannersRepositoryProvider).update(list[i].id, {'isActive': on}),
                      'No se pudo cambiar el banner',
                    ),
                    onEdit: () => _edit(list[i]),
                    onDelete: () => _confirmDelete(list[i]),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una vista previa de la imagen con la proporción del banner.
class _BannerPreview extends StatelessWidget {
  final String? imageUri;

  const _BannerPreview({required this.imageUri});

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(imageUri);
    return AspectRatio(
      aspectRatio: kBannerRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: AppColors.white,
          child: image == null
              ? const Center(child: Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary))
              : Image(image: image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final AdminBanner banner;
  final bool busy;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final ValueChanged<bool> onActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerTile({
    required this.banner,
    required this.busy,
    required this.onUp,
    required this.onDown,
    required this.onActive,
    required this.onEdit,
    required this.onDelete,
  });

  /// "Se ve ahora", "Programado"... según el horario.
  String _status(DateTime now) {
    if (!banner.isActive) return 'Apagado';
    if (banner.startsAt != null && banner.startsAt!.isAfter(now)) return 'Programado';
    if (banner.endsAt != null && !banner.endsAt!.isAfter(now)) return 'Terminado';
    return 'Se ve ahora';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = _status(now);
    final live = status == 'Se ve ahora';

    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BannerPreview(imageUri: banner.imageUrl),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  banner.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 16, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: live ? AppColors.black : AppColors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.black, width: 1.2),
                ),
                child: Text(
                  status,
                  style: AppTypography.label(size: 10, tracking: 1.2, color: live ? AppColors.white : AppColors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Al tocarlo: ${banner.action.label}',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          if (banner.imageUrlEn != null && banner.imageUrlEn!.isNotEmpty)
            Text(
              'Con versión en inglés',
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          if (banner.startsAt != null)
            Text(
              'Se ve desde ${formatShortDate(banner.startsAt!)}',
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          if (banner.endsAt != null)
            Text(
              'Se ve hasta ${formatShortDate(banner.endsAt!)}',
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'Subir',
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: busy ? null : onUp,
              ),
              IconButton(
                tooltip: 'Bajar',
                icon: const Icon(Icons.arrow_downward_rounded),
                onPressed: busy ? null : onDown,
              ),
              const Spacer(),
              Switch(
                value: banner.isActive,
                activeTrackColor: AppColors.black,
                onChanged: busy ? null : onActive,
              ),
              IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: busy ? null : onEdit),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: busy ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Crear o editar un banner: la imagen (y su versión en inglés), a dónde lleva, y su horario.
class AdminBannerFormScreen extends ConsumerStatefulWidget {
  /// El banner que se edita (`null`: uno nuevo).
  final AdminBanner? banner;

  const AdminBannerFormScreen({super.key, this.banner});

  @override
  ConsumerState<AdminBannerFormScreen> createState() => _AdminBannerFormScreenState();
}

class _AdminBannerFormScreenState extends ConsumerState<AdminBannerFormScreen> {
  late final _title = TextEditingController(text: widget.banner?.title ?? '');
  late final _link = TextEditingController(text: widget.banner?.linkUrl ?? '');

  String? _image;
  String? _imageEn;
  late BannerAction _action = widget.banner?.action ?? BannerAction.none;
  late bool _blend = widget.banner?.blendWhite ?? true;
  late bool _active = widget.banner?.isActive ?? true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _scheduleStart = false;
  bool _scheduleEnd = false;
  bool _saving = false;

  bool get _editing => widget.banner != null;

  @override
  void initState() {
    super.initState();
    final b = widget.banner;
    _image = b?.imageUrl;
    _imageEn = b?.imageUrlEn;
    _startsAt = b?.startsAt;
    _endsAt = b?.endsAt;
    _scheduleStart = _startsAt != null;
    _scheduleEnd = _endsAt != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  void _error(String message) {
    if (mounted) DashboardAnimatedToast.show(context, message, isError: true);
  }

  Future<void> _pick({required bool english}) async {
    try {
      final picked = await pickImageFromGallery(maxSide: 2000);
      if (picked == null || !mounted) return;
      setState(() => english ? _imageEn = picked.dataUri : _image = picked.dataUri);
    } on FormatException catch (e) {
      _error(e.message);
    } catch (_) {
      _error('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (_image == null || _image!.isEmpty) return _error('Sube la imagen del banner.');
    if (title.isEmpty) return _error('Ponle un nombre al banner.');
    final link = _link.text.trim();
    if (_action == BannerAction.link && !(link.startsWith('http://') || link.startsWith('https://'))) {
      return _error('El enlace debe empezar con http:// o https://');
    }
    final start = _scheduleStart ? _startsAt : null;
    final end = _scheduleEnd ? _endsAt : null;
    if (start != null && end != null && !end.isAfter(start)) {
      return _error('El banner debe terminar después de empezar.');
    }

    final body = <String, dynamic>{
      'title': title,
      'imageUrl': _image,
      // Vacío = quitar la versión en inglés.
      'imageUrlEn': _imageEn ?? '',
      'action': _action.code,
      'linkUrl': _action == BannerAction.link ? link : '',
      'blendWhite': _blend,
      'isActive': _active,
      'startsAt': start?.toUtc().toIso8601String(),
      'endsAt': end?.toUtc().toIso8601String(),
    };
    setState(() => _saving = true);
    try {
      final repo = ref.read(bannersRepositoryProvider);
      if (_editing) {
        await repo.update(widget.banner!.id, body);
      } else {
        await repo.create(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _error('No se pudo guardar el banner. Revisa los datos e inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imageBlock({required bool english}) {
    final uri = english ? _imageEn : _image;
    final has = uri != null && uri.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (has) ...[
          _BannerPreview(imageUri: uri),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            AdminFilterPill(
              label: has ? 'Cambiar imagen' : (english ? 'Subir versión en inglés' : 'Subir imagen'),
              icon: Icons.image_outlined,
              selected: !has,
              onTap: () => _pick(english: english),
            ),
            if (has && english)
              AdminFilterPill(
                label: 'Quitar',
                icon: Icons.close_rounded,
                selected: false,
                onTap: () => setState(() => _imageEn = null),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: _editing ? 'Editar banner' : 'Nuevo banner',
      bottom: AppPrimaryButton(
        label: _editing ? 'Guardar cambios' : 'Publicar banner',
        isLoading: _saving,
        onPressed: _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          const AdminSectionLabel('Paso 1 · La imagen'),
          Text(
            'Sube la imagen ya diseñada, con su texto. Mide 2000 × 648 px (proporción 3.09:1) y pesa menos de 1 MB. '
            'Si tiene otra proporción, se recorta para llenar el banner.',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _imageBlock(english: false),
          const SizedBox(height: 22),
          const AdminSectionLabel('Paso 2 · Versión en inglés'),
          Text(
            'Opcional. Quien use la app en inglés ve esta imagen; si no la subes, ve la de arriba.',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _imageBlock(english: true),
          const SizedBox(height: 22),
          const AdminSectionLabel('Paso 3 · Nombre'),
          AppTextField(
            controller: _title,
            hint: 'Nombre del banner (ej. Promo de octubre)',
            icon: Icons.title_rounded,
            helperText: 'Solo lo ves tú, y lo lee en voz alta el lector de pantalla.',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 22),
          const AdminSectionLabel('Paso 4 · Qué pasa al tocarlo'),
          AdminSelectField(
            icon: Icons.touch_app_outlined,
            title: 'Al tocarlo',
            selected: _action.code,
            options: [for (final a in BannerAction.values) (a.code, a.label)],
            onChanged: (code) => setState(() => _action = BannerAction.fromCode(code)),
          ),
          if (_action == BannerAction.link) ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: _link,
              hint: 'https://…',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              helperText: 'La página que se abre al tocar el banner.',
            ),
          ],
          const SizedBox(height: 22),
          const AdminSectionLabel('Paso 5 · Cómo se ve'),
          _SwitchRow(
            title: 'Fundir con el fondo blanco',
            subtitle: 'Difumina los bordes para que la imagen salga del fondo blanco, sin verse como un cuadro. '
                'Apágalo si la imagen ya trae su propio fondo.',
            value: _blend,
            onChanged: (v) => setState(() => _blend = v),
          ),
          const SizedBox(height: 22),
          const AdminSectionLabel('Paso 6 · Cuándo se ve'),
          _SwitchRow(
            title: 'Visible para los clientes',
            subtitle: 'Apágalo para ocultarlo sin borrarlo.',
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          ScheduleDateTimeRow(
            title: 'Desde cuándo se ve',
            hint: 'Ahora, o el día y la hora en que empieza a verse.',
            offLabel: 'Ahora',
            onLabel: 'Programar',
            isOn: _scheduleStart,
            value: _startsAt,
            defaultTime: const TimeOfDay(hour: 0, minute: 0),
            onToggle: (on) => setState(() => _scheduleStart = on),
            onChanged: (d) => setState(() => _startsAt = d),
          ),
          const SizedBox(height: 16),
          ScheduleDateTimeRow(
            title: 'Hasta cuándo se ve',
            hint: 'Sin fin, o el día y la hora en que deja de verse.',
            offLabel: 'Sin fin',
            onLabel: 'Hasta una fecha',
            isOn: _scheduleEnd,
            value: _endsAt,
            defaultTime: const TimeOfDay(hour: 23, minute: 59),
            onToggle: (on) => setState(() => _scheduleEnd = on),
            onChanged: (d) => setState(() => _endsAt = d),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.body(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Switch(value: value, activeTrackColor: AppColors.black, onChanged: onChanged),
      ],
    );
  }
}
