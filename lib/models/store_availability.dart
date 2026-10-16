class StoreHoursDay {
  final int day;
  final bool isOpen;
  final String openTime;
  final String closeTime;

  const StoreHoursDay({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory StoreHoursDay.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final isOpen = json['isOpen'];
    final openTime = json['openTime'];
    final closeTime = json['closeTime'];
    if (day is! int ||
        isOpen is! bool ||
        openTime is! String ||
        closeTime is! String) {
      throw const FormatException('The store returned invalid weekday hours.');
    }
    return StoreHoursDay(
      day: day,
      isOpen: isOpen,
      openTime: openTime,
      closeTime: closeTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
      };

  StoreHoursDay copyWith({
    bool? isOpen,
    String? openTime,
    String? closeTime,
  }) {
    return StoreHoursDay(
      day: day,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

class StoreAvailability {
  final bool isOrderingEnabled;
  final bool isAcceptingOrders;
  final List<StoreHoursDay> weeklyHours;
  final String timeZone;
  final String statusMessage;

  const StoreAvailability({
    required this.isOrderingEnabled,
    required this.isAcceptingOrders,
    required this.weeklyHours,
    required this.timeZone,
    required this.statusMessage,
  });

  factory StoreAvailability.fromJson(Map<String, dynamic> json) {
    final isOrderingEnabled = json['isOrderingEnabled'];
    final isAcceptingOrders = json['isAcceptingOrders'];
    final rawHours = json['weeklyHours'];
    final timeZone = json['timeZone'];
    final statusMessage = json['statusMessage'];
    if (isOrderingEnabled is! bool ||
        isAcceptingOrders is! bool ||
        rawHours is! List ||
        timeZone is! String ||
        statusMessage is! String ||
        rawHours.any((day) => day is! Map<String, dynamic>)) {
      throw const FormatException('The store returned invalid availability settings.');
    }
    return StoreAvailability(
      isOrderingEnabled: isOrderingEnabled,
      isAcceptingOrders: isAcceptingOrders,
      weeklyHours: rawHours
          .cast<Map<String, dynamic>>()
          .map(StoreHoursDay.fromJson)
          .toList(growable: false),
      timeZone: timeZone,
      statusMessage: statusMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'isOrderingEnabled': isOrderingEnabled,
        'isAcceptingOrders': isAcceptingOrders,
        'weeklyHours': weeklyHours.map((day) => day.toJson()).toList(),
        'timeZone': timeZone,
        'statusMessage': statusMessage,
      };
}
