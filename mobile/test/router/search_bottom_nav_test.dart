// ABOUTME: Tests that search screen shows bottom navigation bar
// ABOUTME: Verifies bottom nav is visible on search route (not hidden like camera/settings)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/app_shell.dart';

void main() {
  group('Search route bottom navigation', () {
    testWidgets('bottom navigation bar is visible on search route', (tester) async {
      final router = createRouter();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to search
      router.go('/search');
      await tester.pumpAndSettle();

      // Bottom navigation bar should be visible
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Verify we can see the navigation items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('no tab is highlighted on search route', (tester) async {
      final router = createRouter();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to search
      router.go('/search');
      await tester.pumpAndSettle();

      // Find the BottomNavigationBar widget
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );

      // No tab should be selected (currentIndex should allow no selection)
      // We verify this by checking that currentIndex is not 0-3
      expect(bottomNav.currentIndex < 0 || bottomNav.currentIndex > 3, isTrue);
    });
  });
}
