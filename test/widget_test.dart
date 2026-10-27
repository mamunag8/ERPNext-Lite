import 'package:erpnext_mobile_app/core/models/user_session.dart';
import 'package:erpnext_mobile_app/core/network/api_client.dart';
import 'package:erpnext_mobile_app/core/services/smart_dashboard_service.dart';
import 'package:erpnext_mobile_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ERPNext Lite Core, Auth & Smart Dashboard Tests', () {
    test('normalizes ERPNext server URLs accurately', () {
      expect(
        ErpApiClient.normalizeServerUrl('erp.dripirrigation.bd/'),
        'https://erp.dripirrigation.bd',
      );
      expect(
        ErpApiClient.normalizeServerUrl('https://erp.dripirrigation.bd/app'),
        'https://erp.dripirrigation.bd',
      );
      expect(
        ErpApiClient.normalizeServerUrl('https://client.erpnext.com///'),
        'https://client.erpnext.com',
      );
    });

    test('serializes and restores UserSession permanently', () {
      const UserSession original = UserSession(
        serverUrl: 'https://erp.dripirrigation.bd',
        username: 'cfo@dripirrigation.com.bd',
        fullName: 'CFO DIBL',
        email: 'cfo@dripirrigation.com.bd',
        authType: 'password',
        employeeId: 'HR-EMP-00001',
        employeeName: 'CFO DIBL',
        company: 'Drip Irrigation BD Ltd',
        currency: 'BDT',
        roles: <String>['System Manager', 'Expense Approver'],
        hasFcrm: true,
        isDiblCustomized: true,
      );

      final String encoded = original.toEncodedJson();
      final UserSession restored = UserSession.fromEncodedJson(encoded);

      expect(restored.serverUrl, 'https://erp.dripirrigation.bd');
      expect(restored.employeeId, 'HR-EMP-00001');
      expect(restored.currencySymbol, '৳');
      expect(restored.isApprover, isTrue);
      expect(restored.hasFcrm, isTrue);
      expect(restored.isDiblCustomized, isTrue);
    });

    test(
      'SmartDashboardService ranks frequently used and pinned items higher',
      () async {
        final SmartDashboardService smart = SmartDashboardService.instance;
        await smart.resetUserStats();

        const SmartDashboardItemSpec itemA = SmartDashboardItemSpec(
          id: 'mod_todo',
          title: 'Quick ToDo',
          primaryDocType: 'ToDo',
          defaultOrder: 0,
          alwaysAvailable: true,
        );
        const SmartDashboardItemSpec itemB = SmartDashboardItemSpec(
          id: 'mod_projects',
          title: 'Projects & Stock',
          primaryDocType: 'Project',
          defaultOrder: 6,
          alwaysAvailable: true,
        );

        await smart.recordItemTap('mod_projects', primaryDocType: 'Project');
        await smart.recordItemTap('mod_projects', primaryDocType: 'Project');

        final List<SmartDashboardItemSpec> sorted = smart
            .filterAndSort<SmartDashboardItemSpec>(<SmartDashboardItemSpec>[
              itemA,
              itemB,
            ], (SmartDashboardItemSpec s) => s);
        expect(sorted.first.id, 'mod_projects');
      },
    );

    testWidgets('renders LoginScreen with ERPNext Lite branding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('ERPNext Lite'), findsOneWidget);
      expect(find.textContaining('1st-Time Permanent Setup'), findsOneWidget);
      expect(find.text('DIBL Server (erp.dripirrigation.bd)'), findsOneWidget);
      expect(find.text('Sign In & Save Permanently'), findsOneWidget);
    });
  });
}
