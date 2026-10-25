import 'package:intl/intl.dart';

String formatOrderPlacedAt(String? value) {
  final createdAt = DateTime.tryParse(value ?? '')?.toLocal();
  if (createdAt == null) return 'Time unavailable';
  return DateFormat('d MMM yyyy · h:mm a').format(createdAt);
}
