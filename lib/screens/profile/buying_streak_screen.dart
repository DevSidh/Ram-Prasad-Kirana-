import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/buying_streak.dart';
import '../../services/api_service.dart';

class BuyingStreakScreen extends StatefulWidget {
  const BuyingStreakScreen({super.key});

  @override
  State<BuyingStreakScreen> createState() => _BuyingStreakScreenState();
}

class _BuyingStreakScreenState extends State<BuyingStreakScreen> {
  BuyingStreakSnapshot? _snapshot;
  String? _error;
  bool _loading = true;
  final Set<int> _claimingDays = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final response =
          await context.read<ApiService>().get('/account/buying-streak');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('The server returned an invalid streak.');
      }
      final snapshot = BuyingStreakSnapshot.fromJson(response);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _claim(BuyingStreakReward reward) async {
    if (!reward.isUnlocked || reward.claimedAt != null) return;
    setState(() => _claimingDays.add(reward.day));
    try {
      await context.read<ApiService>().post(
        '/account/buying-streak/rewards/${reward.day}/claim',
        const {},
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day ${reward.day} reward claimed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingDays.remove(reward.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Buying day streak')),
      body: _loading && snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && snapshot == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            setState(() => _loading = true);
                            unawaited(_load());
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                        sliver: SliverToBoxAdapter(
                          child: _StreakSummary(
                            currentStreak: snapshot?.currentStreak ?? 0,
                          ),
                        ),
                      ),
                      if (snapshot?.rewards.isNotEmpty ?? false)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                          sliver: SliverList.builder(
                            itemCount: snapshot!.rewards.length,
                            itemBuilder: (context, index) {
                              final reward = snapshot.rewards[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RewardTile(
                                  reward: reward,
                                  isClaiming:
                                      _claimingDays.contains(reward.day),
                                  onClaim: () => _claim(reward),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No streak rewards are set up yet.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StreakSummary extends StatelessWidget {
  const _StreakSummary({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF183D2A),
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF183D2A), Color(0xFF246B42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFFFC857), size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BUYING DAY STREAK',
                  style: TextStyle(
                    color: Color(0xFFD5EBDD),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currentStreak ${currentStreak == 1 ? 'day' : 'days'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Place an order each day to keep your streak.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.isClaiming,
    required this.onClaim,
  });

  final BuyingStreakReward reward;
  final bool isClaiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final claimed = reward.claimedAt != null;
    final unlocked = reward.isUnlocked;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFFEAF6ED) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked
              ? AppConstants.primary.withValues(alpha: .35)
              : AppConstants.borderLight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: unlocked ? AppConstants.primary : Colors.black12,
            foregroundColor: unlocked ? Colors.white : Colors.black54,
            child: Text('${reward.day}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day ${reward.day} · ${reward.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  reward.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x99000000),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claimed)
            const Icon(Icons.check_circle, color: AppConstants.primary)
          else if (unlocked)
            FilledButton(
              onPressed: isClaiming ? null : onClaim,
              child: isClaiming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Claim'),
            )
          else
            const Icon(Icons.lock_outline, color: Colors.black38),
        ],
      ),
    );
  }
}
