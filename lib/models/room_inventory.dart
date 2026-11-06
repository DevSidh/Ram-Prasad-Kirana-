import 'pos_models.dart';
import 'stock_summary.dart';

class InventoryRoom {
  const InventoryRoom(
      {required this.id,
      required this.name,
      required this.number,
      this.active = true});
  final String id, name, number;
  final bool active;
  String get label => '$number · $name';
  factory InventoryRoom.fromJson(Map<String, dynamic> json) => InventoryRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as String,
      active: json['active'] == true);
}

class RoomPick {
  const RoomPick(
      {required this.productId, required this.roomId, required this.quantity});
  final String productId;
  final String? roomId;
  final int quantity;
  Map<String, dynamic> toJson() =>
      {'productId': productId, 'roomId': roomId, 'quantity': quantity};
  factory RoomPick.fromJson(Map<String, dynamic> json) => RoomPick(
      productId: json['productId'] as String,
      roomId: json['roomId'] as String?,
      quantity: (json['quantity'] as num).toInt());
}

class RoomInventorySnapshot {
  RoomInventorySnapshot(
      {required this.rooms,
      required this.stocks,
      required this.totals,
      required this.capturedAt,
      this.products = const [],
      this.isCached = false});
  final List<InventoryRoom> rooms;

  /// Null room IDs represent the calculated Unassigned location.
  final Map<String, Map<String, int>> stocks;
  final Map<String, ({int total, int available})> totals;
  final DateTime capturedAt;
  final bool isCached;
  final List<PosProduct> products;
  final Set<String> conflictedProducts = {};
  bool get configured => rooms.any((room) => room.active);
  List<String?> get locations =>
      [null, ...rooms.where((room) => room.active).map((room) => room.id)];
  String roomLabel(String? id) => id == null
      ? 'Unassigned'
      : rooms.where((room) => room.id == id).firstOrNull?.label ?? id;
  int quantity(String productId, String? roomId) {
    if (roomId != null) return stocks[productId]?[roomId] ?? 0;
    return ((totals[productId]?.total ?? 0) -
            (stocks[productId]?.values.fold<int>(0, (sum, n) => sum + n) ?? 0))
        .clamp(0, 2147483647);
  }

  int available(String productId, String? roomId) =>
      quantity(productId, roomId).clamp(0, totals[productId]?.available ?? 0);
  factory RoomInventorySnapshot.fromJson(Map<String, dynamic> json,
      {bool cached = false}) {
    final stocks = <String, Map<String, int>>{};
    for (final row in (json['stocks'] as List).cast<Map<String, dynamic>>()) {
      (stocks[row['productId'] as String] ??= {})[row['roomId'] as String] =
          (row['quantity'] as num).toInt();
    }
    return RoomInventorySnapshot(
        products: (json['products'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(PosProduct.fromJson)
            .toList(),
        rooms: (json['rooms'] as List)
            .cast<Map<String, dynamic>>()
            .map(InventoryRoom.fromJson)
            .toList(),
        stocks: stocks,
        totals: {
          for (final row
              in (json['totals'] as List).cast<Map<String, dynamic>>())
            row['productId'] as String: (
              total: (row['total'] as num).toInt(),
              available: (row['available'] as num).toInt()
            )
        },
        capturedAt: DateTime.parse(json['capturedAt'] as String),
        isCached: cached);
  }
  void validatePicks(List<RoomPick> picks, Map<String, int> required) {
    final actual = <String, int>{};
    final seen = <String>{};
    for (final pick in picks) {
      if (pick.quantity <= 0 ||
          !required.containsKey(pick.productId) ||
          !seen.add('${pick.productId}/${pick.roomId}') ||
          !locations.contains(pick.roomId) ||
          pick.quantity > available(pick.productId, pick.roomId)) {
        throw StateError(
            'Room quantities changed. Refresh and choose the source rooms again.');
      }
      actual[pick.productId] = (actual[pick.productId] ?? 0) + pick.quantity;
    }
    for (final entry in required.entries) {
      if (conflictedProducts.contains(entry.key)) {
        throw StateError(
            'Local room stock conflicts with server stock. Review the stock synchronization conflict before billing this product.');
      }
      if (actual[entry.key] != entry.value ||
          entry.value > (totals[entry.key]?.available ?? 0)) {
        throw StateError(
            'Choose room quantities matching every bill item exactly.');
      }
    }
  }
}

String roomStockUnit(PosProduct product) =>
    StockSummary.isLooseWeight(product) ? 'g' : product.unitLabel;
