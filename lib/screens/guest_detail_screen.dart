
import 'package:flutter/material.dart';

import '../models/guest.dart';
import '../models/check_in_event.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class GuestDetailScreen extends StatefulWidget {
  final String code;

  const GuestDetailScreen({
    super.key,
    required this.code,
  });

  @override
  State<GuestDetailScreen> createState() =>
      _GuestDetailScreenState();
}

class _GuestDetailScreenState
    extends State<GuestDetailScreen> {
  Guest? _guest;
  List<CheckInEvent> _history = [];

  int _adultsToRegister = 0;
  int _childrenToRegister = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuest();
  }

  Future<void> _loadGuest() async {
    try {
      final db = DatabaseService.instance;

      final guest = await db.getGuestByCode(widget.code);
      final history =
          await db.getCheckInHistory(widget.code);

      if (!mounted) return;

      setState(() {
        _guest = guest;
        _history = history;
        _loading = false;
        _error = null;

        _adultsToRegister = 0;
        _childrenToRegister = 0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  String _statusText(Guest guest) {
    switch (guest.status) {
      case GuestStatus.pending:
        return 'PASE PENDIENTE';
      case GuestStatus.partial:
        return 'ENTRADA PARCIAL';
      case GuestStatus.complete:
        return 'ENTRADA COMPLETA';
    }
  }

  Color _statusColor(Guest guest) {
    switch (guest.status) {
      case GuestStatus.pending:
        return AppColors.muted;
      case GuestStatus.partial:
        return AppColors.warning;
      case GuestStatus.complete:
        return AppColors.success;
    }
  }

  Future<void> _confirmEntry() async {
    if (_saving || _guest == null) return;

    final adults = _adultsToRegister;
    final children = _childrenToRegister;

    if (adults + children == 0) return;

    final guest = _guest!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar ingreso'),
        content: Text(
          '¿Registrar $adults adultos y '
          '$children niños para ${guest.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      await DatabaseService.instance.registerPartialEntry(
        code: guest.code,
        adults: adults,
        children: children,
      );

      await _loadGuest();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingreso registrado correctamente',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar: $e'),
          backgroundColor: AppColors.error,
        ),
      );

      // Recargar por si cambiaron los cupos.
      await _loadGuest();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _quantitySelector({
    required String label,
    required IconData icon,
    required int value,
    required int maximum,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$maximum disponibles',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _saving || value == 0
                ? null
                : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 35,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _saving || value >= maximum
                ? null
                : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _countRow(
    String label,
    int checked,
    int total,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$checked / $total',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Guest guest) {
    final statusColor = _statusColor(guest);
    final progress = guest.totalPeople == 0
        ? 0.0
        : guest.totalCheckedIn / guest.totalPeople;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  guest.status == GuestStatus.complete
                      ? Icons.check_circle
                      : Icons.confirmation_number_outlined,
                  color: statusColor,
                  size: 60,
                ),
                const SizedBox(height: 14),
                Text(
                  guest.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 26,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Folio: ${guest.code}',
                  style: const TextStyle(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _statusText(guest),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Mesa: ${guest.tableLabel}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _countRow(
                  'Adultos ingresados',
                  guest.checkedInAdults,
                  guest.adults,
                ),
                _countRow(
                  'Niños ingresados',
                  guest.checkedInChildren,
                  guest.children,
                ),
                const SizedBox(height: 15),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
                const SizedBox(height: 9),
                Text(
                  '${guest.totalCheckedIn} de '
                  '${guest.totalPeople} personas ingresaron',
                  style: const TextStyle(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (guest.totalPending > 0) ...[
          const Text(
            'Registrar nueva entrada',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 22,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),

          _quantitySelector(
            label: 'Adultos',
            icon: Icons.person_outline,
            value: _adultsToRegister,
            maximum: guest.pendingAdults,
            onChanged: (value) {
              setState(() {
                _adultsToRegister = value;
              });
            },
          ),

          const SizedBox(height: 10),

          _quantitySelector(
            label: 'Niños',
            icon: Icons.child_care_outlined,
            value: _childrenToRegister,
            maximum: guest.pendingChildren,
            onChanged: (value) {
              setState(() {
                _childrenToRegister = value;
              });
            },
          ),

          const SizedBox(height: 18),

          FilledButton.icon(
            onPressed: _saving ||
                    _adultsToRegister +
                            _childrenToRegister ==
                        0
                ? null
                : _confirmEntry,
            icon: const Icon(Icons.how_to_reg),
            label: Text(
              _saving
                  ? 'Guardando...'
                  : 'Confirmar ingreso '
                    '(${_adultsToRegister + _childrenToRegister})',
            ),
          ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified,
                    color: AppColors.success,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Todos los invitados de este pase '
                    'han ingresado.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 28),

        const Text(
          'Historial de entradas',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 10),

        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text(
              'No hay movimientos individuales '
              'registrados en el historial.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          ..._history.map(
            (event) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const Icon(
                  Icons.history,
                  color: AppColors.primary,
                ),
                title: Text(
                  '${event.adults} adultos · '
                  '${event.children} niños',
                ),
                subtitle: Text(
                  _formatDate(event.createdAt),
                ),
              ),
            ),
          ),

        const SizedBox(height: 20),

        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver a invitados'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pase'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? Center(
                    child: Text('Error: $_error'),
                  )
                : _guest == null
                    ? const Center(
                        child: Text('Pase no encontrado'),
                      )
                    : _buildContent(_guest!),
      ),
    );
  }
}
