import 'package:flutter/material.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _vaccineNotifs = true;
  bool _medsNotifs = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SectionTitle(title: 'Notificaciones'),
          ),
          SwitchListTile(
            title: const Text('Habilitar notificaciones'),
            subtitle: const Text('Activar o desactivar todas las alertas'),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
            },
          ),
          if (_notificationsEnabled) ...[
            SwitchListTile(
              title: const Text('Vacunas'),
              value: _vaccineNotifs,
              onChanged: (val) => setState(() => _vaccineNotifs = val),
            ),
            SwitchListTile(
              title: const Text('Medicaciones'),
              value: _medsNotifs,
              onChanged: (val) => setState(() => _medsNotifs = val),
            ),
          ],
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SectionTitle(title: 'Datos'),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Copia de seguridad local'),
            subtitle: const Text('Próximamente'),
            onTap: () {},
            enabled: false,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SectionTitle(title: 'Apariencia'),
          ),
          SwitchListTile(
            title: const Text('Modo oscuro'),
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
            },
          ),
        ],
      ),
    );
  }
}
