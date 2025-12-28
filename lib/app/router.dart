import 'package:flutter/material.dart';
import 'package:pethouse/app/app_shell.dart';
import 'package:pethouse/app/pages/app_pages.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AppShell();
      },
    ),
    GoRoute(
      path: '/onboarding',
      builder: (BuildContext context, GoRouterState state) {
        return const WelcomePage();
      },
    ),
    GoRoute(
      path: '/pets/select',
      builder: (BuildContext context, GoRouterState state) {
        return const PetSelectPage();
      },
    ),
    GoRoute(
      path: '/pets/new',
      builder: (BuildContext context, GoRouterState state) {
        return const PetNewPage();
      },
    ),
    GoRoute(
      path: '/permissions',
      builder: (BuildContext context, GoRouterState state) {
        return const PermissionsPage();
      },
    ),
    GoRoute(
      path: '/journal/new',
      builder: (BuildContext context, GoRouterState state) {
        return const JournalNewPage();
      },
    ),
    GoRoute(
      path: '/journal/:id',
      builder: (BuildContext context, GoRouterState state) {
        final idParam = state.pathParameters['id'];
        final id = int.tryParse(idParam ?? '');
        return JournalDetailPage(entryId: id);
      },
    ),
    GoRoute(
      path: '/journal/:id/edit',
      builder: (BuildContext context, GoRouterState state) {
        final idParam = state.pathParameters['id'];
        final id = int.tryParse(idParam ?? '');
        if (id == null) {
          return const Scaffold(
            body: Center(child: Text('Entrada no encontrada')),
          );
        }
        return JournalEditPage(entryId: id);
      },
    ),
    GoRoute(
      path: '/health/vaccine/new',
      builder: (BuildContext context, GoRouterState state) {
        return const HealthVaccineNewPage();
      },
    ),
    GoRoute(
      path: '/health/med/new',
      builder: (BuildContext context, GoRouterState state) {
        return const HealthMedicationNewPage();
      },
    ),
    GoRoute(
      path: '/weight/new',
      builder: (BuildContext context, GoRouterState state) {
        return const WeightNewPage();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsPage();
      },
    ),
    GoRoute(
      path: '/reminders',
      builder: (BuildContext context, GoRouterState state) {
        return const RemindersPage();
      },
    ),
  ],
);
