import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/scanned_product_barcode.dart';
import '../../theme/app_colors.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

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

  @override
  void dispose() {
    _manualController.dispose();
    _manualFocus.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didScan || !_useCamera) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
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
      _scanError = null;
      _manualController.clear();
    });
    if (!useCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _manualFocus.requestFocus();
      });
    }
  }

  void _submitManualCode() {
    final parsed = ScannedProductBarcode.parse(_manualController.text);
    if (parsed == null) {
      setState(() => _scanError = 'Enter a valid product barcode.');
      return;
    }
    Navigator.of(context).pop(parsed);
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
                  enabled: defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS,
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
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => ColoredBox(
                          color: AppColors.primary,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                error.errorCode ==
                                        MobileScannerErrorCode.permissionDenied
                                    ? 'Camera access is off. Allow camera access in Settings or switch to a barcode scanner.'
                                    : 'Camera scanning is unavailable. Switch to a barcode scanner or enter the barcode below.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.surface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        placeholderBuilder: (_) => const ColoredBox(
                          color: AppColors.primary,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
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
                              borderRadius: BorderRadius.circular(AppRadii.row),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Text(
                          'Align the barcode inside the frame',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.surface,
                            shadows: const [
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
        ],
      ),
    );
  }
}
