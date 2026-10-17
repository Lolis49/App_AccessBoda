import 'package:flutter/material.dart';

import '../models/guest.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

import 'guest_detail_screen.dart';
import 'scanner_screen.dart';
import 'import_guests_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Guest> _guests = [];
  Map<String, int> _stats = {};

  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final requestId = ++_requestId;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final db = DatabaseService.instance;

      final guests = await db.searchGuests(
        _searchController.text,
      );

      final stats = await db.getStatistics();

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _guests = guests;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (mounted) await _loadData();
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportGuestsScreen(),
      ),
    );

    if (mounted) await _loadData();
  }

  Future<void> _openStatistics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
    if (mounted) await _loadData();
  }

  Future<void> _openGuest(Guest guest) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestDetailScreen(
          code: guest.code,
        ),
      ),
    );

    if (mounted) await _loadData();
  }

  @override
  void dispose() {
    _requestId++;
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WEDDING ACCESS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            color: AppColors.gold,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Lolis & José',
          style: TextStyle(
            fontSize: 35,
            fontFamily: 'serif',
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Control de invitados · Octubre 2027',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de accesos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final total = _stats['total_passes'] ?? 0;
              final complete = _stats['used_passes'] ?? 0;
              final partial = _stats['partial_passes'] ?? 0;
              final pending = total - complete - partial;

              final cards = [
                StatCard(
                  label: 'Pases',
                  value: total,
                  icon: Icons.confirmation_number_outlined,
                ),
                StatCard(
                  label: 'Completos',
                  value: complete,
                  icon: Icons.check_circle_outline,
                ),
                StatCard(
                  label: 'Parciales',
                  value: partial,
                  icon: Icons.group_outlined,
                ),
                StatCard(
                  label: 'Pendientes',
                  value: pending,
                  icon: Icons.schedule,
                ),
              ];

              final width = (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: width,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _openStatistics,
            icon: const Icon(Icons.bar_chart),
            label: const Text('Ver panel de estadísticas'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear pase QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCard(Guest guest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openGuest(guest),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  guest.used
                      ? Icons.check_circle_outline
                      : Icons.people_outline,
                  color: guest.used ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guest.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      guest.code,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${guest.totalCheckedIn} de '
                      '${guest.totalPeople} personas ingresaron',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(status: guest.status),
                    const SizedBox(height: 8),
                    Text(
                      '${guest.adults} adultos · ${guest.children} niños',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Mesa: ${guest.tableLabel}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'L & J',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 23,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Importar invitados',
            icon: const Icon(
              Icons.file_upload_outlined,
            ),
            onPressed: _openImport,
          ),
          IconButton(
            tooltip: 'Reiniciar pruebas',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetTestData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            32,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: 25),
            _buildSummary(),
            const SizedBox(height: 28),
            const Text(
              'Lista de invitados',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _searchController,
              onChanged: (_) => _loadData(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar nombre o folio...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () {
                    _searchController.clear();
                    _loadData();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error al cargar invitados: $_error',
                  style: const TextStyle(
                    color: AppColors.error,
                  ),
                ),
              )
            else if (_guests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'No se encontraron invitados',
                    style: TextStyle(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                '${_guests.length} resultados',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              ..._guests.map(_buildGuestCard),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resetTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reiniciar pruebas'),
        content: const Text(
          '¿Deseas borrar todas las entradas '
          'registradas y su historial?\n\n'
          'La lista de invitados se conservará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService.instance.resetAllCheckIns();

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registros reiniciados correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reiniciar: $e'),
        ),
      );
    }
  }
}
