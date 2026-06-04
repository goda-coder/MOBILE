import 'package:flutter/material.dart';

import '../theme/colors.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Real-time updates about your wallet activity.',
                style: TextStyle(color: AppColors.ink400)),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: const [
                _Dot(color: AppColors.ink400),
                SizedBox(width: 10),
                Expanded(child: Text('Disconnected',
                    style: TextStyle(color: AppColors.ink300))),
              ]),
            )),
            const SizedBox(height: 12),
            Card(child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.ink800, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none,
                      color: AppColors.ink400, size: 20),
                ),
                const SizedBox(height: 12),
                const Text('No notifications yet.',
                    style: TextStyle(color: AppColors.ink400, fontSize: 13)),
                const SizedBox(height: 6),
                const Text(
                  "The realtime channel appears here once the SignalR hub is wired up on the backend.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.ink500, fontSize: 12),
                ),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
