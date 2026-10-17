
import 'package:flutter/material.dart';

import '../models/guest.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final GuestStatus status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    switch (status) {
      case GuestStatus.pending:
        label = 'Pendiente';
        color = AppColors.muted;
      case GuestStatus.partial:
        label = 'Parcial';
        color = AppColors.warning;
      case GuestStatus.complete:
        label = 'Completo';
        color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
