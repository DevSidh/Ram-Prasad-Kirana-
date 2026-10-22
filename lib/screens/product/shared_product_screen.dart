import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/api_service.dart';
import 'product_details_screen.dart';

class SharedProductScreen extends StatefulWidget {
  const SharedProductScreen({super.key, required this.productId});

  final String productId;

  @override
  State<SharedProductScreen> createState() => _SharedProductScreenState();
}

class _SharedProductScreenState extends State<SharedProductScreen> {
  Product? _product;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProduct());
  }

  Future<void> _loadProduct() async {
    try {
      final response = await context
          .read<ApiService>()
          .get('/products/${Uri.encodeComponent(widget.productId)}');
      if (response is! Map<String, dynamic> ||
          response['data'] is! Map<String, dynamic>) {
        throw const FormatException('The shared product link is invalid.');
      }
      final product =
          Product.fromJson(response['data'] as Map<String, dynamic>);
      if (product.id.isEmpty) {
        throw const FormatException('The shared product could not be found.');
      }
      if (!mounted) return;
      setState(() {
        _product = product;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final product = _product;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (product != null) return ProductDetailsScreen(product: product);
    return Scaffold(
      appBar: AppBar(title: const Text('Shared product')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded, size: 42),
              const SizedBox(height: 12),
              Text(
                _error ?? 'This product is no longer available.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  unawaited(_loadProduct());
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
