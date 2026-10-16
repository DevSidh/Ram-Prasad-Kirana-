import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/address.dart';
import '../../providers/theme_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import '../../widgets/store_animation.dart';
import 'address_map_picker.dart';

class AddressBookScreen extends StatefulWidget {
  final bool selectionMode;

  const AddressBookScreen({super.key, this.selectionMode = false});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final AddressService _addressService =
      AddressService(context.read<ApiService>());
  List<Address> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final addresses = await _addressService.getAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      if (_addresses.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh addresses: $_error')),
        );
      }
    }
  }

  Future<void> _edit([Address? current]) async {
    final address = await showDialog<Address>(
      context: context,
      builder: (_) => _AddressFormDialog(address: current),
    );
    if (address == null || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final saved = current == null
          ? await _addressService.createAddress(address)
          : await _addressService.updateAddress(address);
      if (!mounted) return;
      if (widget.selectionMode) {
        Navigator.pop(context, saved);
        return;
      }
      setState(() {
        _addresses = current == null
            ? [..._addresses, saved]
            : _addresses
                .map((item) => item.id == saved.id ? saved : item)
                .toList();
        _loading = false;
      });
      await _load();
      if (mounted && !_addresses.any((item) => item.id == saved.id)) {
        setState(() => _addresses = [..._addresses, saved]);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save address: $_error')),
      );
    }
  }

  Future<void> _setDefault(Address address) async {
    try {
      await _addressService.setDefault(address.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('Remove the ${address.title.toLowerCase()} address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _addressService.deleteAddress(address.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode
            ? 'Choose delivery address'
            : 'Delivery addresses'),
        actions: [
          IconButton(
            tooltip: 'Add address',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading && _addresses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _addresses.isEmpty
              ? _AddressError(message: _error!, onRetry: _load)
              : _addresses.isEmpty
                  ? _AddressEmpty(onAdd: () => _edit())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _addresses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          return Material(
                            color: AppConstants.surfaceLight,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: widget.selectionMode
                                  ? () => Navigator.pop(context, address)
                                  : () => _edit(address),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryLight,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        address.title.toLowerCase() == 'work'
                                            ? Icons.work_outline
                                            : Icons.home_outlined,
                                        color: AppConstants.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  address.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (address.isDefault) ...[
                                                const SizedBox(width: 8),
                                                const _DefaultBadge(),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(address.fullName),
                                          Text(
                                            '${address.street}, ${address.city}, ${address.province}',
                                            style: TextStyle(
                                              color: AppConstants.textMuted,
                                            ),
                                          ),
                                          Text(
                                            address.phone,
                                            style: TextStyle(
                                              color: AppConstants.textMuted,
                                            ),
                                          ),
                                          if (!widget.selectionMode)
                                            Wrap(
                                              spacing: 4,
                                              children: [
                                                if (!address.isDefault)
                                                  TextButton(
                                                    onPressed: () =>
                                                        _setDefault(address),
                                                    child: const Text(
                                                        'Set as default'),
                                                  ),
                                                TextButton(
                                                  onPressed: () =>
                                                      _delete(address),
                                                  child: const Text('Remove'),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (widget.selectionMode)
                                      const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _addresses.isEmpty || widget.selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add address'),
            ),
    );
  }
}

class _AddressFormDialog extends StatefulWidget {
  final Address? address;

  const _AddressFormDialog({this.address});

  @override
  State<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<_AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _street;
  late final TextEditingController _landmark;
  late final TextEditingController _instructions;
  late String _title;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _name = TextEditingController(text: address?.fullName ?? '');
    _phone = TextEditingController(text: address?.phone ?? '');
    _city = TextEditingController(text: address?.city ?? '');
    _province = TextEditingController(text: address?.province ?? 'Madhesh');
    _street = TextEditingController(text: address?.street ?? '');
    _landmark = TextEditingController(text: address?.landmark ?? '');
    _instructions = TextEditingController(text: address?.instructions ?? '');
    _title = address?.title ?? 'Home';
    _latitude = address?.latitude;
    _longitude = address?.longitude;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _province.dispose();
    _street.dispose();
    _landmark.dispose();
    _instructions.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _chooseMapLocation() async {
    final location = await Navigator.push<PickedAddressLocation>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddressMapPicker(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (location == null || !mounted) return;
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      if (location.street.isNotEmpty) _street.text = location.street;
      if (location.city.isNotEmpty) _city.text = location.city;
      if (location.province.isNotEmpty) _province.text = location.province;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    return AlertDialog(
      title: Text(
          widget.address == null ? 'Add delivery address' : 'Edit address'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _chooseMapLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Choose a map pin'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A map pin is optional and helps the courier find your address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (_latitude != null && _longitude != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Map pin selected (${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)})',
                      style: TextStyle(
                        color: AppConstants.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _title,
                  decoration: const InputDecoration(labelText: 'Address label'),
                  items: const ['Home', 'Work', 'Other']
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _title = value ?? 'Home'),
                ),
                const SizedBox(height: 10),
                _field(_name, 'Recipient name', validator: _required),
                _field(_phone, 'Phone number',
                    keyboardType: TextInputType.phone, validator: _required),
                _field(_street, 'Ward, street, and house details',
                    validator: _required),
                _field(_landmark, 'Landmark (optional)'),
                _field(_city, 'City / municipality', validator: _required),
                _field(_province, 'Province', validator: _required),
                _field(_instructions, 'Delivery instructions (optional)'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              Address(
                id: widget.address?.id ?? '',
                title: _title,
                fullName: _name.text.trim(),
                phone: _phone.text.trim(),
                city: _city.text.trim(),
                province: _province.text.trim(),
                street: _street.text.trim(),
                landmark: _landmark.text.trim().isEmpty
                    ? null
                    : _landmark.text.trim(),
                instructions: _instructions.text.trim().isEmpty
                    ? null
                    : _instructions.text.trim(),
                isDefault: widget.address?.isDefault ?? false,
                latitude: _latitude,
                longitude: _longitude,
              ),
            );
          },
          child: const Text('Save address'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
      );
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppConstants.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'DEFAULT',
          style: TextStyle(
            color: AppConstants.primaryDark,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _AddressEmpty extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddressEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 52, color: AppConstants.primary),
              const SizedBox(height: 12),
              const Text('No delivery addresses yet',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Save an address for a quicker checkout.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.textMuted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add an address'),
              ),
            ],
          ),
        ),
      );
}

class _AddressError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AddressError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => StorePageError(
        title: 'Addresses unavailable',
        message: message,
        retryLabel: 'Try again',
        onRetry: onRetry,
      );
}
