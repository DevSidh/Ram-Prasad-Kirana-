// Drives the production bill composer with isolated fixtures. No sale is made.
// Console output is the public interface of this standalone diagnostic tool.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/screens/admin/admin_billing_screen.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

const _label = String.fromEnvironment('PERF_LABEL', defaultValue: 'billing-ui');
const _diagnostic = bool.fromEnvironment('PERF_DIAGNOSTIC');

class _FixtureApi extends AdminApiService {
  _FixtureApi() : super(ApiService(baseUrl: 'http://127.0.0.1:1'));
  int lookups = 0;
  @override
  Future<List<PosProduct>> searchPosProducts(String query) async {
    lookups++;
    return List.generate(20, (i) => _product(i));
  }
}

PosProduct _product(int i) => PosProduct(
    id: 'fixture-$i',
    name: 'Fixture $i',
    sku: 'SKU-$i',
    barcode: '${8900000000000 + i}',
    price: 10.25,
    unitLabel: 'pcs',
    available: 10000);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await Directory.systemTemp.createTemp('faststore-ui-perf-');
  final store = OfflinePosStore(
      storageDirectory: root,
      billingStore: LocalBillingStore(rootPath: '${root.path}/bills'),
      useLocalStock: true);
  await store.saveCatalog(List.generate(2000, _product));
  final api = _FixtureApi();
  runApp(MaterialApp(
      home: Scaffold(body: _Driver(root: root, store: store, api: api))));
}

class _Driver extends StatefulWidget {
  const _Driver({required this.root, required this.store, required this.api});
  final Directory root;
  final OfflinePosStore store;
  final _FixtureApi api;
  @override
  State<_Driver> createState() => _DriverState();
}

class _DriverState extends State<_Driver> {
  final _frames = <FrameTiming>[];
  final _clock = Stopwatch()..start();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _timings(List<FrameTiming> timings) => _frames.addAll(timings);

