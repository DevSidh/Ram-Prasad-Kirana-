import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/buying_streak.dart';
import '../../navigation/main_bottom_nav.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class BuyingStreakScreen extends StatefulWidget {
  const BuyingStreakScreen({super.key});

  @override
  State<BuyingStreakScreen> createState() => _BuyingStreakScreenState();
}

class _BuyingStreakScreenState extends State<BuyingStreakScreen> {
  BuyingStreakSnapshot? _snapshot;
  String? _error;
  bool _loading = true;
  bool _rewardPopupShown = false;
  final Set<int> _claimingDays = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  bool get _isCustomer {
    final auth = context.read<AuthProvider>();
    return auth.isAuthenticated &&
        auth.currentUser?.role.toUpperCase() == 'CUSTOMER';
  }

  Future<void> _load() async {
    if (!_isCustomer) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    try {
      final response =
          await context.read<ApiService>().get('/account/buying-streak');
      if (response is! Map<String, dynamic>) {
        throw const FormatException('The store returned an invalid streak.');
      }
      final snapshot = BuyingStreakSnapshot.fromJson(response);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
      unawaited(_showUnlockedRewardOnce(snapshot));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _showUnlockedRewardOnce(
    BuyingStreakSnapshot snapshot,
  ) async {
    if (_rewardPopupShown) return;
    final reward = snapshot.rewards.cast<BuyingStreakReward?>().firstWhere(
          (item) => item!.isUnlocked && item.claimedAt == null,
          orElse: () => null,
        );
    if (reward == null) return;

    final userId = context.read<AuthProvider>().currentUser?.id ?? 'customer';
    final prefs = await SharedPreferences.getInstance();
    final key =
        'streak_reward_seen_${userId}_${reward.day}_${reward.unlockedAt ?? ''}';
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    _rewardPopupShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFE6A82E),
              size: 38,
            ),
            title: Text('${reward.title} unlocked'),
            content: Text(reward.description),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openReward(reward);
                },
                child: const Text('View reward'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _claim(BuyingStreakReward reward) async {
    if (!reward.isUnlocked ||
        reward.claimedAt != null ||
        _claimingDays.contains(reward.day)) {
      return;
    }
    setState(() => _claimingDays.add(reward.day));
    try {
      await context.read<ApiService>().post(
        '/account/buying-streak/rewards/${reward.day}/claim',
        const {},
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${reward.title} claimed.')),
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

  void _openReward(BuyingStreakReward reward) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BuyingStreakRewardDetailScreen(
          reward: reward,
          isClaiming: _claimingDays.contains(reward.day),
          onClaim: () => _claim(reward),
        ),
      ),
    );
  }

  void _openRewards() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BuyingStreakRewardsScreen(
          snapshot: snapshot,
          claimingDays: _claimingDays,
          onRewardTap: _openReward,
        ),
      ),
    );
  }

  Future<void> _login() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(returnToCaller: true),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _register() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _toggleTheme() async {
    final theme = context.read<ThemeProvider?>();
    if (theme != null) await theme.setDarkMode(!theme.isDarkMode);
  }

  void _openHowItWorks() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BuyingStreakHowItWorksScreen(),
      ),
    );
  }

  void _openReminders() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BuyingStreakRemindersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isCustomer = auth.isAuthenticated &&
        auth.currentUser?.role.toUpperCase() == 'CUSTOMER';
    final snapshot = _snapshot;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buying day streak'),
        actions: [
          IconButton(
            tooltip: 'How it works',
            onPressed: _openHowItWorks,
            icon: const Icon(Icons.info_outline_rounded),
          ),
          IconButton(
            tooltip: 'Streak reminders',
            onPressed: _openReminders,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: _toggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: !isCustomer
          ? _GuestStreakPrompt(onLogin: _login, onRegister: _register)
          : _loading && snapshot == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && snapshot == null
                  ? _StreakLoadError(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        key: const ValueKey('buying-streak-scroll'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                            sliver: SliverToBoxAdapter(
                              child: _StreakHero(
                                snapshot: snapshot!,
                                onShop: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const MainBottomNav(initialIndex: 0),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_error != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 10),
                                child: _InlineStreakError(
                                  message: _error!,
                                  onRetry: _load,
                                ),
                              ),
                            ),
                          if (snapshot.streakAtRisk)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                              sliver: SliverToBoxAdapter(
                                child: _RiskCard(
                                  currentStreak: snapshot.currentStreak,
                                ),
                              ),
                            ),
                          if (snapshot.streakBroken)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                              sliver: SliverToBoxAdapter(
                                child: _BrokenStreakCard(
                                  lastStreak: snapshot.lastConsecutiveStreak,
                                  bestStreak: snapshot.bestStreak,
                                  onShop: () {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const MainBottomNav(
                                          initialIndex: 0,
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeading(
                                title: 'Milestone path',
                                action: snapshot.rewards.isEmpty
                                    ? null
                                    : 'My rewards',
                                onAction: _openRewards,
                              ),
                            ),
                          ),
                          if (snapshot.rewards.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(18, 0, 18, 12),
                                child: _SurfaceCard(
                                  child: Text(
                                    'No streak milestones are available yet. Check back after the store adds its rewards.',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 156,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: snapshot.rewards.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final reward = snapshot.rewards[index];
                                    return _MilestoneCard(
                                      reward: reward,
                                      currentStreak: snapshot.currentStreak,
                                      isClaiming:
                                          _claimingDays.contains(reward.day),
                                      onTap: () => _openReward(reward),
                                    );
                                  },
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
                            sliver: SliverToBoxAdapter(
                              child: _SectionHeading(
                                title: 'This month',
                                action: snapshot.calendarMonth,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                            sliver: SliverToBoxAdapter(
                              child: _MonthHeatmap(snapshot: snapshot),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                            sliver: SliverToBoxAdapter(
                              child: _ProfileLevelCard(snapshot: snapshot),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                            sliver: SliverToBoxAdapter(
                              child: _StreakShortcuts(
                                onRewards: _openRewards,
                                onHowItWorks: _openHowItWorks,
                                onReminders: _openReminders,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.snapshot, required this.onShop});

  final BuyingStreakSnapshot snapshot;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final hasStreak = snapshot.currentStreak > 0;
    final rewardDay = snapshot.nextRewardDay;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF123B2B), Color(0xFF216846)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123B2B).withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFFC857),
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasStreak ? 'YOUR BUYING STREAK' : 'YOUR NEXT CHAPTER',
                  style: const TextStyle(
                    color: Color(0xFFD5EBDD),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              if (snapshot.hasPurchasedToday)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF8EF1A8),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${snapshot.currentStreak}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 60,
                  height: .95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'days',
                  style: TextStyle(
                    color: Color(0xFFD5EBDD),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasStreak
                ? snapshot.hasPurchasedToday
                    ? 'Today counts. Keep your rhythm going.'
                    : 'Place an order today to keep your streak alive.'
                : 'Place your first order to start a streak.',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          if (rewardDay != null && snapshot.daysToNextReward != null) ...[
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: rewardDay <= 0
                    ? 1
                    : (snapshot.currentStreak / rewardDay).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: .20),
                color: const Color(0xFFFFC857),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.daysToNextReward == 0
                  ? 'A milestone reward is ready.'
                  : '${snapshot.daysToNextReward} more '
                      '${snapshot.daysToNextReward == 1 ? 'day' : 'days'} '
                      'to your next milestone',
              style: const TextStyle(
                color: Color(0xFFF5E9C9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!hasStreak) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onShop,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC857),
                foregroundColor: const Color(0xFF3B2A00),
              ),
              child: const Text('Shop now'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF392913)
          : const Color(0xFFFFF3D5),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFDE9415), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your $currentStreak-day streak is at risk. Order today to keep it going.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokenStreakCard extends StatelessWidget {
  const _BrokenStreakCard({
    required this.lastStreak,
    required this.bestStreak,
    required this.onShop,
  });

  final int lastStreak;
  final int bestStreak;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A streak ended. Your rewards are safe.',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Your previous run was $lastStreak days. Your best streak of '
            '$bestStreak days is kept. Start again whenever you are ready.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onShop,
            icon: const Icon(Icons.shopping_basket_outlined),
            label: const Text('Start a new streak'),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.reward,
    required this.currentStreak,
    required this.isClaiming,
    required this.onTap,
  });

  final BuyingStreakReward reward;
  final int currentStreak;
  final bool isClaiming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unlocked = reward.isUnlocked;
    return SizedBox(
      width: 215,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: unlocked
                          ? const Color(0xFF1A9B59)
                          : colors.surfaceContainerHighest,
                      foregroundColor:
                          unlocked ? Colors.white : colors.onSurfaceVariant,
                      child: unlocked
                          ? const Icon(Icons.check_rounded, size: 18)
                          : Text('${reward.day}'),
                    ),
                    const Spacer(),
                    Icon(
                      unlocked ? Icons.lock_open_rounded : Icons.lock_outline,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Day ${reward.day} · ${reward.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    unlocked
                        ? reward.claimedAt == null
                            ? 'Reward unlocked · tap to view'
                            : 'Reward claimed'
                        : '${(reward.day - currentStreak).clamp(0, 365)} '
                            'days to go · tap for details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (isClaiming)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({required this.snapshot});

  final BuyingStreakSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final purchaseDays = snapshot.monthPurchaseDays.toSet();
    final month = snapshot.calendarMonth;
    if (month == null || snapshot.daysInMonth <= 0) {
      return _SurfaceCard(
        child: Text(
          'Your purchase days will appear here.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final itemCount = snapshot.monthStartWeekday + snapshot.daysInMonth;
    return _SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final weekday in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
            ),
            itemBuilder: (context, index) {
              final day = index - snapshot.monthStartWeekday + 1;
              if (day < 1 || day > snapshot.daysInMonth) {
                return const SizedBox.shrink();
              }
              final dayKey = '$month-${day.toString().padLeft(2, '0')}';
              final ordered = purchaseDays.contains(dayKey);
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: ordered
                      ? const Color(0xFF29B765)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: ordered ? Colors.white : colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: ordered ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${purchaseDays.length} purchase '
              '${purchaseDays.length == 1 ? 'day' : 'days'} this month',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLevelCard extends StatelessWidget {
  const _ProfileLevelCard({required this.snapshot});

  final BuyingStreakSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF1A613D),
            foregroundColor: Colors.white,
            child: Icon(Icons.workspace_premium_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.profileLevel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${snapshot.totalPurchaseDays} purchase days · '
                  'best streak ${snapshot.bestStreak} days',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakShortcuts extends StatelessWidget {
  const _StreakShortcuts({
    required this.onRewards,
    required this.onHowItWorks,
    required this.onReminders,
  });

  final VoidCallback onRewards;
  final VoidCallback onHowItWorks;
  final VoidCallback onReminders;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          _ShortcutTile(
            icon: Icons.card_giftcard_outlined,
            label: 'My rewards',
            onTap: onRewards,
          ),
          const Divider(height: 8),
          _ShortcutTile(
            icon: Icons.menu_book_outlined,
            label: 'How streaks work',
            onTap: onHowItWorks,
          ),
          const Divider(height: 8),
          _ShortcutTile(
            icon: Icons.notifications_active_outlined,
            label: 'Streak reminders',
            onTap: onReminders,
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF238551)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!))
        else if (action != null)
          Text(
            action!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _StreakLoadError extends StatelessWidget {
  const _StreakLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStreakError extends StatelessWidget {
  const _InlineStreakError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestStreakPrompt extends StatelessWidget {
  const _GuestStreakPrompt({
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: _SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 52,
                color: Color(0xFFE6A82E),
              ),
              const SizedBox(height: 10),
              const Text(
                'Log in to build a streak',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Order on consecutive days to unlock store rewards. Log in or create an account to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onLogin,
                  child: const Text('Log in'),
                ),
              ),
              TextButton(
                onPressed: onRegister,
                child: const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyingStreakHowItWorksScreen extends StatelessWidget {
  const BuyingStreakHowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rules = [
      'Place at least one qualifying order each day.',
      'Each consecutive purchase day extends your streak.',
      'Reach a milestone to unlock a reward configured by the store.',
      'Miss a day and your current streak resets. Your best streak and earned rewards stay.',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('How streaks work')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (var index = 0; index < rules.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1A9B59),
                      foregroundColor: Colors.white,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(rules[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const _SurfaceCard(
            child: Text(
              'Store days follow Nepal time. Cancelled orders do not count. Your streak and milestone eligibility are calculated by the store server.',
            ),
          ),
        ],
      ),
    );
  }
}

class BuyingStreakRewardsScreen extends StatefulWidget {
  const BuyingStreakRewardsScreen({
    super.key,
    required this.snapshot,
    required this.claimingDays,
    required this.onRewardTap,
  });

  final BuyingStreakSnapshot snapshot;
  final Set<int> claimingDays;
  final ValueChanged<BuyingStreakReward> onRewardTap;

  @override
  State<BuyingStreakRewardsScreen> createState() =>
      _BuyingStreakRewardsScreenState();
}

class _BuyingStreakRewardsScreenState extends State<BuyingStreakRewardsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.snapshot.rewards
        .where((reward) => reward.isUnlocked && reward.claimedAt == null)
        .toList(growable: false);
    final used = widget.snapshot.rewards
        .where((reward) => reward.claimedAt != null)
        .toList(growable: false);
    final locked = widget.snapshot.rewards
        .where((reward) => !reward.isUnlocked)
        .toList(growable: false);
    final groups = [available, used, <BuyingStreakReward>[]];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My rewards'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Available (${available.length})'),
            Tab(text: 'Claimed (${used.length})'),
            const Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RewardList(
            rewards: groups[0],
            emptyMessage: locked.isEmpty
                ? 'Milestone rewards will appear here when you unlock them.'
                : 'No available rewards yet. Keep going to reach your next milestone.',
            onTap: widget.onRewardTap,
          ),
          _RewardList(
            rewards: groups[1],
            emptyMessage: 'Rewards you claim will be kept here.',
            onTap: widget.onRewardTap,
            claimed: true,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The store has not configured expiry dates for streak rewards yet.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardList extends StatelessWidget {
  const _RewardList({
    required this.rewards,
    required this.emptyMessage,
    required this.onTap,
    this.claimed = false,
  });

  final List<BuyingStreakReward> rewards;
  final String emptyMessage;
  final ValueChanged<BuyingStreakReward> onTap;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: rewards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        return _SurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1A9B59),
              foregroundColor: Colors.white,
              child: claimed
                  ? const Icon(Icons.check_rounded)
                  : Text('${reward.day}'),
            ),
            title: Text(
              reward.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(reward.description),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onTap(reward),
          ),
        );
      },
    );
  }
}

class BuyingStreakRewardDetailScreen extends StatelessWidget {
  const BuyingStreakRewardDetailScreen({
    super.key,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Streak reward')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _SurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 54,
                        color: Color(0xFFE1A22C),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        reward.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        reward.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (reward.couponCode != null) ...[
                        const SizedBox(height: 16),
                        SelectableText(
                          'Coupon code: ${reward.couponCode}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Unlocked at the day ${reward.day} milestone',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (reward.isUnlocked && !claimed)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isClaiming ? null : onClaim,
                  child: isClaiming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Claim reward'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainBottomNav(initialIndex: 0),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text(claimed ? 'Continue shopping' : 'Shop to unlock'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BuyingStreakRemindersScreen extends StatefulWidget {
  const BuyingStreakRemindersScreen({super.key});

  @override
  State<BuyingStreakRemindersScreen> createState() =>
      _BuyingStreakRemindersScreenState();
}

class _BuyingStreakRemindersScreenState
    extends State<BuyingStreakRemindersScreen> {
  static const _preferenceKey = 'buying_streak_reminders_enabled';
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = preferences.getBool(_preferenceKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streak reminders')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _SurfaceCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Streak reminder preference'),
              subtitle: const Text(
                'Save this preference on this device. Server-sent streak reminders are not connected yet.',
              ),
              value: _enabled,
              onChanged: _loading ? null : _setEnabled,
            ),
          ),
          const SizedBox(height: 10),
          _SurfaceCard(
            child: Text(
              'This switch does not schedule push notifications. You can manage general FastStore notification permission in your phone settings.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
