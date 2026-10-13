import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../models/address.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import '../profile/address_book_screen.dart';
import '../order/order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;
  List<Address> _savedAddresses = [];
  Address? _selectedAddress;
  bool _loadingAddresses = true;
  String _selectedPaymentMethod = 'COD';
  bool _isSubmitting = false;
  final String _orderRequestKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    unawaited(_loadAddresses());
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
      final order = await orderProvider.placeOrder(
        items: cart.itemList,
        address: address,
        paymentMethod: _selectedPaymentMethod,
        idempotencyKey: _orderRequestKey,
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

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    context.watch<ThemeProvider?>();

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: const Text('Express Checkout'),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _selectedAddress == null) {
            _chooseAddress();
            return;
          }
          if (_currentStep < 3) {
            setState(() => _currentStep++);
          } else {
            _handlePlaceOrder();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppConstants.primaryForeground,
                                strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == 3
                                ? 'Confirm & Place Order'
                                : 'Continue',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppConstants.primaryForeground),
                          ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                    child: const Text('Back'),
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
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildAddressCard(),
          ),

          // Delivery timing is coordinated by the store after an order is placed.
          Step(
            title: const Text('Delivery Timing',
                style: TextStyle(fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'The store will confirm your delivery timing after you place the order.',
              ),
            ),
          ),

          // Step 3: Payment
          Step(
            title: const Text('Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold)),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Basket Items',
                          style: TextStyle(
                              fontSize: 13, color: AppConstants.textMuted)),
                      Text('${cart.itemCount} items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppConstants.textDark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal',
                          style: TextStyle(
                              fontSize: 13, color: AppConstants.textMuted)),
                      Text(
                          '${AppConstants.currencySymbol}${cart.subtotal.toInt()}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppConstants.textDark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delivery',
                          style: TextStyle(
                              fontSize: 13, color: AppConstants.textMuted)),
                      Text(
                          cart.deliveryFee == 0
                              ? 'FREE'
                              : '${AppConstants.currencySymbol}${cart.deliveryFee.toInt()}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppConstants.textDark)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Grand Total',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textDark)),
                      Text(
                          '${AppConstants.currencySymbol}${cart.grandTotal.toInt()}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryDark)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
