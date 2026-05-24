import 'package:flutter/material.dart';

import '../../core/realtime/realtime_service.dart';
import '../../core/theme/app_theme.dart';

class RealtimeStatusChip extends StatelessWidget {
  const RealtimeStatusChip({super.key, required this.realtime});

  final RealtimeService realtime;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: realtime,
      builder: (context, _) {
        final connected = realtime.isConnected;
        final connecting = realtime.isConnecting;
        final label = connected
            ? 'Realtime'
            : connecting
                ? 'Đang nối'
                : 'Offline';
        final icon = connected
            ? Icons.bolt
            : connecting
                ? Icons.sync
                : Icons.cloud_off_outlined;
        return Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(icon,
              size: 16, color: connected ? AppColors.accent : AppColors.muted),
          label: Text(label),
        );
      },
    );
  }
}
