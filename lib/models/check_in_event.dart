
class CheckInEvent {
  final int id;
  final String guestCode;
  final int adults;
  final int children;
  final DateTime createdAt;

  const CheckInEvent({
    required this.id,
    required this.guestCode,
    required this.adults,
    required this.children,
    required this.createdAt,
  });

  factory CheckInEvent.fromMap(
    Map<String, Object?> map,
  ) {
    return CheckInEvent(
      id: map['id'] as int,
      guestCode: map['guest_code'] as String,
      adults: map['adults'] as int,
      children: map['children'] as int,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }
}
