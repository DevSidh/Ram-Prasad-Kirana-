import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/notification_preferences.dart';
import '../../widgets/store_animation.dart';
import '../auth/login_screen.dart';
import '../profile/profile_options_screens.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _pushAvailable = false;
  bool _pushBusy = false;
  bool _clearingNotifications = false;
  bool _markAllReadStarted = false;
  String? _error;
  String? _preferencesWarning;
  Map<String, bool> _notificationPreferences = NotificationPreferences.defaults;
  String? _loadedUserId;
  final Set<String> _deletingNotificationIds = {};
  int _loadRevision = 0;

  String _translate(String text) =>
      context.read<AppLanguageProvider?>()?.translate(text) ?? text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      _loadRevision++;
      _notifications = [];
      _loading = userId != null;
      _pushBusy = false;
      _pushAvailable = false;
      _clearingNotifications = false;
      _markAllReadStarted = false;
      _error = null;
      _deletingNotificationIds.clear();
      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              context.read<AuthProvider>().currentUser?.id == userId) {
            _loadNotifications();
          }
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (_clearingNotifications) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      if (!_markAllReadStarted) {
        await api.patch('/account/notifications/read-all', const {});
        _markAllReadStarted = true;
      }
      final response = await api.get('/account/notifications');
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw StateError('The server returned invalid notification data.');
      }
      if (!mounted ||
          revision != _loadRevision ||
          context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      Map<String, bool> notificationPreferences =
          NotificationPreferences.defaults;
      String? preferencesWarning;
      try {
        notificationPreferences = await NotificationPreferences.load();
      } catch (error) {
        preferencesWarning = error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted ||
          revision != _loadRevision ||
          context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() {
        _notifications = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .where(
              (item) => !_deletingNotificationIds.contains(
                item['id']?.toString(),
              ),
            )
            .toList();
        _notificationPreferences = notificationPreferences;
        _preferencesWarning = preferencesWarning;
        _pushAvailable = response['pushAvailable'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          revision != _loadRevision ||
          context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null || id == null || notification['isRead'] == true) return;

    try {
      await context
          .read<ApiService>()
          .patch('/account/notifications/$id/read', const {});
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() => notification['isRead'] = true);
    } catch (error) {
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    await _markAsRead(notification);
    if (!mounted) return;
    final metadata = notification['metadata'];
    final rawCouponCode =
        metadata is Map<String, dynamic> ? metadata['couponCode'] : null;
    if (rawCouponCode is! String || rawCouponCode.trim().isEmpty) return;

    final couponCode = rawCouponCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{2,39}$').hasMatch(couponCode)) return;
    final messenger = ScaffoldMessenger.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coupon $couponCode is ready to use at checkout.',
        ),
        action: SnackBarAction(
          label: 'Copy code',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: couponCode));
            messenger.showSnackBar(
              SnackBar(content: Text('Coupon $couponCode copied.')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null ||
        id == null ||
        id.isEmpty ||
        _deletingNotificationIds.contains(id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete notification?')),
        content:
            Text(context.tr('This notification will be permanently removed.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        context.read<AuthProvider>().currentUser?.id != userId) {
      return;
    }

    final originalIndex =
        _notifications.indexWhere((item) => item['id']?.toString() == id);
    setState(() {
      _deletingNotificationIds.add(id);
      _notifications.removeWhere((item) => item['id']?.toString() == id);
    });
    try {
      await context
          .read<ApiService>()
          .delete('/account/notifications/${Uri.encodeComponent(id)}');
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() {
        _deletingNotificationIds.remove(id);
        _loadRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('Notification deleted.'))),
      );
    } catch (error) {
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() {
        _deletingNotificationIds.remove(id);
        _loadRevision++;
        if (originalIndex >= 0 &&
            !_notifications.any((item) => item['id']?.toString() == id)) {
          _notifications.insert(
            originalIndex.clamp(0, _notifications.length),
            notification,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _deleteAllNotifications() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null ||
        _notifications.isEmpty ||
        _clearingNotifications ||
        _deletingNotificationIds.isNotEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete all notifications?')),
        content: Text(context.tr(
          'All notifications in your activity list will be permanently removed.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('Delete all')),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        context.read<AuthProvider>().currentUser?.id != userId) {
      return;
    }

    final previousNotifications = _notifications
        .map((notification) => Map<String, dynamic>.from(notification))
        .toList();
    setState(() {
      _clearingNotifications = true;
      _notifications.clear();
      _loadRevision++;
    });
    try {
      await context.read<ApiService>().delete('/account/notifications');
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_translate('All notifications deleted.'))),
      );
    } catch (error) {
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      setState(() {
        _notifications
          ..clear()
          ..addAll(previousNotifications);
        _loadRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted && context.read<AuthProvider>().currentUser?.id == userId) {
        setState(() => _clearingNotifications = false);
      }
    }
  }

  Future<void> _enablePush() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    setState(() => _pushBusy = true);
    try {
      await PushNotificationService().enable(context.read<ApiService>());
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      await _loadNotifications();
      if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Push alerts enabled on this device.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted && context.read<AuthProvider>().currentUser?.id == userId) {
        setState(() => _pushBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthProvider>().currentUser != null;
    context.watch<ThemeProvider?>();
    final visibleNotifications = _notifications.where((item) {
      final type = item['type']?.toString() ?? '';
      return NotificationPreferences.allows(type, _notificationPreferences);
    }).toList(growable: false);
    final unreadCount =
        visibleNotifications.where((item) => item['isRead'] != true).length;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppConstants.backgroundLight,
        actions: [
          if (signedIn && _notifications.isNotEmpty)
            IconButton(
              tooltip: 'Delete all notifications',
              onPressed:
                  _clearingNotifications ? null : _deleteAllNotifications,
              icon: _clearingNotifications
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
          if (signedIn)
            IconButton(
              tooltip: 'Refresh notifications',
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !signedIn
          ? _SignInPrompt(
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(returnToCaller: true),
                  ),
                );
                if (mounted && authProvider.currentUser != null) {
                  await _loadNotifications();
                }
              },
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _loading
                  ? ListView(
                      children: const [
                        SizedBox(
                          height: 260,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppConstants.primary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _error != null
                      ? StorePageError(
                          title: 'Notifications could not load',
                          message: _error!,
                          retryLabel: 'Try again',
                          onRetry: _loadNotifications,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF176C4A),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          unreadCount == 0
                                              ? 'You are all caught up'
                                              : '$unreadCount unread updates',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Order and store updates, all in one place.',
                                          style: TextStyle(
                                            color: Color(0xFFDCECE2),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _PushPreferenceCard(
                              available: _pushAvailable,
                              busy: _pushBusy,
                              onEnable: _enablePush,
                            ),
                            if (_preferencesWarning != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                '${context.tr('Notification filters could not be loaded:')} $_preferencesWarning. ${context.tr('Showing all updates.')}',
                                style: TextStyle(
                                  color: AppConstants.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            Text(
                              'Recent activity',
                              style: TextStyle(
                                color: AppConstants.textDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_notifications.isEmpty)
                              const _EmptyNotifications()
                            else if (visibleNotifications.isEmpty)
                              _FilteredNotificationsEmpty(
                                onManage: () async {
                                  await Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationPreferencesScreen(),
                                    ),
                                  );
                                  if (mounted) await _loadNotifications();
                                },
                              )
                            else
                              for (final notification in visibleNotifications)
                                _NotificationTile(
                                  notification: notification,
                                  onTap: () =>
                                      _handleNotificationTap(notification),
                                  isDeleting: _deletingNotificationIds
                                      .contains(notification['id']?.toString()),
                                  onDelete: () =>
                                      _deleteNotification(notification),
                                ),
                          ],
                        ),
            ),
    );
  }
}

class _PushPreferenceCard extends StatelessWidget {
  const _PushPreferenceCard({
    required this.available,
    required this.busy,
    required this.onEnable,
  });

  final bool available;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final clientConfigured = PushNotificationService.isConfigured;
    final canEnable = clientConfigured && available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppConstants.glassSurfaceFor(AppConstants.isDarkTheme),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppConstants.glassBorderFor(AppConstants.isDarkTheme),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, color: AppConstants.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push alerts',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  canEnable
                      ? 'Get delivery updates on this device.'
                      : 'Push setup is not configured yet. In-app updates remain available.',
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canEnable)
            TextButton(
              onPressed: busy ? null : onEnable,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enable'),
            )
          else
            Icon(Icons.info_outline, color: AppConstants.textMuted),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    required this.isDeleting,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] == true;
    final type = notification['type']?.toString() ?? '';
    final isAnnouncement = type == 'PROMOTIONAL';
    final icon = type.startsWith('ORDER_')
        ? Icons.local_shipping_outlined
        : Icons.local_offer_outlined;
    final createdAt = DateTime.tryParse(
      notification['createdAt']?.toString() ?? '',
    )?.toLocal();
    final dateLabel = createdAt == null
        ? ''
        : '${createdAt.month}/${createdAt.day} · ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: isAnnouncement
            ? const Color(0xFFFFF5D7)
            : AppConstants.glassSurfaceFor(AppConstants.isDarkTheme),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isAnnouncement
                ? const Color(0xFFE5B64A)
                : AppConstants.glassBorderFor(AppConstants.isDarkTheme),
          ),
          borderRadius: BorderRadius.circular(17),
        ),
        child: InkWell(
          onTap: isDeleting ? null : onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isAnnouncement ? Icons.campaign_rounded : icon,
                    color: isAnnouncement
                        ? const Color(0xFF805700)
                        : AppConstants.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnnouncement
                            ? 'FASTSTORE'
                            : notification['title']?.toString() ??
                                'Store update',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: isAnnouncement ? 1.1 : null,
                          color: isAnnouncement
                              ? const Color(0xFF805700)
                              : AppConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['body']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppConstants.textMuted,
                        ),
                      ),
                      if (dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Delete notification',
                      onPressed: isDeleting ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete_outline, size: 20),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: const BoxDecoration(
                          color: AppConstants.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
      decoration: BoxDecoration(
        color: AppConstants.glassSurfaceFor(AppConstants.isDarkTheme),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppConstants.glassBorderFor(AppConstants.isDarkTheme),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 40, color: AppConstants.primary),
          const SizedBox(height: 10),
          const Text(
            'Nothing new yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Your order and store updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilteredNotificationsEmpty extends StatelessWidget {
  const _FilteredNotificationsEmpty({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
        decoration: BoxDecoration(
          color: AppConstants.glassSurfaceFor(AppConstants.isDarkTheme),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppConstants.glassBorderFor(AppConstants.isDarkTheme),
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                size: 40, color: AppConstants.primary),
            const SizedBox(height: 10),
            Text(
              context.tr('No updates match these filters'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              context
                  .tr('Change notification preferences to see more activity.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onManage,
              child: Text(context.tr('Manage notification preferences')),
            ),
          ],
        ),
      );
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none,
                size: 48, color: AppConstants.primary),
            const SizedBox(height: 12),
            const Text(
              'Sign in to see your notifications',
              style: TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onTap, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}
