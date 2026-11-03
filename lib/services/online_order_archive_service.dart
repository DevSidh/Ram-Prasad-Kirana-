import 'dart:convert';
import 'dart:io';

import '../models/admin_models.dart';

/// Keeps an on-computer copy of online orders and their status changes.
/// The database remains authoritative; this archive is for local records.
class OnlineOrderArchiveService {
  const OnlineOrderArchiveService();

  static const rootPath = 'C:/Ramprasad/online';
  static const confirmFolderName = 'Confirm order';
  static const cancelledFolderName = 'Order cancelled';
  static const deliveryFolderName = 'Order to be delivered';
  static const deliveredFolderName = 'Order delivered';

  static const _statusFolders = [
    confirmFolderName,
    cancelledFolderName,
    deliveryFolderName,
    deliveredFolderName,
  ];

  Future<Directory> ensureFolders() async {
    final root = Directory(rootPath);
    for (final name in _statusFolders) {
      await Directory('${root.path}/$name').create(recursive: true);
    }
    await Directory('${root.path}/history').create(recursive: true);
    return root;
  }

  Future<void> archiveOrders(Iterable<AdminOrder> orders) async {
    final root = await ensureFolders();
    for (final order in orders) {
      if (order.id.isEmpty || order.orderNumber.trim().isEmpty) continue;
      await _archiveOrder(root, order);
    }
  }

  Future<void> _archiveOrder(Directory root, AdminOrder order) async {
    final safeName = _safeFileName(order.orderNumber);
    final targetFolder = _folderFor(order.status);
    final targetFile = File('${root.path}/$targetFolder/$safeName.json');
    final allFiles = [
      for (final folder in _statusFolders)
        File('${root.path}/$folder/$safeName.json'),
    ];
    final oldFiles = <File>[];
    for (final file in allFiles) {
      if (file.path == targetFile.path || !await file.exists()) continue;
      oldFiles.add(file);
    }

    final nextRecord = _orderJson(order);
    var currentRecordChanged = false;
    if (await targetFile.exists()) {
      try {
        final currentRecord = jsonDecode(await targetFile.readAsString());
        if (currentRecord is Map<String, dynamic>) {
          currentRecordChanged =
              jsonEncode(_withoutSyncTimestamp(currentRecord)) !=
                  jsonEncode(_withoutSyncTimestamp(nextRecord));
        } else {
          currentRecordChanged = true;
        }
      } on FormatException {
        currentRecordChanged = true;
      }
    }

    if (oldFiles.isNotEmpty || currentRecordChanged) {
      final historyFile = File('${root.path}/history/$safeName.jsonl');
      final recordsToArchive = [
        ...oldFiles,
        if (currentRecordChanged) targetFile,
      ];
      for (final oldFile in recordsToArchive) {
        final oldRecord = await oldFile.readAsString();
        await historyFile.writeAsString(
          '$oldRecord\r\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    }

    final temporary = File('${targetFile.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(nextRecord),
      flush: true,
    );
    if (await targetFile.exists()) await targetFile.delete();
    await temporary.rename(targetFile.path);

    // Remove stale status copies only after both the history and current
    // status snapshots have been safely written.
    for (final oldFile in oldFiles) {
      if (await oldFile.exists()) await oldFile.delete();
    }
  }

  String _folderFor(String status) => switch (status.toUpperCase()) {
        'PLACED' => confirmFolderName,
        'CANCELLED' => cancelledFolderName,
        'DELIVERED' => deliveredFolderName,
        _ => deliveryFolderName,
      };

  String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'order' : safe;
  }

  Map<String, dynamic> _withoutSyncTimestamp(Map<String, dynamic> record) =>
      Map<String, dynamic>.from(record)..remove('syncedToComputerAt');

  Map<String, dynamic> _orderJson(AdminOrder order) => {
        'id': order.id,
        'orderNumber': order.orderNumber,
        'status': order.status,
        'paymentMethod': order.paymentMethod,
        'paymentStatus': order.paymentStatus,
        'subtotal': order.subtotal,
        'deliveryFee': order.deliveryFee,
        'discount': order.discount,
        'total': order.total,
        'couponCode': order.couponCode,
        'customer': {
          'name': order.customerName,
          'phone': order.customerPhone,
          'email': order.customerEmail,
        },
        'shipping': {
          'address': order.shippingAddress,
          'instructions': order.deliveryInstructions,
        },
        'createdAt': order.createdAt,
        'items': [
          for (final item in order.items)
            {
              'name': item.name,
              'sku': item.sku,
              'quantity': item.quantity,
              'price': item.price,
              'total': item.total,
              'isWholesale': item.isWholesale,
            },
        ],
        'statusHistory': order.statusHistory,
        'delivery': {
          'id': order.deliveryId,
          'status': order.deliveryStatus,
          'deliveryPersonId': order.deliveryPersonId,
          'deliveryPersonName': order.deliveryPersonName,
          'statusHistory': order.deliveryHistory,
        },
        'scheduledDeliveryAt': order.scheduledDeliveryAt?.toIso8601String(),
        'syncedToComputerAt': DateTime.now().toIso8601String(),
      };
}
