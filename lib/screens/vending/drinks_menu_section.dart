import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/media.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';

const _menuGreen = Color(0xFF37DC86);

class Drink {
  final String name;
  final String tagline;
  final int price;
  final String slot;
  final int stock;
  final Color colorTop;
  final Color colorBottom;
  final String category;
  final String? badge;
  final String? imageAsset;
  final String imageUrl;
  final Product product;

  const Drink({
    required this.name,
    required this.tagline,
    required this.price,
    required this.slot,
    required this.stock,
    required this.colorTop,
    required this.colorBottom,
    required this.category,
    required this.product,
    this.badge,
    this.imageAsset,
    this.imageUrl = '',
  });

  factory Drink.fromProduct(Product product, int index) {
    final category = drinkCategoryFor(product);
    final colors = _drinkColors(category);
    final name = product.name;
    return Drink(
      name: name,
      tagline: product.description.trim().isEmpty
          ? product.weight
          : product.description.trim(),
      price: product.price.round(),
      slot: '${String.fromCharCode(65 + (index ~/ 3) % 6)}${index % 3 + 1}',
      stock: product.stock,
      colorTop: colors.$1,
      colorBottom: colors.$2,
      category: category,
      badge: product.isBestSeller ? 'Best seller' : null,
      imageUrl: product.imageUrl,
      product: product,
    );
  }
}

String drinkCategoryFor(Product product) {
  final category = '${product.categorySlug ?? ''} ${product.categoryName ?? ''}'
      .toLowerCase();
  final searchable =
      '$category ${product.name} ${product.description}'.toLowerCase();
  switch (product.vendingSection?.toUpperCase()) {
    case 'SODA':
      return 'Soda';
    case 'TEA_COFFEE':
      return 'Tea & Coffee';
    case 'ENERGY':
      return 'Energy';
  }
  if (searchable.contains('milk') ||
      searchable.contains('lassi') ||
      searchable.contains('water')) {
    return 'Hidden';
  }
  if (searchable.contains('energy') ||
      searchable.contains('power') ||
      searchable.contains('energy drink')) {
    return 'Energy';
  }
  if (searchable.contains('tea') || searchable.contains('coffee')) {
    return 'Tea & Coffee';
  }
  return 'Soda';
}

(Color, Color) _drinkColors(String category) {
  return switch (category) {
    'Tea & Coffee' => (const Color(0xFF37483F), const Color(0xFF7CA06E)),
    'Energy' => (const Color(0xFF4C3B79), const Color(0xFFB13E5C)),
    _ => (const Color(0xFF3A5265), const Color(0xFF697D9C)),
  };
}

class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        key: const ValueKey('drinks-category-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            child: ChoiceChip(
              key: ValueKey('drink-category-$category'),
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => onSelected(category),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected
                    ? isDark
                        ? const Color(0xFF101316)
                        : Colors.white
                    : colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor:
                  isDark ? const Color(0xFF20262C) : colors.surfaceContainerLow,
              selectedColor: isDark ? Colors.white : const Color(0xFF176B42),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF176B42))
                    : colors.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          );
        },
      ),
    );
  }
}

class DrinkCard extends StatelessWidget {
  final Drink drink;
  final bool featured;
  final bool selected;
  final ValueChanged<Product> onSelect;
  final ValueChanged<Product> onAdd;

