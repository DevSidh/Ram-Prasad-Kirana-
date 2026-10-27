import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store_offer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/offer_service.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  StoreOffer? _offer;
  List<_CouponEntry> _notificationCoupons = const [];
  String? _offerError;
  String? _notificationError;
  bool _loading = true;
  bool _loadingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoupons());
  }

  Future<void> _loadCoupons() async {
    if (_loadingNotifications) return;
    setState(() {
      _loading = true;
      _offerError = null;
      _notificationError = null;
    });

    final api = context.read<ApiService>();
    final userId = context.read<AuthProvider>().currentUser?.id;
    StoreOffer? offer;
    String? offerError;
    var notificationCoupons = <_CouponEntry>[];
    String? notificationError;
    Set<String>? availableCouponCodes;

    try {
      offer = await OfferService(api).getActiveOffer();
      if (offer != null && !offer.isAvailableAt(DateTime.now())) {
        offer = null;
      }
    } catch (error) {
      offerError = error.toString().replaceFirst('Exception: ', '');
    }

    if (userId != null) {
      _loadingNotifications = true;
      try {
        final availableResponse = await api.get('/account/coupons/available');
        if (availableResponse is! Map<String, dynamic> ||
            availableResponse['availableCouponCodes'] is! List) {
          throw const FormatException(
            'The store returned invalid available coupon data.',
          );
        }
        availableCouponCodes =
            (availableResponse['availableCouponCodes'] as List)
                .whereType<String>()
                .map((code) => code.trim().toUpperCase())
                .toSet();
      } catch (error) {
        notificationError =
            'Available coupons could not be checked: ${error.toString().replaceFirst('Exception: ', '')}';
      }
      if (availableCouponCodes == null) {
        offer = null;
      }

      try {
        final response = await api.get('/account/notifications');
        if (response is! Map<String, dynamic> || response['data'] is! List) {
          throw const FormatException(
            'The store returned invalid notification data.',
          );
        }
        if (offer != null &&
            availableCouponCodes != null &&
            !availableCouponCodes.contains(offer.code.toUpperCase())) {
          offer = null;
        }
        final seenCodes = <String>{if (offer != null) offer.code};
        for (final notification
            in (response['data'] as List).whereType<Map<String, dynamic>>()) {
          final metadata = notification['metadata'];
          final code =
              metadata is Map<String, dynamic> ? metadata['couponCode'] : null;
          final productId =
              metadata is Map<String, dynamic> ? metadata['productId'] : null;
          final notificationTitle = notification['title']?.toString().trim();
          if (code is! String) continue;
          final normalized = code.trim().toUpperCase();
          if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{2,39}$').hasMatch(normalized) ||
              availableCouponCodes == null ||
              !availableCouponCodes.contains(normalized) ||
              !seenCodes.add(normalized)) {
            continue;
          }
          notificationCoupons.add(
            _CouponEntry(
              code: normalized,
              title: notificationTitle?.isNotEmpty == true
                  ? notificationTitle!
                  : productId is String
                      ? 'Product-specific coupon'
                      : 'Coupon from a notification',
              description: (notification['body'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (notification['body'] as String).trim()
                  : 'Shared with you in your store notifications; checkout will confirm whether it is still valid.',
            ),
          );
        }
      } catch (error) {
        final message = error.toString().replaceFirst('Exception: ', '');
        notificationError = notificationError == null
            ? message
            : '$notificationError\n$message';
      } finally {
        _loadingNotifications = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _offer = offer;
      _offerError = offerError;
      _notificationCoupons = notificationCoupons;
      _notificationError = notificationError;
      _loading = false;
    });
  }

  void _useCoupon(String code) {
    context.read<CartProvider>().suggestCouponCode(code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coupon $code added to your cart. Checkout will confirm eligibility.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  String _offerDescription(StoreOffer offer) {
    if (offer.discountType == OfferDiscountType.fixed) {
      return 'Rs. ${offer.amount} off your order'
          '${offer.minOrderAmount > 0 ? ' on orders over Rs. ${offer.minOrderAmount}' : ''}. '
          'Checkout will confirm eligibility.';
    }
    return '${offer.percent}% off'
        '${offer.maxDiscount == null ? '' : ', up to Rs. ${offer.maxDiscount}'}'
        '${offer.minOrderAmount > 0 ? ' on orders over Rs. ${offer.minOrderAmount}' : ''}. '
        'Checkout will confirm eligibility.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final coupons = <_CouponEntry>[
      if (_offer case final offer?)
        _CouponEntry(
          code: offer.code,
          title: 'Current store offer',
          description: _offerDescription(offer),
          isActiveOffer: true,
        ),
      ..._notificationCoupons,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coupons'),
        actions: [
          IconButton(
            tooltip: 'Refresh coupons',
            onPressed: _loading ? null : _loadCoupons,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCoupons,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_offerError != null)
                    _CouponLoadError(
                      message: _offerError!,
                      onRetry: _loadCoupons,
                    ),
                  if (_notificationError != null)
                    _CouponLoadError(
                      message: _notificationError!,
                      onRetry: _loadCoupons,
                    ),
                  if (coupons.isEmpty &&
                      _offerError == null &&
                      _notificationError == null)
                    SizedBox(
                      height: 360,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_giftcard_outlined,
                              size: 52,
                              color: colors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No coupons available right now',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'New store offers and notification coupons will appear here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final coupon in coupons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CouponCard(
                        coupon: coupon,
                        onUse: () => _useCoupon(coupon.code),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CouponEntry {
  final String code;
  final String title;
  final String description;
  final bool isActiveOffer;

  const _CouponEntry({
    required this.code,
    required this.title,
    required this.description,
    this.isActiveOffer = false,
  });
}

class _CouponCard extends StatelessWidget {
  final _CouponEntry coupon;
  final VoidCallback onUse;

  const _CouponCard({required this.coupon, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  coupon.isActiveOffer
                      ? Icons.local_offer_rounded
                      : Icons.notifications_active_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coupon.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .35),
                ),
              ),
              child: Text(
                coupon.code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Text(coupon.description),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUse,
                child: const Text('Add coupon to cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CouponLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Some coupons could not load'),
          subtitle: Text(message),
          trailing: IconButton(
            tooltip: 'Retry loading coupons',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      );
}
