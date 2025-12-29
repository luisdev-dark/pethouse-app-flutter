import 'package:flutter/material.dart';
import 'package:pethouse/shared/widgets/common_widgets.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleScaffold(
      title: 'Recordatorios',
      body: 'Lista de recordatorios',
    );
  }
}