  const DrinkCard({
    super.key,
    required this.drink,
    required this.featured,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = drink.stock <= 0;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = BorderRadius.circular(22);
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? (isDark ? _menuGreen : const Color(0xFF218653))
                  : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (isDark ? _menuGreen : const Color(0xFF218653))
                          .withValues(alpha: .19),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: featured
              ? _FeaturedDrinkCard(
                  drink: drink,
                  selected: selected,
                  disabled: disabled,
                  onSelect: onSelect,
                  onAdd: onAdd,
                  radius: radius,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 45,
                      child: DrinkStage(
                        drink: drink,
                        featured: false,
                        disabled: disabled,
                        selected: selected,
                        radius: radius,
                      ),
                    ),
                    Expanded(
                      flex: 55,
                      child: DrinkInfoPlate(
                        drink: drink,
                        disabled: disabled,
                        onSelect: onSelect,
                        onAdd: onAdd,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _FeaturedDrinkCard extends StatelessWidget {
  final Drink drink;
  final bool selected;
  final bool disabled;
  final ValueChanged<Product> onSelect;
  final ValueChanged<Product> onAdd;
  final BorderRadius radius;

  const _FeaturedDrinkCard({
    required this.drink,
    required this.selected,
    required this.disabled,
    required this.onSelect,
    required this.onAdd,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DrinkStage(
              drink: drink,
              featured: true,
              disabled: disabled,
              selected: selected,
              radius: radius,
            ),
          ),
          Expanded(
            flex: 6,
            child: DrinkInfoPlate(
              drink: drink,
              disabled: disabled,
              onSelect: onSelect,
              onAdd: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class DrinkStage extends StatelessWidget {
  final Drink drink;
  final bool featured;
  final bool disabled;
  final bool selected;
  final BorderRadius radius;

  const DrinkStage({
    super.key,
    required this.drink,
    required this.featured,
    required this.disabled,
    required this.selected,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = (constraints.maxHeight * (featured ? .84 : .60))
            .clamp(42.0, constraints.maxWidth * (featured ? .92 : .70))
            .toDouble();
        final artWidth = (artSize * (featured ? .78 : .68))
            .clamp(34.0, constraints.maxWidth * (featured ? .84 : .58))
            .toDouble();
        return ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                key: featured
                    ? const ValueKey('featured-drink-white-stage')
                    : null,
                decoration: featured
                    ? const BoxDecoration(color: Colors.white)
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: disabled
                              ? const [Color(0xFF42474D), Color(0xFF272C31)]
                              : [drink.colorTop, drink.colorBottom],
                        ),
                      ),
              ),
              if (!featured)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(.04, -.12),
                          radius: .82,
                          colors: [
                            Colors.white
                                .withValues(alpha: disabled ? .06 : .25),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                top: 10,
                bottom: 9,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!featured)
                        Positioned(
                          bottom: artSize * .04,
                          child: Container(
                            width: artSize * .68,
                            height: artSize * .12,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .28),
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(artSize, artSize),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .3),
                                  blurRadius: artSize * .14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(
                        width: artWidth,
                        height: artSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: disabled
                                ? ColorFiltered(
                                    colorFilter: const ColorFilter.matrix([
                                      .2126,
                                      .7152,
                                      .0722,
                                      0,
                                      0,
                                      .2126,
                                      .7152,
                                      .0722,
                                      0,
                                      0,
                                      .2126,
                                      .7152,
                                      .0722,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: Opacity(
                                      opacity: .68,
                                      child: _DrinkProductArt(drink: drink),
                                    ),
                                  )
                                : _DrinkProductArt(drink: drink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (disabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .18),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                top: 10,
                child: _StagePill(
                  label: disabled ? 'Sold out' : drink.badge,
                  maxWidth: constraints.maxWidth * .62,
                  soldOut: disabled,
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: _SlotPill(label: drink.slot, soldOut: disabled),
              ),
              if (!disabled && drink.stock <= 2)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _StockPill(stock: drink.stock),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DrinkProductArt extends StatelessWidget {
  final Drink drink;

  const _DrinkProductArt({required this.drink});

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: _CanPainter(
        top: drink.colorTop,
        bottom: drink.colorBottom,
        label: drink.name,
      ),
    );
    if (drink.imageAsset case final asset? when asset.isNotEmpty) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    if (drink.imageUrl.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: optimizedProductImageUrl(drink.imageUrl, targetWidth: 320),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      memCacheWidth: 240,
      memCacheHeight: 320,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _CanPainter extends CustomPainter {
  final Color top;
  final Color bottom;
  final String label;

  const _CanPainter({
    required this.top,
    required this.bottom,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final body = Rect.fromLTWH(size.width * .12, size.height * .08,
        size.width * .76, size.height * .84);
    final radius = Radius.circular(size.width * .12);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(body);
    canvas.drawRRect(RRect.fromRectAndRadius(body, radius), bodyPaint);
    final rimPaint = Paint()..color = const Color(0xFFD9E1E4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .19, size.height * .04, size.width * .62,
            size.height * .08),
        Radius.circular(size.width * .08),
      ),
      rimPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .19, size.height * .90, size.width * .62,
            size.height * .055),
        Radius.circular(size.width * .06),
      ),
      Paint()..color = const Color(0xFFBCC8CC),
    );
    final labelRect = Rect.fromLTWH(
      size.width * .16,
      size.height * .38,
      size.width * .68,
      size.height * .24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, Radius.circular(size.width * .05)),
      Paint()..color = Colors.white.withValues(alpha: .88),
    );
    final text = TextPainter(
      text: TextSpan(
        text: label.trim().isEmpty ? 'DRINK' : label.trim().split(' ').first,
        style: TextStyle(
          color: top,
          fontSize: size.width * .11,
          fontWeight: FontWeight.w900,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelRect.width - 4);
    text.paint(
      canvas,
      Offset(
        labelRect.center.dx - text.width / 2,
        labelRect.center.dy - text.height / 2,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .24, size.height * .13, size.width * .08,
            size.height * .62),
        Radius.circular(size.width * .05),
      ),
      Paint()..color = Colors.white.withValues(alpha: .28),
    );
  }

  @override
  bool shouldRepaint(covariant _CanPainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.label != label;
}

class _StagePill extends StatelessWidget {
  final String? label;
  final double maxWidth;
  final bool soldOut;

  const _StagePill({
    required this.label,
    required this.maxWidth,
    required this.soldOut,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null && !soldOut) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            soldOut ? 'Sold out' : label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF101316),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  final String label;
  final bool soldOut;

  const _SlotPill({required this.label, required this.soldOut});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: soldOut ? .45 : .28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  final int stock;

  const _StockPill({required this.stock});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          'Only $stock left',
          style: const TextStyle(
            color: Color(0xFF101316),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class DrinkInfoPlate extends StatelessWidget {
  final Drink drink;
  final bool disabled;
  final ValueChanged<Product> onSelect;
  final ValueChanged<Product> onAdd;

  const DrinkInfoPlate({
    super.key,
    required this.drink,
    required this.disabled,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final quantity = context.select<CartProvider, int>(
      (cart) => cart.itemForProduct(drink.product.id)?.quantity ?? 0,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                drink.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: disabled ? colors.onSurfaceVariant : colors.onSurface,
                  fontSize: 14,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                drink.tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: disabled
                      ? colors.onSurfaceVariant
                      : colors.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.15,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rs. ${drink.price}',
              maxLines: 1,
              style: TextStyle(
                color: disabled ? colors.onSurfaceVariant : colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: disabled
                ? FilledButton(
                    key: ValueKey('sold-out-drink-${drink.product.id}'),
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: colors.surfaceContainerHighest,
                      disabledForegroundColor: colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Sold out',
                      maxLines: 1,
                      style: TextStyle(fontSize: 11),
                    ),
                  )
                : quantity == 0
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox.square(
                          dimension: 44,
                          child: FilledButton(
                            key: ValueKey('add-drink-${drink.product.id}'),
                            onPressed: () {
                              onSelect(drink.product);
                              onAdd(drink.product);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _menuGreen,
                              foregroundColor: const Color(0xFF03210F),
                              padding: EdgeInsets.zero,
                              shape: const StadiumBorder(),
                            ),
                            child: const Icon(Icons.add_rounded),
                          ),
                        ),
                      )
                    : _DrinkCartStepper(
                        product: drink.product,
                        quantity: quantity,
                        onAdd: onAdd,
                      ),
          ),
        ],
      ),
    );
  }
}

class _DrinkCartStepper extends StatelessWidget {
  final Product product;
  final int quantity;
  final ValueChanged<Product> onAdd;

  const _DrinkCartStepper({
    required this.product,
    required this.quantity,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20352B) : const Color(0xFFE5F5EC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _menuGreen.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              tooltip: 'Decrease ${product.name}',
              onPressed: () => cart.updateQuantity(product.id, quantity - 1),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.remove_rounded, size: 19),
              color: _menuGreen,
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              tooltip: 'Increase ${product.name}',
              onPressed: quantity < product.stock ? () => onAdd(product) : null,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.add_rounded, size: 19),
              color: _menuGreen,
            ),
          ),
        ],
      ),
    );
  }
}
