import 'package:flutter/material.dart';

import '../models/attendance_statistics.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

class StatisticsScreen extends StatefulWidget {
  final Future<AttendanceStatistics> Function()? loadStatistics;

  const StatisticsScreen({super.key, this.loadStatistics});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  AttendanceStatistics? _statistics;
  bool _loading = true;
  String? _error;
  DateTime? _updatedAt;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.loadStatistics ??
          DatabaseService.instance.getAttendanceStatistics;
      final statistics = await loader();
      if (!mounted || request != _requestId) return;
      setState(() {
        _statistics = statistics;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = 'No se pudieron cargar las estadísticas. Intenta actualizar.';
        _loading = false;
      });
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                )),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _cards(List<StatCard> cards) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600
          ? 3
          : constraints.maxWidth >= 260
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _progress(String title, int checkedIn, int invited, {Color? color}) {
    final progress = invited == 0 ? 0.0 : checkedIn / invited;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(
              '$checkedIn de $invited ingresaron · ${invited - checkedIn} pendientes',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 9,
            color: color ?? AppColors.primary,
            backgroundColor: AppColors.border,
            semanticsLabel: title,
            semanticsValue: '${(progress * 100).toStringAsFixed(1)} %',
          ),
        ],
      ),
    );
  }

  List<Widget> _content(AttendanceStatistics stats) {
    final updated = _updatedAt!;
    final time = '${updated.hour.toString().padLeft(2, '0')}:'
        '${updated.minute.toString().padLeft(2, '0')}';
    return [
      Text('Actualizado a las $time · Datos de este dispositivo',
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 16),
      if (stats.totalPasses == 0) ...[
        const Text(
            'Aún no hay invitados. Importa tu Excel desde Inicio para comenzar.'),
        const SizedBox(height: 16),
      ],
      _section('Asistencia general', [
        Text('${(stats.progress * 100).toStringAsFixed(1)} %',
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
        const SizedBox(height: 12),
        _progress('Personas', stats.checkedIn, stats.invited),
        _cards([
          StatCard(
              label: 'Invitados',
              value: stats.invited,
              icon: Icons.people_outline),
          StatCard(
              label: 'Ingresaron', value: stats.checkedIn, icon: Icons.login),
          StatCard(
              label: 'Por ingresar',
              value: stats.pending,
              icon: Icons.schedule),
        ]),
      ]),
      const SizedBox(height: 16),
      _section('Estado de las invitaciones', [
        _cards([
          StatCard(
              label: 'Total de pases',
              value: stats.totalPasses,
              icon: Icons.confirmation_number_outlined),
          StatCard(
              label: 'Completos',
              value: stats.completePasses,
              icon: Icons.check_circle_outline),
          StatCard(
              label: 'Parciales',
              value: stats.partialPasses,
              icon: Icons.group_outlined),
          StatCard(
              label: 'Sin ingresos',
              value: stats.pendingPasses,
              icon: Icons.schedule),
        ]),
        const SizedBox(height: 12),
        const Text(
            'Completo: ingresaron todos. Parcial: falta parte del grupo. '
            'Sin ingresos: nadie del pase ha ingresado.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
      const SizedBox(height: 16),
      _section('Adultos y niños', [
        _progress('Adultos', stats.checkedInAdults, stats.adults),
        _progress('Niños', stats.checkedInChildren, stats.children,
            color: AppColors.gold),
      ]),
      const SizedBox(height: 16),
      _section('Asistencia por mesa', [
        const Text(
            'Ingresos registrados respecto a las personas asignadas a cada mesa.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 16),
        if (stats.tables.isEmpty) const Text('Sin mesas para mostrar.'),
        for (final table in stats.tables)
          _progress(table.label, table.checkedIn, table.invited),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de estadísticas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar estadísticas',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar')),
            ] else if (_statistics != null)
              ..._content(_statistics!),
          ],
        ),
      ),
    );
  }
}
