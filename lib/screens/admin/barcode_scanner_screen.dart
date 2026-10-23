import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/scanned_product_barcode.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _manualController = TextEditingController();
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
  String? _scanError;
  String? _lastRejectedValue;

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didScan) return;
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
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error.errorCode ==
                                  MobileScannerErrorCode.permissionDenied
                              ? 'Camera access is off. Allow camera access in Settings or enter the barcode below.'
                              : 'Camera scanning is unavailable. Enter the barcode below.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  placeholderBuilder: (_) => const ColoredBox(
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 170,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(18),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                TextField(
                  controller: _manualController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitManualCode(),
                  decoration: InputDecoration(
                    labelText: 'Enter or scan with a hardware scanner',
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
                  'USB and Bluetooth scanners can type into this field.',
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
