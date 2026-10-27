import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/scanned_product_barcode.dart';
import '../../services/admin_api_service.dart';
import '../../theme/app_colors.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.api});

  final AdminApiService? api;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _manualController = TextEditingController();
  final _manualFocus = FocusNode();
  late final MobileScannerController _scannerController =
      MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );
  bool _didScan = false;
  late bool _useCamera = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  String? _scanError;
  String? _lastRejectedValue;
  String? _pairingCode;
  String? _remoteStatus;
  bool _remoteDesktopMode = false;
  bool _remotePhoneMode = false;
  bool _remoteSending = false;
  Timer? _remotePoll;

  @override
  void dispose() {
    _manualController.dispose();
    _manualFocus.dispose();
    _scannerController.dispose();
    _remotePoll?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didScan || !_useCamera) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (_remotePhoneMode) {
        unawaited(_sendRemoteBarcode(value));
        return;
      }
      final parsed = ScannedProductBarcode.parse(value);
      if (parsed == null) {
        if (_lastRejectedValue == value) return;
        _lastRejectedValue = value;
        setState(() => _scanError =
            'This code cannot be used as a product barcode. Enter the product code manually.');
        return;
      }
      _didScan = true;
      Navigator.of(context).pop(parsed);
      return;
    }
  }

  void _selectSource(bool useCamera) {
    if (_useCamera == useCamera) return;
    setState(() {
      _useCamera = useCamera;
      _remoteDesktopMode = useCamera && !_supportsLocalCamera;
      _remotePhoneMode = false;
      _scanError = null;
      _manualController.clear();
    });
    if (_remoteDesktopMode) unawaited(_startDesktopPairing());
    if (!useCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _manualFocus.requestFocus();
      });
    }
  }

  void _submitManualCode() {
    if (_remotePhoneMode) {
      unawaited(_sendRemoteBarcode(_manualController.text.trim()));
      return;
    }
    final parsed = ScannedProductBarcode.parse(_manualController.text);
    if (parsed == null) {
      setState(() => _scanError = 'Enter a valid product barcode.');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  bool get _supportsLocalCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _startDesktopPairing() async {
    final api = widget.api;
    if (api == null) return;
    setState(() => _remoteStatus = 'Creating a secure pairing code…');
    try {
      final code = await api.createBarcodeScannerSession();
      if (!mounted) return;
      setState(() {
        _pairingCode = code;
        _remoteStatus = 'Enter this code on the signed-in phone.';
      });
      _remotePoll?.cancel();
      _remotePoll = Timer.periodic(const Duration(milliseconds: 800), (_) {
        unawaited(_pollRemoteBarcode());
      });
    } catch (error) {
      if (mounted) {
        setState(() => _remoteStatus = _pairingErrorMessage(error));
      }
    }
  }

  Future<void> _pollRemoteBarcode() async {
    final api = widget.api;
    final code = _pairingCode;
    if (api == null || code == null || !mounted) return;
    try {
      final value = await api.takeBarcodeScannerResult(code);
      if (value == null || value.trim().isEmpty || !mounted) return;
      final parsed = ScannedProductBarcode.parse(value.trim());
      if (parsed == null) {
        setState(() => _remoteStatus =
            'The phone scanned an unsupported code. Try again.');
        return;
      }
      _remotePoll?.cancel();
      Navigator.of(context).pop(parsed);
    } catch (error) {
      if (!mounted) return;
      _remotePoll?.cancel();
      setState(() => _remoteStatus = _pairingErrorMessage(error));
    }
  }

  Future<void> _connectPhoneToPc() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Windows billing'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: '8 digit pairing code',
            hintText: 'Enter the code shown on the computer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null) return;
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(
          () => _scanError = 'Enter the 8 digit code shown on the computer.');
      return;
    }
    try {
      await widget.api?.joinBarcodeScannerSession(code);
    } catch (error) {
      if (mounted) {
        setState(() => _scanError = _pairingErrorMessage(error));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _pairingCode = code;
      _remotePhoneMode = true;
      _scanError = null;
      _remoteStatus =
          'Connected. Aim the camera at a barcode to send it to the PC.';
    });
  }

  Future<void> _sendRemoteBarcode(String value) async {
    final api = widget.api;
    final code = _pairingCode;
    if (api == null || code == null || _remoteSending || value.isEmpty) return;
    _remoteSending = true;
    try {
      await api.submitBarcodeScannerResult(code: code, barcode: value);
      if (mounted)
        setState(() => _remoteStatus = 'Barcode sent to the computer.');
    } catch (error) {
      if (mounted)
        setState(() => _remoteStatus =
            'Could not send barcode. Check the connection or pairing code.');
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _remoteSending = false;
    }
  }

  String _pairingErrorMessage(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('expired')) {
      return 'The pairing code expired. Create a new code on the computer and reconnect the phone.';
    }
    if (message.contains('Cannot POST') ||
        message.contains('Cannot GET') ||
        message.contains('404')) {
      return 'The server needs the barcode-pairing update. Update the backend on Render, then try again.';
    }
    return 'Pairing expired or the connection failed. Check that both devices are online and signed in to the same billing account, then try again.';
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanError = 'Flashlight could not be enabled: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          if (_useCamera)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, _) => IconButton(
                tooltip: state.torchState == TorchState.on
                    ? 'Turn flashlight off'
                    : 'Turn flashlight on',
                onPressed: state.torchState == TorchState.unavailable
                    ? null
                    : _toggleTorch,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  enabled: _supportsLocalCamera || widget.api != null,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Mobile camera'),
                ),
                const ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.barcode_reader),
                  label: Text('Barcode scanner'),
                ),
              ],
              selected: {_useCamera},
              onSelectionChanged: (selection) => _selectSource(selection.first),
            ),
          ),
          Expanded(
            child: _useCamera
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_remoteDesktopMode)
                        _phonePairingPanel()
                      else
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) => ColoredBox(
                            color: AppColors.isWindowsAdminDarkTheme
                                ? AppColors.pageStart
                                : AppColors.primary,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error.errorCode ==
                                          MobileScannerErrorCode
                                              .permissionDenied
                                      ? 'Camera access is off. Allow camera access in Settings or switch to a barcode scanner.'
                                      : 'Camera scanning is unavailable. Switch to a barcode scanner or enter the barcode below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.surface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          placeholderBuilder: (_) => ColoredBox(
                            color: AppColors.isWindowsAdminDarkTheme
                                ? AppColors.pageStart
                                : AppColors.primary,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                        ),
                      if (!_remoteDesktopMode)
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 280,
                              height: 170,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 3,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.row),
                              ),
                            ),
                          ),
                        ),
                      if (!_remoteDesktopMode)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 22,
                          child: Text(
                            'Align the barcode inside the frame',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              color: AppColors.surface,
                              shadows: [
                                Shadow(
                                  color: AppColors.primary,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.barcode_reader,
                            size: 58,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'External scanner selected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connect a USB or Bluetooth scanner that types barcodes like a keyboard, then scan into the field below.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                TextField(
                  controller: _manualController,
                  focusNode: _manualFocus,
                  autofocus: !_useCamera,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitManualCode(),
                  decoration: InputDecoration(
                    labelText: _useCamera
                        ? 'Enter or scan with a hardware scanner'
                        : 'Scan or enter barcode',
                    hintText: 'Barcode or product code',
                    errorText: _scanError,
                    suffixIcon: IconButton(
                      tooltip: 'Look up barcode',
                      onPressed: _submitManualCode,
                      icon: Icon(Icons.search_rounded, color: colors.primary),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _useCamera
                      ? 'USB and Bluetooth scanners can type into this field too.'
                      : 'Keyboard-wedge scanners send the barcode here and press Enter.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_supportsLocalCamera && widget.api != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: OutlinedButton.icon(
                onPressed: _connectPhoneToPc,
                icon: const Icon(Icons.desktop_windows_outlined),
                label: const Text('Send scans to Windows billing'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _phonePairingPanel() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android_rounded, size: 56),
              const SizedBox(height: 14),
              Text(
                _pairingCode ?? '••••••••',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              Text(_remoteStatus ?? 'Waiting for phone camera…',
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              const Text(
                'On the signed-in billing app on your phone, open Scan barcode, tap “Send scans to Windows billing”, and enter this code. Code expires in 3 minutes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _startDesktopPairing,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Create new code'),
              ),
            ],
          ),
        ),
      );
}
