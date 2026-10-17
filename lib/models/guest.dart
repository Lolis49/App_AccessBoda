
class Guest {
  final String code;
  final String name;
  final int adults;
  final int children;
  final bool used;
  final DateTime? checkedInAt;

  const Guest({
    required this.code,
    required this.name,
    required this.adults,
    required this.children,
    this.used = false,
    this.checkedInAt,
  });

  int get totalPeople => adults + children;

  factory Guest.fromJson(
    String code,
    Map<String, dynamic> json,
  ) {
    return Guest(
      code: code.trim().toUpperCase(),
      name: json['name'] as String,
      adults: (json['adults'] as num).toInt(),
      children: (json['children'] as num).toInt(),
    );
  }

  factory Guest.fromMap(Map<String, Object?> map) {
    final checkedIn = map['checked_in_at'] as String?;

    return Guest(
      code: map['code'] as String,
      name: map['name'] as String,
      adults: map['adults'] as int,
      children: map['children'] as int,
      used: (map['used'] as int) == 1,
      checkedInAt: checkedIn == null
          ? null
          : DateTime.parse(checkedIn),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'name': name,
      'adults': adults,
      'children': children,
      'used': used ? 1 : 0,
      'checked_in_at': checkedInAt?.toIso8601String(),
    };
  }
}
