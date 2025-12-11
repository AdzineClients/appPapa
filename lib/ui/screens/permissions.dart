import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _notificationsEnabled = false;
  bool _checkingInitial = true; // just to disable the switch on first load

  @override
  void initState() {
    super.initState();
    _loadInitialStatus();
  }

  Future<void> _loadInitialStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
      _checkingInitial = false;
    });
  }

  Future<void> _onToggleNotification(bool value) async {
    if (value) {
      // Request permission
      final status = await Permission.notification.request();
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    } else {
      // Can't directly revoke; send user to system settings.
      await openAppSettings();
      final status = await Permission.notification.status;
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Permissions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55), // 👈 strength of dark overlay
              BlendMode.darken,               // or BlendMode.srcATop / overlay
            ),
          ),
        ),

        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildNotificationCard(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(bool isDark) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final cardBg = isDark
        ? const Color(0xFF05070B).withOpacity(0.9)
        : Colors.black.withOpacity(0.04);

    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    return Container(
      height: 110, // 👈 fixed height so it doesn’t stretch
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allow important alerts,\nreminders and updates.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _notificationsEnabled,
            onChanged: _checkingInitial ? null : _onToggleNotification,
          ),
        ],
      ),
    );
  }
}
