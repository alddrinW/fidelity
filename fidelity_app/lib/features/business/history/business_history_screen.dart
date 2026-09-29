import 'package:flutter/material.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';

class BusinessHistoryScreen extends StatefulWidget {
  final String businessId;

  const BusinessHistoryScreen({super.key, required this.businessId});

  @override
  State<BusinessHistoryScreen> createState() => _BusinessHistoryScreenState();
}

class _BusinessHistoryScreenState extends State<BusinessHistoryScreen> {
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _transfers = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiClient().get('scans/business/${widget.businessId}', queryParams: {'status': 'approved'}),
        ApiClient().get('rewards/business/${widget.businessId}'),
        ApiClient().get('rewards/transfers', queryParams: {'businessId': widget.businessId}),
      ]);

      var rawScans = results[0] is List ? List<Map<String, dynamic>>.from(results[0] as List) : <Map<String, dynamic>>[];
      var rawRewards = results[1] is List ? List<Map<String, dynamic>>.from(results[1] as List) : <Map<String, dynamic>>[];
      var rawTransfers = results[2] is List ? List<Map<String, dynamic>>.from(results[2] as List) : <Map<String, dynamic>>[];

      if (_dateRange != null) {
        final start = _dateRange!.start;
        final end = _dateRange!.end.add(const Duration(days: 1));

        rawScans = rawScans.where((s) {
          final dtStr = s['scannedAt'] ?? s['scanned_at'];
          if (dtStr == null) return false;
          final dt = DateTime.tryParse(dtStr.toString())?.toLocal();
          return dt != null && dt.isAfter(start) && dt.isBefore(end);
        }).toList();

        rawRewards = rawRewards.where((r) {
          final dtStr = r['earnedAt'] ?? r['earned_at'];
          if (dtStr == null) return false;
          final dt = DateTime.tryParse(dtStr.toString())?.toLocal();
          return dt != null && dt.isAfter(start) && dt.isBefore(end);
        }).toList();

        rawTransfers = rawTransfers.where((t) {
          final dtStr = t['transferredAt'] ?? t['created_at'];
          if (dtStr == null) return false;
          final dt = DateTime.tryParse(dtStr.toString())?.toLocal();
          return dt != null && dt.isAfter(start) && dt.isBefore(end);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _scans = rawScans;
          _rewards = rawRewards;
          _transfers = rawTransfers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = _dateRange ??
        DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now());

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() => _dateRange = pickedRange);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial de Actividad'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Escaneos'),
              Tab(text: 'Premios'),
              Tab(text: 'Traspasos'),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black38,
            indicatorColor: Colors.black,
            isScrollable: true,
          ),
          actions: [
            IconButton(
              icon: Icon(_dateRange == null ? Icons.filter_alt_outlined : Icons.filter_alt),
              onPressed: _selectDateRange,
              color: _dateRange == null ? null : Colors.black,
            ),
            if (_dateRange != null)
              IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { setState(() => _dateRange = null); _loadHistory(); }),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple)))
            : TabBarView(children: [_buildScansList(), _buildRewardsList(), _buildTransfersList()]),
      ),
    );
  }

  Widget _buildScansList() {
    if (_scans.isEmpty) return const Center(child: Text('No hay escaneos en este periodo'));
    return ListView.builder(
      itemCount: _scans.length,
      itemBuilder: (context, index) {
        final scan = _scans[index];
        final profileName = scan['user']?['fullName'] ?? scan['profiles']?['full_name'] ?? 'Usuario';
        final dateStr = scan['scannedAt'] ?? scan['scanned_at'] ?? '';
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(profileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(EcuadorDateUtils.formatEcuadorTime(dateStr)),
          trailing: const Text('+1 Punto', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildRewardsList() {
    if (_rewards.isEmpty) return const Center(child: Text('No hay premios en este periodo'));
    return ListView.builder(
      itemCount: _rewards.length,
      itemBuilder: (context, index) {
        final reward = _rewards[index];
        final profileName = reward['user']?['fullName'] ?? reward['profiles']?['full_name'] ?? 'Usuario';
        final dateStr = reward['earnedAt'] ?? reward['earned_at'] ?? '';
        return ListTile(
          leading: const Icon(Icons.card_giftcard, color: AppTheme.accentPurple),
          title: Text(profileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reward['description'] ?? 'Premio', style: const TextStyle(color: AppTheme.accentPurple, fontWeight: FontWeight.w600)),
              Text(EcuadorDateUtils.formatEcuadorTime(dateStr)),
            ],
          ),
          trailing: const Text('- Pts', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildTransfersList() {
    if (_transfers.isEmpty) return const Center(child: Text('No hay transferencias en este periodo'));
    return ListView.builder(
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final transfer = _transfers[index];
        final fromName = transfer['fromUser']?['fullName'] ?? transfer['from_user']?['full_name'] ?? 'Alguien';
        final toName = transfer['toUser']?['fullName'] ?? transfer['to_user']?['full_name'] ?? 'Alguien';
        final pts = transfer['reward']?['pointsRequired'] ?? transfer['rewards']?['points_used'] ?? '';
        final dateStr = transfer['transferredAt'] ?? transfer['created_at'] ?? '';
        return ListTile(
          leading: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
          title: Text('$fromName -> $toName', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Premio transferido', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
              Text(EcuadorDateUtils.formatEcuadorTime(dateStr)),
            ],
          ),
          trailing: Text('$pts Pts', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}

