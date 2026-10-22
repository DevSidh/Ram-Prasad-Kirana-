class BuyingStreakReward {
  final int day;
  final String title;
  final String description;
  final bool isUnlocked;
  final String? unlockedAt;
  final String? claimedAt;

  const BuyingStreakReward({
    required this.day,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.claimedAt,
  });

  factory BuyingStreakReward.fromJson(Map<String, dynamic> json) {
    if (json['day'] is! int ||
        json['title'] is! String ||
        json['description'] is! String ||
        json['isUnlocked'] is! bool) {
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
    );
  }
}

class BuyingStreakSnapshot {
  final int currentStreak;
  final String? lastPurchaseDay;
  final List<BuyingStreakReward> rewards;

  const BuyingStreakSnapshot({
    required this.currentStreak,
    required this.lastPurchaseDay,
    required this.rewards,
  });

  factory BuyingStreakSnapshot.fromJson(Map<String, dynamic> json) {
    final currentStreak = json['currentStreak'];
    final rawRewards = json['rewards'];
    if (currentStreak is! int || rawRewards is! List) {
      throw const FormatException(
          'The server returned an invalid buying streak.');
    }
    return BuyingStreakSnapshot(
      currentStreak: currentStreak,
      lastPurchaseDay: json['lastPurchaseDay'] as String?,
      rewards: rawRewards
          .whereType<Map<String, dynamic>>()
          .map(BuyingStreakReward.fromJson)
          .toList(growable: false),
    );
  }
}
