enum GuestStatus {
  pending,
  partial,
  complete,
}

class Guest {
  final String code;
  final String name;
  final int adults;
  final int children;
  final int? tableNumber;
  final int checkedInAdults;
  final int checkedInChildren;
  final bool used;
  final DateTime? checkedInAt;

  const Guest({
    required this.code,
    required this.name,
    required this.adults,
    required this.children,
    this.tableNumber,
    this.checkedInAdults = 0,
    this.checkedInChildren = 0,
    this.used = false,
    this.checkedInAt,
  });

  int get totalPeople => adults + children;

  int get totalCheckedIn => checkedInAdults + checkedInChildren;

  int get pendingAdults => adults - checkedInAdults;

  int get pendingChildren => children - checkedInChildren;

  int get totalPending => pendingAdults + pendingChildren;

  GuestStatus get status {
    if (totalCheckedIn == 0) {
      return GuestStatus.pending;
    }

    if (totalPending == 0) {
      return GuestStatus.complete;
    }

    return GuestStatus.partial;
  }

  factory Guest.fromJson(
    String code,
    Map<String, dynamic> json,
  ) {
    return Guest(
      code: code.trim().toUpperCase(),
      name: json['name'] as String,
      adults: (json['adults'] as num).toInt(),
      children: (json['children'] as num).toInt(),
      tableNumber: parseTableNumber(json['mesa']),
    );
  }

  factory Guest.fromMap(Map<String, Object?> map) {
    final date = map['checked_in_at'] as String?;

    return Guest(
      code: map['code'] as String,
      name: map['name'] as String,
      adults: map['adults'] as int,
      children: map['children'] as int,
      tableNumber: map['table_number'] as int?,
      checkedInAdults: (map['checked_in_adults'] as int?) ?? 0,
      checkedInChildren: (map['checked_in_children'] as int?) ?? 0,
      used: (map['used'] as int) == 1,
      checkedInAt: date == null ? null : DateTime.parse(date),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'name': name,
      'adults': adults,
      'children': children,
      'table_number': tableNumber,
      'checked_in_adults': checkedInAdults,
      'checked_in_children': checkedInChildren,
      'used': used ? 1 : 0,
      'checked_in_at': checkedInAt?.toIso8601String(),
    };
  }

  static int? parseTableNumber(Object? value) {
    if (value == null) return null;
    if (value is! int || value <= 0) {
      throw const FormatException(
        'El campo "mesa" debe ser un entero mayor que cero.',
      );
    }
    return value;
  }

  String get tableLabel => tableNumber?.toString() ?? 'Sin asignar';
}
