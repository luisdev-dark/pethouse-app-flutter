import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Bienvenido a PetHouse',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Registra la vida de tu mascota',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 140,
                child: PageView(
                  children: const [
                    OnboardingCard(
                      title: 'Diario rapido',
                      body: 'Registra momentos especiales en segundos.',
                    ),
                    OnboardingCard(
                      title: 'Vacunas al dia',
                      body: 'No pierdas ninguna fecha importante.',
                    ),
                    OnboardingCard(
                      title: 'Alertas utiles',
                      body: 'Recordatorios para peso y medicaciones.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/pets/new'),
                  child: const Text('Crear perfil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
