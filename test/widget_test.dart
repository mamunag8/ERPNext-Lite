import 'package:erpnext_mobile_app/core/models/user_session.dart';
import 'package:erpnext_mobile_app/core/network/api_client.dart';
import 'package:erpnext_mobile_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NexERP Mobile Core & Auth Tests', () {
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

    testWidgets('renders LoginScreen with DIBL preset and permanent notice', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('NexERP Mobile'), findsOneWidget);
      expect(find.textContaining('1st-Time Permanent Setup'), findsOneWidget);
      expect(find.text('DIBL Server (erp.dripirrigation.bd)'), findsOneWidget);
      expect(find.text('Sign In & Save Permanently'), findsOneWidget);
    });
  });
}
