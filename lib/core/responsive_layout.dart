int responsiveGridCrossAxisCount({
  required double availableWidth,
  double horizontalPadding = 0,
  double minTileWidth = 136,
  double spacing = 12,
  int maxColumns = 6,
}) {
  final contentWidth =
      (availableWidth - horizontalPadding).clamp(0.0, double.infinity);
  final columns = ((contentWidth + spacing) / (minTileWidth + spacing)).floor();
  return columns.clamp(1, maxColumns).toInt();
}
