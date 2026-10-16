import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_widgets.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/store_animation.dart';

const _canColors = <Color>[
  Color(0xFFE84A3C),
  Color(0xFF38A982),
  Color(0xFF3873D9),
  Color(0xFFDC76A0),
  Color(0xFF825D47),
  Color(0xFF7A9B43),
  Color(0xFFF09437),
  Color(0xFF35A9D5),
  Color(0xFFE27652),
];

class VendingMachineScreen extends StatefulWidget {
  const VendingMachineScreen({super.key});

  @override
  State<VendingMachineScreen> createState() => _VendingMachineScreenState();
}

class _VendingMachineScreenState extends State<VendingMachineScreen> {
  List<Product> _drinks = const [];
  Product? _selectedDrink;
  Product? _panelDrink;
  String? _error;
  bool _loading = true;
  int _quantity = 1;
  bool _observedTabVisibility = false;
  bool _wasTabVisible = true;

  @override
  void initState() {
    super.initState();
    _loadDrinks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_observedTabVisibility && isVisible && !_wasTabVisible) {
      _loadDrinks();
    }
    _observedTabVisibility = true;
    _wasTabVisible = isVisible;
  }

  Future<void> _loadDrinks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiService>().get(
        '/products',
        queryParams: const {
          'vendingDrink': 'true',
          'page': '1',
          'limit': '100',
        },
      );
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw const FormatException(
          'The server returned an invalid vending drink list.',
        );
      }
      final products = (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .where((product) => product.isVendingDrink)
          .toList(growable: false);
      if (!mounted) return;
      Product? selectedDrink;
      for (final product in products) {
        if (product.id == _selectedDrink?.id) {
          selectedDrink = product;
          break;
        }
      }
      setState(() {
        _drinks = products;
        _selectedDrink = selectedDrink;
        _panelDrink = selectedDrink;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _selectDrink(Product drink) {
    if (drink.stock <= 0) return;
    setState(() {
      _selectedDrink = drink;
      _panelDrink = drink;
      _quantity = 1;
    });
  }

  void _closeDrink() {
    setState(() => _selectedDrink = null);
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || _selectedDrink != null) return;
      setState(() => _panelDrink = null);
    });
  }

  void _adjustQuantity(int change) {
    final drink = _selectedDrink;
    if (drink == null) return;
    setState(() {
      _quantity =
          (_quantity + change).clamp(1, math.min(20, drink.stock)).toInt();
    });
  }

  void _addToCart() {
    final drink = _selectedDrink;
    if (drink == null) return;
    final quantity = _quantity;
    try {
      context.read<CartProvider>().addItem(drink, quantity);
      setState(() {
        _selectedDrink = null;
        _quantity = 1;
      });
      _closeDrink();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $quantity × ${drink.name} to cart.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Color _drinkColor(Product drink) =>
      _canColors[drink.id.hashCode.abs() % _canColors.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedDrink;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Vending machine'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh vending drinks',
            onPressed: _loading ? null : _loadDrinks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          AppBackground(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _loadDrinks,
                child: _loading && _drinks.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _drinks.isEmpty
                        ? StorePageError(
                            title: 'Drinks could not load',
                            message: _error!,
                            retryLabel: 'Try again',
                            onRetry: _loadDrinks,
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              10,
                              16,
                              120,
                            ),
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 510),
                                  child: _VendingMachineBody(
                                    drinks: _drinks,
                                    selectedDrink: selected,
                                    drinkColor: _drinkColor,
                                    onDrinkTap: _selectDrink,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: selected == null,
              child: GestureDetector(
                onTap: _closeDrink,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: selected == null ? 0 : 1,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .42),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            right: selected == null
                ? -math.min(380.0, MediaQuery.sizeOf(context).width * .9)
                : 0,
            width: math.min(380.0, MediaQuery.sizeOf(context).width * .9),
            child: _panelDrink == null
                ? const SizedBox.shrink()
                : _DrinkDetailsPanel(
                    key: ValueKey(_panelDrink!.id),
                    drink: _panelDrink!,
                    color: _drinkColor(_panelDrink!),
                    quantity: _quantity,
                    onClose: _closeDrink,
                    onDecrease: () => _adjustQuantity(-1),
                    onIncrease: () => _adjustQuantity(1),
                    onAddToCart: _addToCart,
                  ),
          ),
          if (_error != null && _drinks.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 8,
              child: Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Refresh failed: $_error',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VendingMachineBody extends StatelessWidget {
  final List<Product> drinks;
  final Product? selectedDrink;
  final Color Function(Product) drinkColor;
  final ValueChanged<Product> onDrinkTap;

  const _VendingMachineBody({
    required this.drinks,
    required this.selectedDrink,
    required this.drinkColor,
    required this.onDrinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final window = _MachineDisplayWindow(
          drinks: drinks,
          selectedDrink: selectedDrink,
          drinkColor: drinkColor,
          onDrinkTap: onDrinkTap,
          colors: colors,
        );
        final controls = _MachineControlPanel(
          drinkCount: drinks.length,
          selectedDrink: selectedDrink,
          onSelectDrink:
              selectedDrink == null ? null : () => onDrinkTap(selectedDrink!),
        );
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF5639),
                Color(0xFFE52F20),
                Color(0xFFB61F19),
              ],
            ),
            border:
                Border.all(color: Colors.white.withValues(alpha: .5), width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .34),
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ram Prasad',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'G E N E R A L   S T O R E',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: .88),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fresh drinks\nanytime',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFFFE4BB),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (compact) ...[
                window,
                const SizedBox(height: 10),
                controls,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: window),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: controls),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Good Drinks   ·   Better Days',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFFE4BB),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MachineDisplayWindow extends StatelessWidget {
  final List<Product> drinks;
  final Product? selectedDrink;
  final Color Function(Product) drinkColor;
  final ValueChanged<Product> onDrinkTap;
  final ColorScheme colors;

  const _MachineDisplayWindow({
    required this.drinks,
    required this.selectedDrink,
    required this.drinkColor,
    required this.onDrinkTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final empty = drinks.isEmpty;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF102431),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFA8C9E6), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA46ADFF),
            blurRadius: 15,
            spreadRadius: -7,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10212B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (_) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5E3FF),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF65BFFF),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 3),
            decoration: BoxDecoration(
              color: const Color(0xFF152F3D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF50738A)),
            ),
            child: empty
                ? const SizedBox(
                    height: 152,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'The machine is being stocked.\\nYour drinks will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD6E9F3),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: drinks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 142,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final drink = drinks[index];
                      return _DrinkSlot(
                        drink: drink,
                        color: drinkColor(drink),
                        selected: selectedDrink?.id == drink.id,
                        onTap: () => onDrinkTap(drink),
                      );
                    },
                  ),
          ),
          Container(
            height: 9,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFB4DCFF),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0xFF64B6FF), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF090F13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.keyboard_double_arrow_down_rounded,
                  color: Color(0xFF73BDFF),
                  size: 21,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    empty ? 'READY TO STOCK' : 'TAP A DRINK TO SELECT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: .9),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineControlPanel extends StatelessWidget {
  final int drinkCount;
  final Product? selectedDrink;
  final VoidCallback? onSelectDrink;

  const _MachineControlPanel({
    required this.drinkCount,
    required this.selectedDrink,
    required this.onSelectDrink,
  });

  @override
  Widget build(BuildContext context) {
    final drink = selectedDrink;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF07191A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF88A0A1), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA151F21),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.eco_rounded, color: Color(0xFF21C99A), size: 20),
              const SizedBox(height: 5),
              Text(
                drink == null ? 'Pick a drink' : drink.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                drink == null
                    ? '$drinkCount drinks · Choose from the shelf'
                    : 'Fresh from the store · ${drink.weight}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9DB7B2),
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Icon(
                drink == null
                    ? Icons.local_drink_outlined
                    : Icons.local_drink_rounded,
                color: const Color(0xFF21C99A),
                size: 38,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSelectDrink,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00684F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                  label: Text(
                    drink == null
                        ? 'Choose a drink'
                        : 'Rs. ${drink.price.toStringAsFixed(0)} · Details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final icon in [
              Icons.remove_rounded,
              Icons.add_rounded,
              Icons.currency_rupee_rounded,
            ])
              Expanded(
                child: Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD2D7D4),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFF8A9992)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66320B0A),
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: const Color(0xFF42534B), size: 19),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 33,
          decoration: BoxDecoration(
            color: const Color(0xFFAC382A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .45)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card_rounded, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tap / Insert Card',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.wifi_rounded, size: 14, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFF07111A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF65BFFF), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA288BFF),
                blurRadius: 13,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_drink_outlined,
                color: Color(0xFF65BFFF),
                size: 24,
              ),
              const SizedBox(height: 3),
              Text(
                drink == null ? 'Your drink goes here' : 'Ready when you are',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB7DBFF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrinkSlot extends StatelessWidget {
  final Product drink;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DrinkSlot({
    required this.drink,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = drink.stock > 0;
    return Semantics(
      button: isAvailable,
      enabled: isAvailable,
      label:
          '${drink.name}, Rs. ${drink.price.toStringAsFixed(0)}, ${isAvailable ? '${drink.stock} in stock' : 'sold out'}',
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF345B50)
                : Colors.black.withValues(alpha: .08),
            border: selected
                ? Border.all(color: const Color(0xFFFFD784), width: 2)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (drink.imageUrl.isNotEmpty)
                      ProductThumbnail(
                        imageUrl: drink.imageUrl,
                        size: 82,
                        fallbackIcon: Icons.local_drink_outlined,
                      )
                    else
                      _IllustratedCan(
                        name: drink.name,
                        color: color,
                        height: 82,
                      ),
                    if (!isAvailable)
                      Positioned.fill(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xDD202827),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              child: Text(
                                'SOLD OUT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                drink.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFD784)
                      : const Color(0xFF196B7A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Rs. ${drink.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: selected ? const Color(0xFF382819) : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustratedCan extends StatelessWidget {
  final String name;
  final Color color;
  final double height;

  const _IllustratedCan({
    required this.name,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final width = height * .49;
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Container(
            height: height * .1,
            width: width * .76,
            decoration: const BoxDecoration(
              color: Color(0xFFD5DADD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
          ),
          Expanded(
            child: Container(
              width: width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(color, Colors.white, .3)!,
                    color,
                    Color.lerp(color, Colors.black, .22)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: height * .08,
            width: width * .8,
            decoration: const BoxDecoration(
              color: Color(0xFFADB6BA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkDetailsPanel extends StatelessWidget {
  final Product drink;
  final Color color;
  final int quantity;
  final VoidCallback onClose;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onAddToCart;

  const _DrinkDetailsPanel({
    super.key,
    required this.drink,
    required this.color,
    required this.quantity,
    required this.onClose,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = drink.price * quantity;
    return Material(
      elevation: 18,
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close drink details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: drink.imageUrl.isNotEmpty
                      ? ProductThumbnail(
                          imageUrl: drink.imageUrl,
                          size: 150,
                          fallbackIcon: Icons.local_drink_outlined,
                        )
                      : _IllustratedCan(
                          name: drink.name,
                          color: color,
                          height: 150,
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                drink.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (drink.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  drink.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 7),
              Text(
                'Rs. ${drink.price.toStringAsFixed(0)} each',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Decrease quantity',
                    onPressed: quantity > 1 ? onDecrease : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Increase quantity',
                    onPressed: quantity < 20 && quantity < drink.stock
                        ? onIncrease
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Total  Rs. ${total.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Add to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
