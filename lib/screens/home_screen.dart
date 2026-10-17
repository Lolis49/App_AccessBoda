
import 'package:flutter/material.dart';

import '../models/guest.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

import 'guest_detail_screen.dart';
import 'scanner_screen.dart';
import 'import_guests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
      TextEditingController();

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
    final total = _stats['total_passes'] ?? 0;
    final used = _stats['used_passes'] ?? 0;

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
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Pases',
                  value: total,
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'Utilizados',
                  value: used,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'Pendientes',
                  value: total - used,
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                  color: guest.used
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                      '${guest.adults} adultos · '
                      '${guest.children} niños',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(used: guest.used),
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
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            18, 18, 18, 32,
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
}
