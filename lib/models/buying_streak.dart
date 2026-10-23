class BuyingStreakReward {
  final int day;
  final String title;
  final String description;
  final bool isUnlocked;
  final String? unlockedAt;
  final String? claimedAt;
  final String? couponCode;

  const BuyingStreakReward({
    required this.day,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.claimedAt,
    this.couponCode,
  });

  factory BuyingStreakReward.fromJson(Map<String, dynamic> json) {
    if (json['day'] is! int ||
        json['title'] is! String ||
        json['description'] is! String ||
        json['isUnlocked'] is! bool ||
        (json['couponCode'] != null && json['couponCode'] is! String)) {
      throw const FormatException(
          'The server returned an invalid streak reward.');
    }
    return BuyingStreakReward(
      day: json['day'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      isUnlocked: json['isUnlocked'] as bool,
      unlockedAt: json['unlockedAt'] as String?,
      claimedAt: json['claimedAt'] as String?,
      couponCode: json['couponCode'] as String?,
    );
  }
}

class BuyingStreakSnapshot {
  final int currentStreak;
  final int bestStreak;
  final int totalPurchaseDays;
  final int lastConsecutiveStreak;
  final String? lastPurchaseDay;
  final String? calendarMonth;
  final int daysInMonth;
  final int monthStartWeekday;
  final List<String> monthPurchaseDays;
  final bool hasPurchasedToday;
  final bool streakAtRisk;
  final bool streakBroken;
  final String profileLevel;
  final int? nextRewardDay;
  final int? daysToNextReward;
  final List<BuyingStreakReward> rewards;

  const BuyingStreakSnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalPurchaseDays,
    required this.lastConsecutiveStreak,
    required this.lastPurchaseDay,
    required this.calendarMonth,
    required this.daysInMonth,
    required this.monthStartWeekday,
    required this.monthPurchaseDays,
    required this.hasPurchasedToday,
    required this.streakAtRisk,
    required this.streakBroken,
    required this.profileLevel,
    required this.nextRewardDay,
    required this.daysToNextReward,
    required this.rewards,
  });

  factory BuyingStreakSnapshot.fromJson(Map<String, dynamic> json) {
    final currentStreak = json['currentStreak'];
    final rawRewards = json['rewards'];
    if (currentStreak is! int || rawRewards is! List) {
      throw const FormatException(
          'The server returned an invalid buying streak.');
    }
    final monthPurchaseDays = json['monthPurchaseDays'];
    final daysInMonth = json['daysInMonth'];
    final monthStartWeekday = json['monthStartWeekday'];
    if (monthPurchaseDays != null &&
        (monthPurchaseDays is! List ||
            monthPurchaseDays.any((day) => day is! String))) {
      throw const FormatException(
        'The server returned an invalid buying streak calendar.',
      );
    }
    if (daysInMonth != null && daysInMonth is! int) {
      throw const FormatException(
        'The server returned an invalid buying streak calendar.',
      );
    }
    if (monthStartWeekday != null && monthStartWeekday is! int) {
      throw const FormatException(
        'The server returned an invalid buying streak calendar.',
      );
    }
    final nextRewardDay = json['nextRewardDay'];
    final daysToNextReward = json['daysToNextReward'];
    if ((nextRewardDay != null && nextRewardDay is! int) ||
        (daysToNextReward != null && daysToNextReward is! int)) {
      throw const FormatException(
        'The server returned invalid buying streak milestones.',
      );
    }
    return BuyingStreakSnapshot(
      currentStreak: currentStreak,
      bestStreak:
          json['bestStreak'] is int ? json['bestStreak'] as int : currentStreak,
      totalPurchaseDays: json['totalPurchaseDays'] is int
          ? json['totalPurchaseDays'] as int
          : 0,
      lastConsecutiveStreak: json['lastConsecutiveStreak'] is int
          ? json['lastConsecutiveStreak'] as int
          : currentStreak,
      lastPurchaseDay: json['lastPurchaseDay'] as String?,
      calendarMonth: json['calendarMonth'] as String?,
      daysInMonth: daysInMonth as int? ?? 0,
      monthStartWeekday: monthStartWeekday as int? ?? 0,
      monthPurchaseDays:
          (monthPurchaseDays as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      hasPurchasedToday: json['hasPurchasedToday'] as bool? ?? false,
      streakAtRisk: json['streakAtRisk'] as bool? ?? false,
      streakBroken: json['streakBroken'] as bool? ?? false,
      profileLevel: json['profileLevel'] as String? ?? 'New shopper',
      nextRewardDay: nextRewardDay as int?,
      daysToNextReward: daysToNextReward as int?,
      rewards: rawRewards
          .whereType<Map<String, dynamic>>()
          .map(BuyingStreakReward.fromJson)
          .toList(growable: false),
    );
  }
}
