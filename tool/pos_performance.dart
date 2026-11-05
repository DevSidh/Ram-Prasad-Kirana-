// Isolated service workload in a real Flutter profile/release runtime.
// No authentication, production folders, network, payments or printers are used.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

import 'pos_performance_support.dart';

const _label = String.fromEnvironment('PERF_LABEL', defaultValue: 'run');
const _billCount = int.fromEnvironment('PERF_BILLS', defaultValue: 3000);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Workload()));
}

class _Workload extends StatefulWidget {
  const _Workload();
  @override
  State<_Workload> createState() => _WorkloadState();
}

class _WorkloadState extends State<_Workload> {
  String _phase = 'Preparing isolated fixtures';
  final _frames = <FrameTiming>[];
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _timings(List<FrameTiming> values) {
    if (_measuring) _frames.addAll(values);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  Future<void> _run() async {
    Directory? root;
    try {
      final fixtures =
          PerformanceFixtures(label: _label, billCount: _billCount);
      root = await Directory.systemTemp.createTemp('faststore-perf-');
      final billing = LocalBillingStore(rootPath: '${root.path}/bills');
      final store = OfflinePosStore(
          storageDirectory: root, billingStore: billing, useLocalStock: true);
      final results = <String, dynamic>{
        'label': _label,
        'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
        'os': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'catalogueSize': PerformanceFixtures.catalogueSize,
        'billCount': _billCount,
        'scope':
            'isolated real service calls; animated heartbeat, not end-to-end checkout',
      };
      final products = List.generate(
          PerformanceFixtures.catalogueSize,
          (i) => PosProduct(
                id: 'fixture-$i',
                name: 'Fixture product $i',
                sku: 'SKU-$i',
                barcode: '${8900000000000 + i}',
                price: 10.25,
                unitLabel: 'pcs',
                available: PerformanceFixtures.initialStock,
              ));
      await store.saveCatalog(products);
      await Directory(billing.rootPath).create(recursive: true);
      for (var i = 0; i < _billCount; i++) {
        await File('${billing.rootPath}/fixture-$i.json')
            .writeAsString(jsonEncode({
          'invoiceNumber': 'FIXTURE-$i',
          'date': '2026-11-03T06:00:00Z',
          'total': 10.25,
          'trackLocalStock': true,
          'syncState': 'local_only',
          'items': [
            {
              'productId': 'fixture-${fixtures.productIndexForBill(i)}',
              'quantity': 1
            }
          ],
        }));
      }
      final rssBefore = ProcessInfo.currentRss;
      Future<void> measure(
          String name, int count, Future<void> Function(int) work) async {
        if (mounted) setState(() => _phase = name);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        _frames.clear();
        _measuring = true;
        final samples = <double>[];
        try {
          for (var i = 0; i < count; i++) {
            final task = developer.TimelineTask()..start(name);
            final watch = Stopwatch()..start();
            try {
              await work(i);
            } finally {
              watch.stop();
              task.finish();
            }
            samples.add(watch.elapsedMicroseconds / 1000);
          }
          await Future<void>.delayed(const Duration(milliseconds: 150));
        } finally {
          _measuring = false;
        }
        results[name] = {
          ..._summary(samples),
          'buildMs': _summary(_frames
              .map((f) => f.buildDuration.inMicroseconds / 1000)
              .toList()),
          'rasterMs': _summary(_frames
              .map((f) => f.rasterDuration.inMicroseconds / 1000)
              .toList()),
          'rssBytes': ProcessInfo.currentRss,
        };
      }

      await measure('catalogueColdRead', 1, (_) async {
        await store.readCatalog();
      });
      await measure('cachedBarcodeSearch', 30, (i) async {
        final matches = await store.searchCatalog('${8900000000000 + i}');
        if (matches.length != 1 ||
            matches.single.available != fixtures.expectedStock(i)) {
          throw StateError('Incorrect stock or lookup result');
        }
      });
      await measure('unchangedProductMerge', 20,
          (i) => store.mergeCatalog([products[i]]));
      await measure('durableSaleWithStockValidation', 10, (i) async {
        final key = '550e8400-e29b-41d4-a716-${i.toString().padLeft(12, '0')}';
        await savePerformanceSale(
          billing: billing,
          store: store,
          productId: 'fixture-1500',
          requestId: key,
        );
      });
      final finalStock = await store.readCatalog(freshStock: true);
      if (finalStock
              .singleWhere((product) => product.id == 'fixture-1500')
              .available !=
          fixtures.expectedStock(1500) - 10) {
        throw StateError(
            'Committed fixture sales did not deduct stock correctly');
      }
      results['rssBeforeBytes'] = rssBefore;
      results['rssAfterBytes'] = ProcessInfo.currentRss;
      results['peakRssBytes'] = ProcessInfo.maxRss;
      final output = File('docs/performance/${fixtures.label}.json');
      await output.parent.create(recursive: true);
      await output
          .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
      print('PERFORMANCE_RESULT ${output.absolute.path}');
    } catch (error, stack) {
      print('PERFORMANCE_FAILURE $error\n$stack');
      exitCode = 1;
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(_timings);
      // Only our uniquely allocated temporary directory is removed.
      try {
        if (root != null) await root.delete(recursive: true);
      } catch (error) {
        print('PERFORMANCE_CLEANUP_FAILURE $error');
        exitCode = 1;
      }
      exit(exitCode);
    }
  }

  static Map<String, num> _summary(List<double> values) {
    if (values.isEmpty) return {'samples': 0};
    values.sort();
    return {
      'samples': values.length,
      'p50': values[((values.length - 1) * .50).ceil()],
      'p95': values[((values.length - 1) * .95).ceil()],
      'max': values.last
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('FastStore isolated performance workload')),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(_phase),
        ])),
      );
}
