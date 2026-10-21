import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/campaigns_repository.dart';

/// Hoja para elegir a qué clientes les llega una gift card. Devuelve los ids
/// elegidos, o `null` si se cierra sin confirmar.
Future<Set<String>?> showCustomerPicker(
  BuildContext context, {
  required CampaignsRepository repository,
  required List<String> businessIds,
  Set<String> initial = const {},
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: CustomerPicker(repository: repository, businessIds: businessIds, initial: initial),
    ),
  );
}

class CustomerPicker extends StatefulWidget {
  final CampaignsRepository repository;
  final List<String> businessIds;
  final Set<String> initial;

  const CustomerPicker({
    super.key,
    required this.repository,
    required this.businessIds,
    this.initial = const {},
  });

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final _search = TextEditingController();
  Timer? _debounce;

  late final Set<String> _selected = {...widget.initial};
  List<CampaignCustomer> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => _onSearch(_search.text));
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.repository.customers(widget.businessIds, query: _search.text);
      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  bool get _allShownSelected =>
      _customers.isNotEmpty && _customers.every((c) => _selected.contains(c.id));

  void _toggleAll() {
    setState(() {
      if (_allShownSelected) {
        _selected.removeAll(_customers.map((c) => c.id));
      } else {
        _selected.addAll(_customers.map((c) => c.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ELIGE A TUS CLIENTES',
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              'La gift card les llegará solo a ellos.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 14, weight: FontWeight.w300),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _search,
              hint: 'Buscar por nombre o correo',
              icon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
            ),
            if (_customers.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: AppTextAction(
                  label: _allShownSelected ? 'Quitar a todos' : 'Elegir a todos',
                  onPressed: _toggleAll,
                ),
              ),
            Expanded(child: _list()),
            const SizedBox(height: 8),
            AppPrimaryButton(
              label: _selected.isEmpty ? 'Listo' : 'Listo (${_selected.length})',
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (_error != null) {
      return Center(
        child: Text(
          'No pudimos cargar tus clientes.',
          style: AppTypography.body(size: 15, weight: FontWeight.w300),
        ),
      );
    }
    if (_customers.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isEmpty
              ? 'Todavía no tienes clientes en este negocio.'
              : 'Ningún cliente coincide con tu búsqueda.',
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 15, weight: FontWeight.w300),
        ),
      );
    }
    return ListView.separated(
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _customers[index];
        final on = _selected.contains(c.id);
        return Semantics(
          button: true,
          selected: on,
          label: c.displayName,
          excludeSemantics: true,
          child: Material(
            color: on ? AppColors.pink : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: AppColors.black, width: 1.2),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              onTap: () => setState(() {
                if (!_selected.remove(c.id)) _selected.add(c.id);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(size: 15, weight: FontWeight.w500),
                          ),
                          if (c.fullName?.trim().isNotEmpty ?? false)
                            Text(
                              c.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(size: 13, weight: FontWeight.w300),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      on ? Icons.check_circle_rounded : Icons.circle_outlined,
                      key: ValueKey(on ? 'picked' : 'not-picked'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
