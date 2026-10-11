import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/push_notification_service.dart';
import '../auth/login_screen.dart';

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
  String? _error;
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadNotifications();
        });
      } else {
        _notifications = [];
        _loading = false;
      }
    }
  }

  Future<void> _loadNotifications() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await context.read<ApiService>().get('/account/notifications');
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw StateError('The server returned invalid notification data.');
      }
      if (!mounted) return;
      setState(() {
        _notifications = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _pushAvailable = response['pushAvailable'] == true;
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

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    if (id == null || notification['isRead'] == true) return;

    try {
      await context
          .read<ApiService>()
          .patch('/account/notifications/$id/read', const {});
      if (!mounted) return;
      setState(() => notification['isRead'] = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _enablePush() async {
    setState(() => _pushBusy = true);
    try {
      await PushNotificationService().enable(context.read<ApiService>());
      await _loadNotifications();
      if (!mounted) return;
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
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthProvider>().currentUser != null;
    final unreadCount =
        _notifications.where((item) => item['isRead'] != true).length;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppConstants.backgroundLight,
        actions: [
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
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
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
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 42, color: AppConstants.textMuted),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Center(
                              child: OutlinedButton(
                                onPressed: _loadNotifications,
                                child: const Text('Try again'),
                              ),
                            ),
                          ],
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
                            const SizedBox(height: 22),
                            const Text(
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
                            else
                              for (final notification in _notifications)
                                _NotificationTile(
                                  notification: notification,
                                  onTap: () => _markAsRead(notification),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppConstants.borderLight),
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
                  style: const TextStyle(
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
            const Icon(Icons.info_outline, color: AppConstants.textMuted),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] == true;
    final type = notification['type']?.toString() ?? '';
    final icon = type.startsWith('ORDER_')
        ? Icons.local_shipping_outlined
        : Icons.local_offer_outlined;
    final createdAt = DateTime.tryParse(
      notification['createdAt']?.toString() ?? '',
    );
    final dateLabel = createdAt == null
        ? ''
        : '${createdAt.month}/${createdAt.day} · ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: isRead ? Colors.white : const Color(0xFFEDF6EE),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
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
                  child: Icon(icon, color: AppConstants.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title']?.toString() ?? 'Store update',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isRead ? FontWeight.w600 : FontWeight.w800,
                          color: AppConstants.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['body']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppConstants.textMuted,
                        ),
                      ),
                      if (dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, left: 8),
                    decoration: const BoxDecoration(
                      color: AppConstants.primary,
                      shape: BoxShape.circle,
                    ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 40, color: AppConstants.primary),
          SizedBox(height: 10),
          Text(
            'Nothing new yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
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
