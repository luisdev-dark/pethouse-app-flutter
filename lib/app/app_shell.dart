import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pethouse/features/health/ui/health_tab_page.dart';
import 'package:pethouse/features/home/ui/home_tab_page.dart';
import 'package:pethouse/features/journal/ui/journal_tab_page.dart';
import 'package:pethouse/features/pets/ui/profile_tab_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const <Widget>[
    HomeTabPage(),
    JournalTabPage(),
    HealthTabPage(),
    ProfileTabPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Diario',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Salud',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Acción rápida'),
      ),
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Entrada de diario'),
                onTap: () {
                  context.pop();
                  context.push('/journal/new');
                },
              ),
              ListTile(
                leading: const Icon(Icons.vaccines),
                title: const Text('Registrar vacuna'),
                onTap: () {
                  context.pop();
                  context.push('/health/vaccine/new');
                },
              ),
              ListTile(
                leading: const Icon(Icons.medication),
                title: const Text('Registrar medicación'),
                onTap: () {
                  context.pop();
                  context.push('/health/med/new');
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_weight),
                title: const Text('Registrar peso'),
                onTap: () {
                  context.pop();
                  context.push('/weight/new');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
