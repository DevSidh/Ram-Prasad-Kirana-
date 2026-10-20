import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/admin_api_service.dart';
import '../../services/api_service.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  final ApiService api;

  const AdminAnnouncementsScreen({super.key, required this.api});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  late final AdminApiService _adminApi = AdminApiService(widget.api);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _couponCodeController = TextEditingController();
  bool _sending = false;
  String? _error;
  AdminBroadcastResult? _lastResult;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send to all active accounts?'),
        content: const Text(
          'This announcement will appear in every active account. '
          'Push notifications are sent when device tokens are available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send announcement'),
          ),
        ],
      ),
    );
    if (shouldSend != true || !mounted) return;

    setState(() {
      _sending = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final result = await _adminApi.broadcastNotification(
        title: _titleController.text,
        body: _bodyController.text,
        couponCode: _couponCodeController.text,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _lastResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'One message, every account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Send a store announcement to every active account. '
          'It will be saved in their in-app notifications.',
          style: TextStyle(color: AppConstants.textMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          color: AppConstants.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppConstants.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Announcement title',
                      hintText: 'For example, Fresh stock has arrived',
                      prefixIcon: Icon(Icons.campaign_outlined),
                    ),
                    validator: (value) {
                      final title = value?.trim() ?? '';
                      if (title.isEmpty) return 'Enter a title.';
                      if (title.length > 120) {
                        return 'Use 120 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bodyController,
                    maxLength: 1000,
                    minLines: 4,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Write the announcement customers will see.',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final body = value?.trim() ?? '';
                      if (body.isEmpty) return 'Enter a message.';
                      if (body.length > 1000) {
                        return 'Use 1,000 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _couponCodeController,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Coupon code (optional)',
                      hintText: 'Attach a current coupon for customers to claim',
                      prefixIcon: Icon(Icons.card_giftcard_outlined),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) return null;
                      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{2,39}$')
                          .hasMatch(code)) {
                        return 'Use 3–40 letters, numbers, underscores or hyphens.';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _AnnouncementStatus(
                      icon: Icons.error_outline_rounded,
                      message: _error!,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  if (_lastResult != null) ...[
                    const SizedBox(height: 10),
                    _AnnouncementStatus(
                      icon: Icons.check_circle_outline_rounded,
                      color: AppConstants.primaryDark,
                      message: _resultMessage(_lastResult!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendAnnouncement,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending ? 'Sending…' : 'Review and send to all',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _resultMessage(AdminBroadcastResult result) {
    final parts = <String>[
      'Saved for ${result.notificationsCreated} of '
      '${result.recipientCount} active accounts.',
    ];
    if (!result.pushAvailable) {
      parts.add('Push delivery is not configured; in-app notifications are saved.');
    } else if (result.pushError != null) {
      parts.add(result.pushError!);
    } else if (result.pushFailed > 0) {
      parts.add(
        '${result.pushSent} push notifications sent; '
        '${result.pushFailed} failed.',
      );
    } else {
      parts.add('${result.pushSent} push notifications sent.');
    }
    return parts.join(' ');
  }
}

class _AnnouncementStatus extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _AnnouncementStatus({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
