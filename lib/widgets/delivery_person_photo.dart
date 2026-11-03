import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DeliveryPersonPhoto extends StatelessWidget {
  const DeliveryPersonPhoto({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.apiBaseUrl,
    required this.authToken,
    this.radius = 24,
    this.backgroundColor,
    this.iconColor,
  });

  final String name;
  final String? avatarUrl;
  final String apiBaseUrl;
  final String? authToken;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;

  String? get _resolvedAvatarUrl {
    final value = avatarUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.toString();
    final baseUri = Uri.parse(apiBaseUrl);
    if (value.startsWith('/account/')) {
      final basePath = baseUri.path.endsWith('/')
          ? baseUri.path.substring(0, baseUri.path.length - 1)
          : baseUri.path;
      return baseUri
          .replace(
            path: '$basePath${uri.path}',
            query: uri.hasQuery ? uri.query : null,
          )
          .toString();
    }
    return baseUri.resolve(value).toString();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvedAvatarUrl;
    final background =
        backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final foreground = iconColor ?? Theme.of(context).colorScheme.primary;
    final fallback = name.trim().isEmpty
        ? Icon(Icons.delivery_dining_rounded, color: foreground)
        : Text(
            name.trim().substring(0, 1).toUpperCase(),
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          );
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: imageUrl == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: {
                  if (authToken != null && authToken!.isNotEmpty)
                    'Authorization': 'Bearer $authToken',
                },
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 4).round(),
                memCacheHeight: (radius * 4).round(),
                placeholder: (_, __) => Center(child: fallback),
                errorWidget: (_, __, ___) => Center(child: fallback),
              ),
            ),
    );
  }
}
