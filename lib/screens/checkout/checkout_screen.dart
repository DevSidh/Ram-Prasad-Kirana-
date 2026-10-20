import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/address.dart';
import '../../models/coupon_quote.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/store_availability_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import '../profile/address_book_screen.dart';
import '../order/order_confirmation_screen.dart';
import '../../widgets/store_animation.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _nepalUtcOffset = Duration(hours: 5, minutes: 45);
  int _currentStep = 0;
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;
  bool _loadingAddresses = true;
  String _selectedPaymentMethod = 'COD';
  bool _isSubmitting = false;
  final String _orderRequestKey = const Uuid().v4();
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCouponCode;
  double? _couponSubtotal;
  double _couponDiscount = 0;
  String? _couponMessage;
  bool _couponIsValid = false;
  bool _isValidatingCoupon = false;
  String? _autoAppliedSuggestedCode;
  String _deliveryOption = 'instant';
  DateTime? _scheduledDeliveryAt;

  bool get _canAdvanceStep {
    if (_isSubmitting) return false;
    if (_currentStep == 0) {
      return _selectedAddress != null;
    }
    if (_currentStep == 1) {
      return _deliveryOption != 'custom' || _scheduledDeliveryAt != null;
    }
    if (_currentStep == 2) return _selectedPaymentMethod.isNotEmpty;
    return _currentStep < 3;
  }

  bool get _canPlaceOrder =>
      !_isSubmitting && _currentStep == 3 && _selectedAddress != null;

  @override
  void initState() {
    super.initState();
    final suggestedCode = context.read<CartProvider>().suggestedCouponCode;
    if (suggestedCode != null) _couponController.text = suggestedCode;
    unawaited(_loadAddresses());
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  double _couponEligibleSubtotal(CartProvider cart) => cart.itemList
      .where((item) => !item.isWholesale)
      .fold(0.0, (sum, item) => sum + item.totalPrice);

  DateTime _quickDeliveryTime(int hoursFromNow) =>
      DateTime.now().toUtc().add(Duration(hours: hoursFromNow));

  String _formatNepalTime(DateTime utcTime) => DateFormat(
        'EEE, d MMM · h:mm a',
      ).format(utcTime.toUtc().add(_nepalUtcOffset));

  Future<void> _pickCustomDeliveryTime() async {
    final nepalNow = DateTime.now().toUtc().add(_nepalUtcOffset);
    final earliestDelivery = nepalNow.add(const Duration(hours: 2));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        earliestDelivery.year,
        earliestDelivery.month,
        earliestDelivery.day,
      ),
      firstDate: DateTime(nepalNow.year, nepalNow.month, nepalNow.day),
      lastDate: DateTime(nepalNow.year, nepalNow.month, nepalNow.day + 30),
      helpText: context.tr('Choose delivery date · Nepal time'),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(earliestDelivery),
      helpText: context.tr('Choose delivery time · Nepal time'),
    );
    if (selectedTime == null || !mounted) return;

    final scheduledAt = DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    ).subtract(_nepalUtcOffset);
    if (!scheduledAt.isAfter(DateTime.now().toUtc().add(
          const Duration(hours: 2),
        ))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.tr('Choose a time at least two hours from now.')),
        ),
      );
      return;
    }
    setState(() {
      _deliveryOption = 'custom';
      _scheduledDeliveryAt = scheduledAt;
    });
  }

  Widget _buildDeliveryTiming() {
    final nepalNow = DateTime.now().toUtc().add(_nepalUtcOffset);
    final deviceTime = DateFormat('h:mm a').format(DateTime.now());
    final nepalTime = DateFormat('h:mm a').format(nepalNow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${context.tr('Nepal time')}: $nepalTime · '
            '${context.tr('Your device')}: $deviceTime',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        RadioGroup<String>(
          groupValue: _deliveryOption,
          onChanged: (value) {
            if (value == null) return;
            if (value == 'custom') {
              unawaited(_pickCustomDeliveryTime());
              return;
            }
            setState(() {
              _deliveryOption = value;
              _scheduledDeliveryAt = switch (value) {
                'two-hours' => _quickDeliveryTime(2),
                'four-hours' => _quickDeliveryTime(4),
                _ => null,
              };
            });
          },
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'instant',
                title: Text(context.tr('Instant Delivery')),
                subtitle: Text(context.tr('Deliver as soon as possible.')),
              ),
              RadioListTile<String>(
                value: 'two-hours',
                title: Text(context.tr('In about 2 hours')),
                subtitle: Text(_formatNepalTime(_quickDeliveryTime(2))),
              ),
              RadioListTile<String>(
                value: 'four-hours',
                title: Text(context.tr('In about 4 hours')),
                subtitle: Text(_formatNepalTime(_quickDeliveryTime(4))),
              ),
              RadioListTile<String>(
                value: 'custom',
                title: Text(context.tr('Choose date and time')),
                subtitle: Text(
                  _scheduledDeliveryAt == null
                      ? context.tr('Schedule at least two hours ahead.')
                      : _formatNepalTime(_scheduledDeliveryAt!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _couponMatchesSubtotal(double subtotal) =>
      _appliedCouponCode != null &&
      _couponSubtotal != null &&
      (_couponSubtotal! - subtotal).abs() < 0.01;

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    final subtotal = _couponEligibleSubtotal(context.read<CartProvider>());
    if (code.isEmpty) {
      setState(() {
        _couponMessage = 'Enter a coupon code.';
        _couponIsValid = false;
        _appliedCouponCode = null;
      });
      return;
    }
    if (subtotal <= 0) {
      setState(() {
        _couponMessage = 'Coupons do not apply to wholesale-priced items.';
        _couponIsValid = false;
        _appliedCouponCode = null;
      });
      return;
    }
    setState(() {
      _isValidatingCoupon = true;
      _couponMessage = null;
    });
    try {
      final response = await context.read<ApiService>().post(
        '/coupons/validate',
        {'code': code, 'subtotal': subtotal},
      );
      if (response is! Map<String, dynamic>) {
        throw const FormatException(
            'The store returned an invalid coupon result.');
      }
      final quote = CouponQuote.fromJson(response);
      if (quote.valid &&
          (quote.code == null ||
              quote.discount <= 0 ||
              quote.discount > subtotal)) {
        throw const FormatException(
            'The store returned an invalid coupon discount.');
      }
      if (!mounted) return;
      context.read<CartProvider>().clearSuggestedCouponCode(code);
      setState(() {
        _couponMessage = quote.message;
        _couponIsValid = quote.valid;
        _appliedCouponCode = quote.valid ? quote.code : null;
        _couponDiscount = quote.valid ? quote.discount : 0;
        _couponSubtotal = quote.valid ? subtotal : null;
        if (quote.valid) _couponController.text = quote.code!;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _couponMessage = error.toString().replaceFirst('Exception: ', '');
        _couponIsValid = false;
        _appliedCouponCode = null;
        _couponDiscount = 0;
        _couponSubtotal = null;
      });
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  Widget _buildCouponEntry(double subtotal) {
    final hasStaleCoupon =
        _appliedCouponCode != null && !_couponMatchesSubtotal(subtotal);
    final couponField = TextField(
      controller: _couponController,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _applyCoupon(),
      onChanged: (value) {
        if (value.trim().toUpperCase() != _appliedCouponCode) {
          setState(() {
            _appliedCouponCode = null;
            _couponDiscount = 0;
            _couponSubtotal = null;
            _couponMessage = null;
            _couponIsValid = false;
          });
        }
      },
      decoration: InputDecoration(
        hintText: context.tr('Enter coupon code'),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    final applyButton = FilledButton(
      onPressed: _isValidatingCoupon || subtotal <= 0 ? null : _applyCoupon,
      child: _isValidatingCoupon
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(context.tr('Apply')),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Discount code (regular-priced items only)'),
          style: TextStyle(
            color: AppConstants.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  couponField,
                  Align(
                    alignment: Alignment.centerRight,
                    child: applyButton,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: couponField),
                const SizedBox(width: 8),
                applyButton,
              ],
            );
          },
        ),
        if (_couponMessage != null || hasStaleCoupon) ...[
          const SizedBox(height: 6),
          Text(
            hasStaleCoupon
                ? context.tr('Your basket changed. Apply the code again.')
                : context.tr(_couponMessage!),
            style: TextStyle(
              color: hasStaleCoupon
                  ? Colors.orange.shade800
                  : _couponIsValid
                      ? Colors.green.shade700
                      : Colors.red.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses =
          await AddressService(context.read<ApiService>()).getAddresses();
      if (!mounted) return;
      final preferences = await SharedPreferences.getInstance();
      final selectedId = preferences.getString('selected_delivery_address_id');
      final selectedAddresses =
          addresses.where((item) => item.id == selectedId);
      final defaults = addresses.where((item) => item.isDefault);
      setState(() {
        _savedAddresses = addresses;
        _selectedAddress = selectedAddresses.isNotEmpty
            ? selectedAddresses.first
            : defaults.isEmpty
                ? (addresses.isEmpty ? null : addresses.first)
                : defaults.first;
        _loadingAddresses = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingAddresses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load delivery addresses: $error')),
      );
    }
  }

  Future<void> _rememberSelectedAddress(Address address) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('selected_delivery_address_id', address.id);
  }

  Future<void> _chooseAddress() async {
    final address = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressBookScreen(selectionMode: true),
      ),
    );
    if (address != null && mounted) {
      setState(() {
        _selectedAddress = address;
        if (!_savedAddresses.any((item) => item.id == address.id)) {
          _savedAddresses = [..._savedAddresses, address];
        }
      });
      unawaited(_rememberSelectedAddress(address));
    }
  }

  Widget _buildAddressCard() {
    if (_loadingAddresses) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final address = _selectedAddress;
    if (address == null) {
      return OutlinedButton.icon(
        onPressed: _chooseAddress,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add delivery address'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.primaryLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  address.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppConstants.textDark,
                  ),
                ),
              ),
              TextButton(
                  onPressed: _chooseAddress, child: const Text('Change')),
            ],
          ),
          Text(
            '${address.fullName} · ${address.phone}',
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textDark,
            ),
          ),
          Text(
            '${address.street}, ${address.city}, ${address.province}',
            style: TextStyle(
              color: AppConstants.textMuted,
              fontSize: 12,
            ),
          ),
          if (address.instructions != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: ${address.instructions!}',
                style: TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handlePlaceOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final address = _selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a delivery address to continue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final storeAvailability = context.read<StoreAvailabilityProvider>();
      await storeAvailability.refresh();
      if (!mounted) return;
      final availability = storeAvailability.availability;
      if (availability != null && !availability.isAcceptingOrders) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context
                      .read<AppLanguageProvider?>()
                      ?.translate(availability.statusMessage) ??
                  availability.statusMessage,
            ),
          ),
        );
        return;
      }

      final order = await orderProvider.placeOrder(
        items: cart.itemList,
        address: address,
        paymentMethod: _selectedPaymentMethod,
        idempotencyKey: _orderRequestKey,
        scheduledDeliveryAt: _scheduledDeliveryAt,
        couponCode: _couponMatchesSubtotal(_couponEligibleSubtotal(cart))
            ? _appliedCouponCode
            : null,
      );

      cart.clearCart();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(order: order),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSelectionRow({
    required String value,
    required String selectedValue,
    required String title,
    required String subtitle,
    required Color activeColor,
    required ValueChanged<String> onChanged,
    Widget? secondary,
  }) {
    final isSelected = value == selectedValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(15)
              : AppConstants.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppConstants.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (secondary != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: secondary,
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppConstants.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? activeColor : AppConstants.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? labelColor,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: labelColor ?? AppConstants.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppConstants.textDark,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final couponEligibleSubtotal = _couponEligibleSubtotal(cart);
    final suggestedCode = cart.suggestedCouponCode;
    if (suggestedCode != null &&
        couponEligibleSubtotal > 0 &&
        _autoAppliedSuggestedCode != suggestedCode) {
      _autoAppliedSuggestedCode = suggestedCode;
      _couponController.text = suggestedCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyCoupon());
      });
    }
    context.watch<ThemeProvider?>();
    final tokens = AppThemeExtension.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = cart.subtotal +
        AppConstants.defaultDeliveryFee -
        (_couponMatchesSubtotal(couponEligibleSubtotal) ? _couponDiscount : 0);

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: AppConstants.backgroundFor(isDark),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(context.tr('Express Checkout')),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          forceMaterialTransparency: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppBackground(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                child: Stepper(
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_canAdvanceStep) setState(() => _currentStep++);
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) setState(() => _currentStep--);
                  },
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          if (_currentStep < 3)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _canAdvanceStep
                                    ? details.onStepContinue
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primary,
                                  shape: const StadiumBorder(),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(context.tr('Continue')),
                              ),
                            ),
                          if (_currentStep > 0) ...[
                            if (_currentStep < 3) const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 18,
                                ),
                              ),
                              child: Text(context.tr('Back')),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  steps: [
                    // Step 1: Address
                    Step(
                      title: const Text('Delivery Address',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                      content: _buildAddressCard(),
                    ),

                    Step(
                      title: const Text('Delivery Timing',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1
                          ? StepState.complete
                          : StepState.indexed,
                      content: _buildDeliveryTiming(),
                    ),

                    // Step 3: Payment
                    Step(
                      title: const Text('Payment Method',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2
                          ? StepState.complete
                          : StepState.indexed,
                      content: Column(
                        children: [
                          _buildSelectionRow(
                            value: 'COD',
                            selectedValue: _selectedPaymentMethod,
                            title: 'Cash on Delivery (COD)',
                            subtitle: 'Pay cash or QR scan upon arrival',
                            activeColor: AppConstants.primary,
                            secondary: const Icon(Icons.payments_outlined,
                                color: AppConstants.primary),
                            onChanged: (value) =>
                                setState(() => _selectedPaymentMethod = value),
                          ),
                        ],
                      ),
                    ),

                    // Step 4: Review
                    Step(
                      title: const Text('Order Summary',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      isActive: _currentStep >= 3,
                      content: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConstants.borderLight),
                        ),
                        child: Column(
                          children: [
                            _buildCouponEntry(couponEligibleSubtotal),
                            const SizedBox(height: 18),
                            _buildSummaryRow(
                              'Basket Items',
                              '${cart.itemCount} items',
                            ),
                            const SizedBox(height: 6),
                            _buildSummaryRow(
                              'Subtotal',
                              '${AppConstants.currencySymbol}${cart.subtotal.toInt()}',
                            ),
                            const SizedBox(height: 6),
                            _buildSummaryRow(
                              'Delivery',
                              '${AppConstants.currencySymbol}${AppConstants.defaultDeliveryFee.toInt()}',
                            ),
                            if (_couponMatchesSubtotal(
                                    couponEligibleSubtotal) &&
                                _couponDiscount > 0) ...[
                              const SizedBox(height: 6),
                              _buildSummaryRow(
                                context.tr('Coupon discount'),
                                '-${AppConstants.currencySymbol}${_couponDiscount.toStringAsFixed(_couponDiscount.truncateToDouble() == _couponDiscount ? 0 : 2)}',
                                labelColor: Colors.green.shade700,
                                valueColor: Colors.green.shade700,
                              ),
                            ],
                            const Divider(height: 20),
                            _buildSummaryRow(
                              'Grand Total',
                              '${AppConstants.currencySymbol}${(cart.subtotal + AppConstants.defaultDeliveryFee - (_couponMatchesSubtotal(couponEligibleSubtotal) ? _couponDiscount : 0)).toInt()}',
                              isTotal: true,
                              labelColor: AppConstants.textDark,
                              valueColor: AppConstants.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSubmitting) const _OrderPlacementOverlay(),
          ],
        ),
        bottomNavigationBar: Material(
          type: MaterialType.transparency,
          elevation: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.glassBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Total'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                            ),
                            Text(
                              '${AppConstants.currencySymbol}${total.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: context.tr('Place order'),
                          icon: Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _canPlaceOrder ? _handlePlaceOrder : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderPlacementOverlay extends StatelessWidget {
  const _OrderPlacementOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(
            dismissible: false,
            color: Color(0x99000000),
          ),
        ),
        Center(
          child: Semantics(
            liveRegion: true,
            label: 'Placing your order',
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StoreAnimation(
                      assetPath: 'animations/shopping_cart.lottie',
                      size: 180,
                      semanticLabel: 'Shopping cart in motion',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Placing your order',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please wait while we confirm it with the store.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
