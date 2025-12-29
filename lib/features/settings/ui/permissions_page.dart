import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/shared/services/notification_service.dart';
import 'package:pethouse/shared/services/permission_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();

  bool _notificationsEnabled = false;
  bool _photosEnabled = false;
  bool _requesting = false;

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _requesting = true;
    });
    final granted = await _permissionService.requestNotifications();
    if (granted) {
      await _notificationService.initialize();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = granted && value;
      _requesting = false;
    });
  }

  Future<void> _togglePhotos(bool value) async {
    setState(() {
      _requesting = true;
    });
    final granted = await _permissionService.requestPhotos();
    if (!mounted) {
      return;
    }
    setState(() {
      _photosEnabled = granted && value;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permisos')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _notificationsEnabled,
            onChanged: _requesting ? null : _toggleNotifications,
            title: const Text('Notificaciones'),
            subtitle: const Text('Recibe recordatorios y avisos.'),
          ),
          SwitchListTile(
            value: _photosEnabled,
            onChanged: _requesting ? null : _togglePhotos,
            title: const Text('Fotos'),
            subtitle: const Text('Acceso a la galeria para fotos de mascotas.'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requesting ? null : () => context.go('/'),
            child: const Text('Continuar'),
          ),
        ),
      ),
    );
  }
}
