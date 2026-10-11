import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import 'delivery_panel_screen.dart';

class DeliveryShell extends StatelessWidget {
  const DeliveryShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DeliveryPanelScreen(api: context.read<ApiService>());
  }
}
