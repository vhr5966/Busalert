/// Model representing an official bus route parsed from /api/routes.
///
/// Ensures official route numbers, names, and operator metadata are used
/// instead of hardcoded strings.
library;

class BusRoute {
  final String id;
  final String number;
  final String name;
  final String operatorId;
  final String operatorName;
  final bool isActive;

  const BusRoute({
    required this.id,
    required this.number,
    required this.name,
    required this.operatorId,
    required this.operatorName,
    this.isActive = true,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      operatorId: json['operatorId'] as String? ?? 'cardiff-bus',
      operatorName: json['operatorName'] as String? ?? 'Cardiff Bus',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'isActive': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusRoute &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          number == other.number;

  @override
  int get hashCode => id.hashCode ^ number.hashCode;
}
