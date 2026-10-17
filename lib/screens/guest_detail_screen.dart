
import 'package:flutter/material.dart';

import '../models/guest.dart';
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
      final guest = await DatabaseService.instance
          .getGuestByCode(widget.code);

      if (!mounted) return;

      setState(() {
        _guest = guest;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmEntry() async {
    if (_saving || _guest == null || _guest!.used) {
      return;
    }

    setState(() => _saving = true);

    try {
      final success = await DatabaseService.instance
          .checkIn(_guest!.code);

      await _loadGuest();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Entrada registrada correctamente'
                : 'Este pase ya fue utilizado',
          ),
          backgroundColor: success
              ? AppColors.success
              : AppColors.warning,
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _peopleCard(
    String label,
    int value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} '
        '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final guest = _guest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pase'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Text('Error: $_error'),
                )
              : guest == null
                  ? const Center(
                      child: Text('Pase no encontrado'),
                    )
                  : SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  Icon(
                                    guest.used
                                        ? Icons.check_circle
                                        : Icons.confirmation_number_outlined,
                                    size: 65,
                                    color: guest.used
                                        ? AppColors.warning
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(height: 15),

                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: guest.used
                                          ? AppColors.warning
                                              .withOpacity(0.10)
                                          : AppColors.success
                                              .withOpacity(0.10),
                                      borderRadius:
                                          BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      guest.used
                                          ? 'PASE UTILIZADO'
                                          : 'PASE DISPONIBLE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: guest.used
                                            ? AppColors.warning
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Text(
                                    guest.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 27,
                                      color: AppColors.text,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    'Folio ${guest.code}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      letterSpacing: 1,
                                    ),
                                  ),

                                  const SizedBox(height: 25),

                                  Row(
                                    children: [
                                      _peopleCard(
                                        'Adultos',
                                        guest.adults,
                                        Icons.person_outline,
                                      ),
                                      const SizedBox(width: 12),
                                      _peopleCard(
                                        'Niños',
                                        guest.children,
                                        Icons.child_care_outlined,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 22),

                                  if (guest.used &&
                                      guest.checkedInAt != null)
                                    Container(
                                      width: double.infinity,
                                      padding:
                                          const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'Entrada registrada',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatDate(
                                              guest.checkedInAt!,
                                            ),
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          FilledButton.icon(
                            onPressed: guest.used || _saving
                                ? null
                                : _confirmEntry,
                            icon: Icon(
                              guest.used
                                  ? Icons.check_circle
                                  : Icons.how_to_reg,
                            ),
                            label: Text(
                              guest.used
                                  ? 'Entrada registrada'
                                  : _saving
                                      ? 'Guardando...'
                                      : 'Confirmar entrada',
                            ),
                          ),

                          const SizedBox(height: 12),

                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Volver a invitados',
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