  List<T> _widgets<T extends Widget>(bool Function(T) matches) {
    final result = <T>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is T && matches(widget)) result.add(widget);
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement!.visitChildren(visit);
    return result;
  }

  Future<void> _until(bool Function() ready) async {
    final timeout = Stopwatch()..start();
    while (!ready()) {
      if (timeout.elapsed > const Duration(seconds: 10)) {
        throw StateError('Fixture UI timed out');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _run() async {
    final sandbox = widget.root;
    try {
      await _until(() =>
          _widgets<TextField>((w) => w.decoration?.labelText == 'Qty')
              .isNotEmpty);
      final firstUsable = _clock.elapsedMicroseconds / 1000;
      if (_diagnostic) {
        print(
            'DIAGNOSTIC_READY: production bill composer, synthetic data only');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      _frames.clear();
      final cpuStart = developer.Timeline.now;
      final memoryBefore = _diagnostic ? await _rpc('getMemoryUsage') : null;
      final callbacks = <double>[];
      final presented = <double>[];
      for (var i = 0; i < 60; i++) {
        await _until(() =>
            _widgets<TextField>((w) => w.decoration?.labelText == 'Qty')
                .isNotEmpty);
        final field =
            _widgets<TextField>((w) => w.decoration?.labelText == 'Qty').first;
        final watch = Stopwatch()..start();
        field.controller!.text = '${i % 3 + 1}';
        field.onChanged!('${i % 3 + 1}');
        callbacks.add(watch.elapsedMicroseconds / 1000);
        await WidgetsBinding.instance.endOfFrame;
        presented.add(watch.elapsedMicroseconds / 1000);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final editingFrames = List<FrameTiming>.of(_frames);
      final search = _widgets<TextField>((w) =>
          w.decoration?.labelText?.startsWith('Scan barcode') == true).first;
      final scans = <double>[];
      // Admit a burst immediately: repeat codes must remain separate actions.
      for (var i = 0; i < 20; i++) {
        search.onSubmitted!('8900000000000');
      }
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        await _until(() => _widgets<FilledButton>((w) =>
                w.child is Text && (w.child as Text).data == 'Add to bill')
            .isNotEmpty);
        scans.add(watch.elapsedMicroseconds / 1000);
        final add = _widgets<FilledButton>((w) =>
            w.child is Text && (w.child as Text).data == 'Add to bill').first;
        add.onPressed!();
        // The closing route remains in the tree during its animation.
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final firstQty =
          _widgets<TextField>((w) => w.decoration?.labelText == 'Qty').first;
      // 100 held lines; row zero ended at quantity 3, plus 20 repeated scans.
      if (firstQty.controller?.text != '23') {
        throw StateError(
            'A rapid scan was lost or duplicated: ${firstQty.controller?.text}');
      }
      if (_diagnostic) {
        final samples = await _rpc('getCpuSamples', {
          'timeOriginMicros': '$cpuStart',
          'timeExtentMicros': '${developer.Timeline.now - cpuStart}',
        });
        final trace = File('docs/performance/$_label-cpu.json');
        await trace.parent.create(recursive: true);
        await trace.writeAsString(jsonEncode({
          'memoryBefore': memoryBefore,
          'memoryAfter': await _rpc('getMemoryUsage'),
          'cpu': samples,
        }));
      }
      final output = File('docs/performance/$_label.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(const JsonEncoder.withIndent('  ').convert({
        'label': _label,
        'mode': kProfileMode ? 'profile' : 'release',
        'diagnostic': _diagnostic,
        'scope':
            'production PosBillDialog, isolated fixture API/files; no payments or saves',
        'heldCartLines': 100,
        'catalogueProducts': 2000,
        'firstComposerFrameMs': firstUsable,
        'quantityCallbackMs': _stats(callbacks),
        'quantityToFrameMs': _stats(presented),
        'buildMs': _stats(editingFrames
            .map((f) => f.buildDuration.inMicroseconds / 1000)
            .toList()),
        'rasterMs': _stats(editingFrames
            .map((f) => f.rasterDuration.inMicroseconds / 1000)
            .toList()),
        'queuedScanToPromptMs': _stats(scans),
        'scansAdmitted': 20,
        'scansAdded': 20,
        'serverProductLookups': widget.api.lookups,
        'rssBytes': ProcessInfo.currentRss,
      }));
      print('PERFORMANCE_RESULT ${output.absolute.path}');
      if (_diagnostic) await Future<void>.delayed(const Duration(seconds: 90));
    } catch (error, stack) {
      print('PERFORMANCE_FAILURE $error\n$stack');
      exitCode = 1;
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(_timings);
      runApp(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sandbox.delete(recursive: true);
      exit(exitCode);
    }
  }

  Map<String, num> _stats(List<double> values) {
    values.sort();
    if (values.isEmpty) return {'samples': 0};
    return {
      'samples': values.length,
      'p50': values[((values.length - 1) * .5).ceil()],
      'p95': values[((values.length - 1) * .95).ceil()],
      'max': values.last
    };
  }

  Future<dynamic> _rpc(String method,
      [Map<String, String> params = const {}]) async {
    final info = await developer.Service.getInfo();
    final uri = info.serverUri;
    if (uri == null) {
      throw StateError('Diagnostic requires a profile VM service.');
    }
    final client = HttpClient();
    try {
      final request =
          await client.getUrl(uri.resolve(method).replace(queryParameters: {
        'isolateId': developer.Service.getIsolateId(Isolate.current)!,
        ...params,
      }));
      final response = await request.close();
      final decoded =
          jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      if (decoded['error'] != null) throw StateError('${decoded['error']}');
      return decoded['result'];
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) => PosBillDialog(
        api: widget.api,
        offlineStore: widget.store,
        refreshCatalogOnOpen: false,
        operatorId: 'fixture',
        allowOfflineSync: false,
        onScan: () async => null,
        onNewBill: () {},
        heldSale: PosHeldSale(
            id: 'fixture-held',
            customerName: null,
            customerPhone: null,
            createdAt: DateTime.utc(2026),
            items: List.generate(
                100,
                (i) => {
                      'productId': 'fixture-$i',
                      'productName': 'Fixture $i',
                      'sku': 'SKU-$i',
                      'price': 10.25,
                      'unitLabel': 'pcs',
                      'quantity': 1,
                    })),
      );
}
