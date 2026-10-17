import 'guest.dart';

class TableAttendance {
  final int? tableNumber;
  final int invited;
  final int checkedIn;

  const TableAttendance({
    required this.tableNumber,
    required this.invited,
    required this.checkedIn,
  });

  int get pending => invited - checkedIn;
  double get progress => invited == 0 ? 0 : checkedIn / invited;
  String get label =>
      tableNumber == null ? 'Sin mesa asignada' : 'Mesa $tableNumber';
}

/// Resumen calculado sobre una sola lectura de todas las invitaciones.
class AttendanceStatistics {
  final int totalPasses;
  final int completePasses;
  final int partialPasses;
  final int pendingPasses;
  final int adults;
  final int children;
  final int checkedInAdults;
  final int checkedInChildren;
  final List<TableAttendance> tables;

  const AttendanceStatistics({
    required this.totalPasses,
    required this.completePasses,
    required this.partialPasses,
    required this.pendingPasses,
    required this.adults,
    required this.children,
    required this.checkedInAdults,
    required this.checkedInChildren,
    required this.tables,
  });

  int get invited => adults + children;
  int get checkedIn => checkedInAdults + checkedInChildren;
  int get pending => invited - checkedIn;
  int get pendingAdults => adults - checkedInAdults;
  int get pendingChildren => children - checkedInChildren;
  double get progress => invited == 0 ? 0 : checkedIn / invited;

  factory AttendanceStatistics.fromGuests(List<Guest> guests) {
    var complete = 0;
    var partial = 0;
    var pending = 0;
    var adults = 0;
    var children = 0;
    var checkedAdults = 0;
    var checkedChildren = 0;
    final tables = <int?, TableAttendance>{};

    for (final guest in guests) {
      switch (guest.status) {
        case GuestStatus.complete:
          complete++;
        case GuestStatus.partial:
          partial++;
        case GuestStatus.pending:
          pending++;
      }
      adults += guest.adults;
      children += guest.children;
      checkedAdults += guest.checkedInAdults;
      checkedChildren += guest.checkedInChildren;
      final table = tables[guest.tableNumber];
      tables[guest.tableNumber] = TableAttendance(
        tableNumber: guest.tableNumber,
        invited: (table?.invited ?? 0) + guest.totalPeople,
        checkedIn: (table?.checkedIn ?? 0) + guest.totalCheckedIn,
      );
    }

    final sortedTables = tables.values.toList()
      ..sort((a, b) {
        if (a.tableNumber == null) return b.tableNumber == null ? 0 : 1;
        if (b.tableNumber == null) return -1;
        return a.tableNumber!.compareTo(b.tableNumber!);
      });

    return AttendanceStatistics(
      totalPasses: guests.length,
      completePasses: complete,
      partialPasses: partial,
      pendingPasses: pending,
      adults: adults,
      children: children,
      checkedInAdults: checkedAdults,
      checkedInChildren: checkedChildren,
      tables: List.unmodifiable(sortedTables),
    );
  }
}
