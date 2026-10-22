import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class ErpApiClient extends ChangeNotifier {
  ErpApiClient._internal();
  static final ErpApiClient instance = ErpApiClient._internal();

  static const String _keySessionJson = 'nexerp_user_session_v1';
  static const String _keyPassword = 'nexerp_secret_password_v1';
  static const String _keyApiKey = 'nexerp_api_key_v1';
  static const String _keyApiSecret = 'nexerp_api_secret_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late Dio _dio;
  PersistCookieJar? _cookieJar;
  UserSession? _session;
  bool _isInitialized = false;
  bool _isReauthenticating = false;

  UserSession? get session => _session;
  bool get isLoggedIn => _session != null && _session!.serverUrl.isNotEmpty;
  bool get isInitialized => _isInitialized;

  static String normalizeServerUrl(String rawUrl) {
    String url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/app')) {
      url = url.substring(0, url.length - 4);
    }
    return url;
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String cookiePath = '${appDocDir.path}/.cookies/';
    _cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookiePath),
    );

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 35),
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar!));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              if (_session != null) {
                options.baseUrl = _session!.serverUrl;
                if (_session!.authType == 'api_key') {
                  final String? apiKey = await _secureStorage.read(
                    key: _keyApiKey,
                  );
                  final String? apiSecret = await _secureStorage.read(
                    key: _keyApiSecret,
                  );
                  if (apiKey != null &&
                      apiSecret != null &&
                      apiKey.isNotEmpty &&
                      apiSecret.isNotEmpty) {
                    options.headers['Authorization'] =
                        'token $apiKey:$apiSecret';
                  }
                }
              }
              handler.next(options);
            },
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          final int? status = err.response?.statusCode;
          final bool isAuthError = status == 401 || status == 403;
          final bool isLoginCall = err.requestOptions.path.contains(
            '/api/method/login',
          );

          if (isAuthError &&
              !isLoginCall &&
              !_isReauthenticating &&
              _session != null &&
              _session!.authType == 'password') {
            final bool renewed = await _silentReauthenticate();
            if (renewed) {
              try {
                final Response<dynamic> retryResponse = await _dio.fetch(
                  err.requestOptions,
                );
                return handler.resolve(retryResponse);
              } on DioException catch (retryErr) {
                return handler.next(retryErr);
              }
            }
          }
          handler.next(err);
        },
      ),
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString(_keySessionJson);
    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        _session = UserSession.fromEncodedJson(savedJson);
        _dio.options.baseUrl = _session!.serverUrl;
      } catch (_) {
        _session = null;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> _silentReauthenticate() async {
    if (_session == null || _isReauthenticating) {
      return false;
    }
    _isReauthenticating = true;
    try {
      final String? savedPassword = await _secureStorage.read(
        key: _keyPassword,
      );
      if (savedPassword == null || savedPassword.isEmpty) {
        return false;
      }
      final Response<dynamic> res = await _dio.post<dynamic>(
        '${_session!.serverUrl}/api/method/login',
        data: <String, dynamic>{
          'usr': _session!.username,
          'pwd': savedPassword,
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      _isReauthenticating = false;
    }
  }

  bool get _isDemoSession =>
      _session != null &&
      _session!.username.trim().toLowerCase() == 'demo@kasbpro.com';

  Future<UserSession> loginWithPassword({
    required String rawServerUrl,
    required String username,
    required String password,
  }) async {
    final String serverUrl = normalizeServerUrl(rawServerUrl);
    if (serverUrl.isEmpty) {
      throw Exception('Please enter a valid ERPNext Server URL.');
    }

    if (username.trim().toLowerCase() == 'demo@kasbpro.com' &&
        password.trim() == 'DemoUser@2026') {
      final UserSession demoSession = UserSession(
        serverUrl: serverUrl,
        username: 'demo@kasbpro.com',
        fullName: 'Google Play Reviewer',
        email: 'demo@kasbpro.com',
        authType: 'password',
        employeeId: 'HR-EMP-00001',
        employeeName: 'Google Play Reviewer',
        designation: 'Senior Operations Manager',
        department: 'Operations - DIBL',
        company: 'Drip Irrigation BD Ltd',
        currency: 'BDT',
        branch: 'Dhaka HQ',
        costCenter: 'Main - DIBL',
        expenseApprover: 'hr@dripirrigation.bd',
        leaveApprover: 'hr@dripirrigation.bd',
        roles: const <String>[
          'Employee',
          'Sales User',
          'Sales Manager',
          'HR User',
          'Projects User',
          'Stock User',
        ],
        hasFcrm: true,
        isDiblCustomized: true,
        departments: const <String>[
          'Operations - DIBL',
          'Sales & Marketing - DIBL',
          'Engineering & Projects - DIBL',
          'Accounts & Finance - DIBL',
        ],
        costCenters: const <String>['Main - DIBL', 'Projects - DIBL'],
        projects: const <String>['PROJ-0001', 'PROJ-0002', 'PROJ-0003'],
        warehouses: const <String>['Central Store - DIBL', 'Site Store - DIBL'],
      );
      await _saveSession(demoSession);
      return demoSession;
    }

    _dio.options.baseUrl = serverUrl;
    await _cookieJar?.deleteAll();

    final Response<dynamic> loginRes = await _dio.post<dynamic>(
      '$serverUrl/api/method/login',
      data: <String, dynamic>{'usr': username.trim(), 'pwd': password},
    );

    if (loginRes.statusCode != 200) {
      throw Exception('Login failed (${loginRes.statusCode}).');
    }

    await _secureStorage.write(key: _keyPassword, value: password);
    final Map<String, dynamic> body =
        (loginRes.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String fullName = (body['full_name'] ?? username).toString();

    final UserSession builtSession = await _hydrateUserSession(
      serverUrl: serverUrl,
      username: username.trim(),
      fullName: fullName,
      authType: 'password',
    );

    await _saveSession(builtSession);
    return builtSession;
  }

  Future<UserSession> loginWithApiKey({
    required String rawServerUrl,
    required String apiKey,
    required String apiSecret,
  }) async {
    final String serverUrl = normalizeServerUrl(rawServerUrl);
    if (serverUrl.isEmpty) {
      throw Exception('Please enter a valid ERPNext Server URL.');
    }

    _dio.options.baseUrl = serverUrl;
    await _secureStorage.write(key: _keyApiKey, value: apiKey.trim());
    await _secureStorage.write(key: _keyApiSecret, value: apiSecret.trim());

    final Response<dynamic> userRes = await _dio.get<dynamic>(
      '$serverUrl/api/method/frappe.auth.get_logged_user',
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'token ${apiKey.trim()}:${apiSecret.trim()}',
        },
      ),
    );

    final Map<String, dynamic> data =
        (userRes.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String loggedUser = (data['message'] ?? '').toString();
    if (loggedUser.isEmpty) {
      throw Exception('Invalid API Key or Secret.');
    }

    final UserSession builtSession = await _hydrateUserSession(
      serverUrl: serverUrl,
      username: loggedUser,
      fullName: loggedUser,
      authType: 'api_key',
    );

    await _saveSession(builtSession);
    return builtSession;
  }

  Future<UserSession> _hydrateUserSession({
    required String serverUrl,
    required String username,
    required String fullName,
    required String authType,
  }) async {
    String resolvedEmail = username;
    String resolvedFullName = fullName;
    List<String> roles = <String>[];

    try {
      final Response<dynamic> loggedRes = await _dio.get<dynamic>(
        '$serverUrl/api/method/frappe.auth.get_logged_user',
      );
      final Map<String, dynamic> loggedMap =
          (loggedRes.data as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (loggedMap['message'] != null) {
        resolvedEmail = loggedMap['message'].toString();
      }
    } catch (_) {}

    try {
      final Map<String, dynamic> userDoc = await getDoc('User', resolvedEmail);
      resolvedFullName = (userDoc['full_name'] ?? resolvedFullName).toString();
      final List<dynamic>? roleRows = userDoc['roles'] as List<dynamic>?;
      if (roleRows != null) {
        roles = roleRows
            .map(
              (dynamic r) =>
                  ((r as Map<String, dynamic>)['role'] ?? '').toString(),
            )
            .where((String s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    String employeeId = '';
    String employeeName = resolvedFullName;
    String designation = '';
    String department = '';
    String company = 'Drip Irrigation BD Ltd';
    String currency = 'BDT';
    String branch = '';
    String costCenter = '';
    String expenseApprover = '';
    String leaveApprover = '';

    try {
      final List<Map<String, dynamic>> employees = await getList(
        'Employee',
        fields: <String>[
          'name',
          'employee_name',
          'designation',
          'department',
          'company',
          'branch',
          'payroll_cost_center',
          'expense_approver',
          'leave_approver',
        ],
        filters: <String, dynamic>{'user_id': resolvedEmail},
        limitPageLength: 1,
      );
      if (employees.isNotEmpty) {
        final Map<String, dynamic> emp = employees.first;
        employeeId = (emp['name'] ?? '').toString();
        employeeName = (emp['employee_name'] ?? resolvedFullName).toString();
        designation = (emp['designation'] ?? '').toString();
        department = (emp['department'] ?? '').toString();
        company = (emp['company'] ?? company).toString();
        branch = (emp['branch'] ?? '').toString();
        costCenter = (emp['payroll_cost_center'] ?? '').toString();
        expenseApprover = (emp['expense_approver'] ?? '').toString();
        leaveApprover = (emp['leave_approver'] ?? '').toString();
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> companies = await getList(
        'Company',
        fields: <String>['name', 'default_currency'],
        limitPageLength: 5,
      );
      if (companies.isNotEmpty) {
        final Map<String, dynamic> comp = companies.firstWhere(
          (Map<String, dynamic> c) => c['name'] == company,
          orElse: () => companies.first,
        );
        company = (comp['name'] ?? company).toString();
        currency = (comp['default_currency'] ?? currency).toString();
      }
    } catch (_) {}

    bool hasFcrm = false;
    try {
      await getList('CRM Lead', fields: <String>['name'], limitPageLength: 1);
      hasFcrm = true;
    } catch (_) {
      hasFcrm = false;
    }

    final bool isDibl =
        serverUrl.contains('dripirrigation') ||
        company.toLowerCase().contains('drip irrigation');

    List<String> departments = <String>[];
    try {
      final List<Map<String, dynamic>> deptRows = await getList(
        'Department',
        fields: <String>['name', 'department_name'],
        filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
        limitPageLength: 50,
      );
      departments = deptRows
          .map((Map<String, dynamic> d) => (d['name'] ?? '').toString())
          .where((String s) => s.isNotEmpty)
          .toList();
    } catch (_) {}

    List<String> costCenters = <String>[];
    try {
      final List<Map<String, dynamic>> ccRows = await getList(
        'Cost Center',
        fields: <String>['name'],
        filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
        limitPageLength: 50,
      );
      costCenters = ccRows
          .map((Map<String, dynamic> c) => (c['name'] ?? '').toString())
          .where((String s) => s.isNotEmpty)
          .toList();
    } catch (_) {}

    List<String> projects = <String>[];
    try {
      final List<Map<String, dynamic>> projRows = await getList(
        'Project',
        fields: <String>['name', 'project_name'],
        limitPageLength: 100,
      );
      projects = projRows
          .map((Map<String, dynamic> p) => (p['name'] ?? '').toString())
          .where((String s) => s.isNotEmpty)
          .toList();
    } catch (_) {}

    List<String> warehouses = <String>[];
    try {
      final List<Map<String, dynamic>> whRows = await getList(
        'Warehouse',
        fields: <String>['name'],
        filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
        limitPageLength: 50,
      );
      warehouses = whRows
          .map((Map<String, dynamic> w) => (w['name'] ?? '').toString())
          .where((String s) => s.isNotEmpty)
          .toList();
    } catch (_) {}

    return UserSession(
      serverUrl: serverUrl,
      username: username,
      fullName: resolvedFullName,
      email: resolvedEmail,
      authType: authType,
      employeeId: employeeId,
      employeeName: employeeName,
      designation: designation,
      department: department,
      company: company,
      currency: currency,
      branch: branch,
      costCenter: costCenter,
      expenseApprover: expenseApprover,
      leaveApprover: leaveApprover,
      roles: roles,
      hasFcrm: hasFcrm,
      isDiblCustomized: isDibl,
      departments: departments,
      costCenters: costCenters,
      projects: projects,
      warehouses: warehouses,
    );
  }

  Future<void> refreshSessionMetadata() async {
    if (_session == null || _isDemoSession) {
      return;
    }
    final UserSession updated = await _hydrateUserSession(
      serverUrl: _session!.serverUrl,
      username: _session!.username,
      fullName: _session!.fullName,
      authType: _session!.authType,
    );
    await _saveSession(updated);
  }

  Future<void> _saveSession(UserSession newSession) async {
    _session = newSession;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionJson, newSession.toEncodedJson());
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (_session != null && !_isDemoSession) {
        await _dio.get<dynamic>('${_session!.serverUrl}/api/method/logout');
      }
    } catch (_) {}
    await _cookieJar?.deleteAll();
    await _secureStorage.deleteAll();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionJson);
    _session = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> _getDemoList(String doctype) {
    switch (doctype) {
      case 'Employee':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'designation': 'Senior Operations Manager',
            'branch': 'Dhaka HQ',
            'status': 'Active',
            'company': 'Drip Irrigation BD Ltd',
          },
          <String, dynamic>{
            'name': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'department': 'Engineering & Projects - DIBL',
            'designation': 'Project Engineer',
            'branch': 'Gazipur Site',
            'status': 'Active',
            'company': 'Drip Irrigation BD Ltd',
          },
          <String, dynamic>{
            'name': 'HR-EMP-00003',
            'employee_name': 'Farhana Akter',
            'department': 'Accounts & Finance - DIBL',
            'designation': 'Accounts Officer',
            'branch': 'Dhaka HQ',
            'status': 'Active',
            'company': 'Drip Irrigation BD Ltd',
          },
          <String, dynamic>{
            'name': 'HR-EMP-00004',
            'employee_name': 'Tanvir Ahmed',
            'department': 'Sales & Marketing - DIBL',
            'designation': 'Regional Sales Executive',
            'branch': 'Rajshahi Zone',
            'status': 'Active',
            'company': 'Drip Irrigation BD Ltd',
          },
        ];
      case 'Employee Checkin':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'EMP-CKIN-2026-00101',
            'employee_name': 'Google Play Reviewer',
            'log_type': 'IN',
            'time': '2026-10-18 09:02:15',
            'device_id': '23.8103,90.4125 (Mobile)',
          },
          <String, dynamic>{
            'name': 'EMP-CKIN-2026-00098',
            'employee_name': 'Google Play Reviewer',
            'log_type': 'OUT',
            'time': '2026-10-17 18:10:42',
            'device_id': '23.8103,90.4125 (Mobile)',
          },
        ];
      case 'Attendance':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-ATT-2026-00412',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'attendance_date': '2026-10-17',
            'status': 'Present',
            'shift': 'General Shift',
            'late_entry': 0,
            'early_exit': 0,
          },
          <String, dynamic>{
            'name': 'HR-ATT-2026-00411',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'attendance_date': '2026-10-16',
            'status': 'Present',
            'shift': 'General Shift',
            'late_entry': 0,
            'early_exit': 0,
          },
          <String, dynamic>{
            'name': 'HR-ATT-2026-00410',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'department': 'Engineering & Projects - DIBL',
            'attendance_date': '2026-10-17',
            'status': 'Present',
            'shift': 'General Shift',
            'late_entry': 1,
            'early_exit': 0,
          },
          <String, dynamic>{
            'name': 'HR-ATT-2026-00409',
            'employee': 'HR-EMP-00003',
            'employee_name': 'Farhana Akter',
            'department': 'Accounts & Finance - DIBL',
            'attendance_date': '2026-10-17',
            'status': 'On Leave',
            'shift': 'General Shift',
            'late_entry': 0,
            'early_exit': 0,
          },
        ];
      case 'Shift Request':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-SHT-2026-00018',
            'employee_name': 'Google Play Reviewer',
            'shift_type': 'Morning Field Shift',
            'from_date': '2026-10-20',
            'to_date': '2026-10-25',
            'status': 'Approved',
          },
        ];
      case 'Leave Allocation':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-LAL-2026-00001',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'leave_type': 'Casual Leave',
            'total_leaves_allocated': 14,
            'from_date': '2026-01-01',
            'to_date': '2026-12-31',
          },
          <String, dynamic>{
            'name': 'HR-LAL-2026-00002',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'leave_type': 'Sick Leave',
            'total_leaves_allocated': 14,
            'from_date': '2026-01-01',
            'to_date': '2026-12-31',
          },
          <String, dynamic>{
            'name': 'HR-LAL-2026-00003',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'leave_type': 'Earned Leave',
            'total_leaves_allocated': 18,
            'from_date': '2026-01-01',
            'to_date': '2026-12-31',
          },
        ];
      case 'Leave Application':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-LAP-2026-00045',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'leave_type': 'Casual Leave',
            'from_date': '2026-10-28',
            'to_date': '2026-10-29',
            'total_leave_days': 2,
            'status': 'Approved',
            'description': 'Family event in Rajshahi',
          },
          <String, dynamic>{
            'name': 'HR-LAP-2026-00046',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'leave_type': 'Sick Leave',
            'from_date': '2026-10-24',
            'to_date': '2026-10-25',
            'total_leave_days': 2,
            'status': 'Open',
            'description': 'Medical checkup & rest',
          },
        ];
      case 'Expense Claim':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-EXP-2026-00089',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'posting_date': '2026-10-16',
            'project': 'PROJ-0001',
            'cost_center': 'Main - DIBL',
            'total_claimed_amount': 4500,
            'total_sanctioned_amount': 4500,
            'total_amount_reimbursed': 4500,
            'approval_status': 'Approved',
            'status': 'Paid',
          },
          <String, dynamic>{
            'name': 'HR-EXP-2026-00092',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'posting_date': '2026-10-18',
            'project': 'PROJ-0001',
            'cost_center': 'Projects - DIBL',
            'total_claimed_amount': 3200,
            'total_sanctioned_amount': 3200,
            'total_amount_reimbursed': 0,
            'approval_status': 'Draft',
            'status': 'Draft',
          },
        ];
      case 'Employee Advance':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-EAD-2026-00112',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'posting_date': '2026-10-15',
            'project': 'PROJ-0001',
            'advance_amount': 12000,
            'paid_amount': 12000,
            'claimed_amount': 4500,
            'return_amount': 0,
            'pending_amount': 7500,
            'purpose': 'Gazipur Drip Irrigation Site Installation',
            'status': 'Paid',
          },
        ];
      case 'Salary Slip':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sal Slip/HR-EMP-00001/00009',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'designation': 'Senior Operations Manager',
            'salary_structure': 'DIBL Monthly Regular Structure',
            'posting_date': '2026-09-30',
            'start_date': '2026-09-01',
            'end_date': '2026-09-30',
            'gross_pay': 85000,
            'total_deduction': 3500,
            'net_pay': 81500,
            'status': 'Submitted',
            'docstatus': 1,
            'earnings': <Map<String, dynamic>>[
              <String, dynamic>{
                'salary_component': 'Basic Salary',
                'amount': 50000,
              },
              <String, dynamic>{
                'salary_component': 'House Rent Allowance',
                'amount': 25000,
              },
              <String, dynamic>{
                'salary_component': 'Medical & Conveyance',
                'amount': 10000,
              },
            ],
            'deductions': <Map<String, dynamic>>[
              <String, dynamic>{
                'salary_component': 'Income Tax (AIT)',
                'amount': 2500,
              },
              <String, dynamic>{
                'salary_component': 'Provident Fund',
                'amount': 1000,
              },
            ],
          },
          <String, dynamic>{
            'name': 'Sal Slip/HR-EMP-00002/00009',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'department': 'Engineering & Projects - DIBL',
            'designation': 'Project Engineer',
            'salary_structure': 'DIBL Monthly Regular Structure',
            'posting_date': '2026-10-20',
            'start_date': '2026-10-01',
            'end_date': '2026-10-31',
            'gross_pay': 62000,
            'total_deduction': 2000,
            'net_pay': 60000,
            'status': 'Draft',
            'docstatus': 0,
          },
        ];
      case 'Payroll Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'PR-ENT-2026-00010',
            'company': 'Drip Irrigation BD Ltd',
            'posting_date': '2026-10-25',
            'payroll_frequency': 'Monthly',
            'start_date': '2026-10-01',
            'end_date': '2026-10-31',
            'department': 'Operations - DIBL',
            'branch': 'Dhaka HQ',
            'currency': 'BDT',
            'status': 'Submitted',
            'docstatus': 1,
            'salary_slips_created': 1,
            'salary_slips_submitted': 1,
          },
          <String, dynamic>{
            'name': 'PR-ENT-2026-00009',
            'company': 'Drip Irrigation BD Ltd',
            'posting_date': '2026-09-30',
            'payroll_frequency': 'Monthly',
            'start_date': '2026-09-01',
            'end_date': '2026-09-30',
            'department': 'All Departments',
            'branch': 'Dhaka HQ',
            'currency': 'BDT',
            'status': 'Submitted',
            'docstatus': 1,
            'salary_slips_created': 1,
            'salary_slips_submitted': 1,
          },
        ];
      case 'Salary Structure':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'DIBL Monthly Regular Structure',
            'company': 'Drip Irrigation BD Ltd',
            'is_active': 'Yes',
            'payroll_frequency': 'Monthly',
            'currency': 'BDT',
          },
          <String, dynamic>{
            'name': 'Field Engineering & Project Structure',
            'company': 'Drip Irrigation BD Ltd',
            'is_active': 'Yes',
            'payroll_frequency': 'Monthly',
            'currency': 'BDT',
          },
        ];
      case 'Salary Structure Assignment':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-SSA-2026-00001',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'designation': 'Senior Operations Manager',
            'salary_structure': 'DIBL Monthly Regular Structure',
            'from_date': '2026-01-01',
            'base': 85000,
            'variable': 10000,
            'company': 'Drip Irrigation BD Ltd',
            'docstatus': 1,
          },
          <String, dynamic>{
            'name': 'HR-SSA-2026-00002',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'department': 'Engineering & Projects - DIBL',
            'designation': 'Project Engineer',
            'salary_structure': 'Field Engineering & Project Structure',
            'from_date': '2026-01-01',
            'base': 62000,
            'variable': 5000,
            'company': 'Drip Irrigation BD Ltd',
            'docstatus': 1,
          },
        ];
      case 'Additional Salary':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'HR-ADS-2026-00015',
            'employee': 'HR-EMP-00001',
            'employee_name': 'Google Play Reviewer',
            'department': 'Operations - DIBL',
            'salary_component': 'Performance Bonus',
            'type': 'Earning',
            'payroll_date': '2026-10-25',
            'amount': 15000,
            'currency': 'BDT',
            'overwrite_salary_structure_amount': 0,
            'docstatus': 1,
          },
          <String, dynamic>{
            'name': 'HR-ADS-2026-00016',
            'employee': 'HR-EMP-00002',
            'employee_name': 'Engr. Mahmudul Hasan',
            'department': 'Engineering & Projects - DIBL',
            'salary_component': 'Project Site Overtime Allowance',
            'type': 'Earning',
            'payroll_date': '2026-10-25',
            'amount': 6500,
            'currency': 'BDT',
            'overwrite_salary_structure_amount': 0,
            'docstatus': 1,
          },
        ];
      case 'Salary Component':
        return <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Performance Bonus', 'type': 'Earning'},
          <String, dynamic>{
            'name': 'Project Site Overtime Allowance',
            'type': 'Earning',
          },
          <String, dynamic>{'name': 'Festival Bonus', 'type': 'Earning'},
          <String, dynamic>{
            'name': 'Mobile & Internet Allowance',
            'type': 'Earning',
          },
          <String, dynamic>{'name': 'Arrear Salary', 'type': 'Earning'},
          <String, dynamic>{
            'name': 'Advance Salary Deduction',
            'type': 'Deduction',
          },
          <String, dynamic>{
            'name': 'Late Attendance Deduction',
            'type': 'Deduction',
          },
        ];
      case 'Sales Invoice':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-SINV-2026-00321',
            'customer_name': 'Green Valley Agro Farms Ltd',
            'posting_date': '2026-10-17',
            'grand_total': 145000,
            'outstanding_amount': 0,
            'status': 'Paid',
          },
          <String, dynamic>{
            'name': 'ACC-SINV-2026-00319',
            'customer_name': 'Barind Orchard Project',
            'posting_date': '2026-10-15',
            'grand_total': 88500,
            'outstanding_amount': 28500,
            'status': 'Partly Paid',
          },
        ];
      case 'Sales Order':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'SAL-ORD-2026-00210',
            'customer_name': 'Green Valley Agro Farms Ltd',
            'transaction_date': '2026-10-16',
            'grand_total': 145000,
            'status': 'Completed',
          },
        ];
      case 'Quotation':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'SAL-QTN-2026-00155',
            'party_name': 'Rangpur Tea Estate',
            'transaction_date': '2026-10-17',
            'grand_total': 210000,
            'status': 'Open',
          },
        ];
      case 'Payment Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-PAY-2026-00402',
            'party_name': 'Green Valley Agro Farms Ltd',
            'posting_date': '2026-10-17',
            'paid_amount': 145000,
            'payment_type': 'Receive',
            'status': 'Submitted',
          },
        ];
      case 'CRM Lead':
      case 'Lead':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'CRM-LEAD-2026-00077',
            'lead_name': 'Md. Rafiqul Islam',
            'first_name': 'Md. Rafiqul',
            'last_name': 'Islam',
            'organization': 'Rajshahi Mango Growers',
            'company_name': 'Rajshahi Mango Growers',
            'mobile_no': '+8801711000000',
            'status': 'Qualified',
          },
        ];
      case 'CRM Deal':
      case 'Opportunity':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'CRM-DEAL-2026-00034',
            'organization': 'Green Valley Agro Farms Ltd',
            'party_name': 'Green Valley Agro Farms Ltd',
            'status': 'Proposal/Price Quote',
            'opportunity_amount': 320000,
          },
        ];
      case 'CRM Task':
      case 'ToDo':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TASK-CRM-0019',
            'title': 'Send 5-Acre Drip Irrigation Layout Proposal',
            'description': 'Send 5-Acre Drip Irrigation Layout Proposal',
            'status': 'Open',
            'priority': 'High',
            'date': '2026-10-19',
          },
        ];
      case 'Project':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'PROJ-0001',
            'project_name': 'Gazipur 10-Acre Smart Greenhouse Irrigation',
            'status': 'Open',
            'percent_complete': 75,
            'expected_end_date': '2026-11-15',
          },
        ];
      case 'Task':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TASK-2026-00051',
            'subject': 'Install Inline Dripper Laterals & Pressure Gauge',
            'project': 'PROJ-0001',
            'status': 'Working',
            'priority': 'High',
            'exp_end_date': '2026-10-22',
          },
        ];
      case 'Timesheet':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TS-2026-00084',
            'employee_name': 'Google Play Reviewer',
            'start_date': '2026-10-17',
            'total_hours': 8.0,
            'status': 'Submitted',
          },
        ];
      case 'Material Request':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'MAT-MR-2026-00063',
            'title': '16mm Inline Drip Lateral Pipe (4000m)',
            'material_request_type': 'Material Issue',
            'transaction_date': '2026-10-17',
            'status': 'Pending',
          },
        ];
      case 'Stock Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'MAT-STE-2026-00129',
            'stock_entry_type': 'Material Issue',
            'posting_date': '2026-10-16',
            'from_warehouse': 'Central Store - DIBL',
            'docstatus': 1,
          },
        ];
      case 'Journal Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-JV-2026-00198',
            'voucher_type': 'Journal Entry',
            'posting_date': '2026-10-17',
            'total_debit': 45000,
            'total_credit': 45000,
            'user_remark': 'Site Office Rent & Utility Adjustment - Gazipur',
            'docstatus': 1,
          },
        ];
      case 'Delivery Note':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'MAT-DN-2026-00091',
            'customer_name': 'Green Valley Agro Farms Ltd',
            'posting_date': '2026-10-17',
            'grand_total': 145000,
            'status': 'Completed',
            'docstatus': 1,
          },
        ];
      case 'Bin':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'BIN-0001',
            'item_code': 'DRIP-16MM-INLINE',
            'warehouse': 'Central Store - DIBL',
            'actual_qty': 12500,
            'projected_qty': 11800,
            'valuation_rate': 14.5,
          },
          <String, dynamic>{
            'name': 'BIN-0002',
            'item_code': 'VENTURI-2INCH',
            'warehouse': 'Dhaka Warehouse - DIBL',
            'actual_qty': 85,
            'projected_qty': 80,
            'valuation_rate': 3200,
          },
        ];
      case 'Item Price':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'IP-0001',
            'item_code': 'DRIP-16MM-INLINE',
            'item_name': '16mm Inline Dripper Pipe',
            'price_list': 'Standard Selling',
            'price_list_rate': 18.0,
            'currency': 'BDT',
          },
        ];
      case 'Purchase Order':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'PUR-ORD-2026-00074',
            'supplier': 'Netafim Irrigation Supplies',
            'supplier_name': 'Netafim Irrigation Supplies',
            'transaction_date': '2026-10-15',
            'grand_total': 480000,
            'status': 'To Receive and Bill',
          },
        ];
      case 'Purchase Receipt':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'MAT-PRE-2026-00052',
            'supplier': 'Netafim Irrigation Supplies',
            'supplier_name': 'Netafim Irrigation Supplies',
            'posting_date': '2026-10-16',
            'grand_total': 480000,
            'status': 'Completed',
          },
        ];
      case 'Purchase Invoice':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-PINV-2026-00061',
            'supplier': 'Netafim Irrigation Supplies',
            'supplier_name': 'Netafim Irrigation Supplies',
            'posting_date': '2026-10-17',
            'grand_total': 480000,
            'outstanding_amount': 120000,
            'status': 'Partly Paid',
          },
        ];
      case 'Supplier':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Netafim Irrigation Supplies',
            'supplier_name': 'Netafim Irrigation Supplies',
            'supplier_group': 'Hardware & Irrigation',
            'country': 'Bangladesh',
          },
        ];
      case 'Asset':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-ASS-2026-00042',
            'asset_name': 'Submersible Solar Pump 5HP',
            'item_code': 'SOLAR-PUMP-5HP',
            'asset_category': 'Field Machinery',
            'location': 'Head Office - Dhaka',
            'status': 'Submitted',
            'gross_purchase_amount': 185000,
          },
        ];
      case 'Asset Movement':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'ACC-ASM-2026-00105',
            'purpose': 'Issue',
            'transaction_date': '2026-10-17',
            'company': 'Drip Irrigation BD Ltd',
            'docstatus': 1,
          },
        ];
      default:
        return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getList(
    String doctype, {
    List<String> fields = const <String>['name'],
    Map<String, dynamic>? filters,
    List<List<dynamic>>? listFilters,
    String orderBy = 'creation desc',
    int limitPageLength = 50,
    int limitStart = 0,
  }) async {
    if (_isDemoSession) {
      return _getDemoList(doctype);
    }

    final Map<String, dynamic> queryParameters = <String, dynamic>{
      'fields': jsonEncode(fields),
      'order_by': orderBy,
      'limit_page_length': limitPageLength,
      'limit_start': limitStart,
    };
    if (listFilters != null && listFilters.isNotEmpty) {
      queryParameters['filters'] = jsonEncode(listFilters);
    } else if (filters != null && filters.isNotEmpty) {
      queryParameters['filters'] = jsonEncode(filters);
    }

    final Response<dynamic> res = await _dio.get<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}',
      queryParameters: queryParameters,
    );

    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> rawList =
        (body['data'] as List<dynamic>?) ?? <dynamic>[];
    return rawList
        .map(
          (dynamic e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
        )
        .toList();
  }

  Future<Map<String, dynamic>> getDoc(String doctype, String name) async {
    if (_isDemoSession) {
      final List<Map<String, dynamic>> list = _getDemoList(doctype);
      return list.firstWhere(
        (Map<String, dynamic> e) => e['name'] == name,
        orElse: () => <String, dynamic>{'name': name, 'doctype': doctype},
      );
    }
    final Response<dynamic> res = await _dio.get<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(name)}',
    );
    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<dynamic, dynamic> data =
        (body['data'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createDoc(
    String doctype,
    Map<String, dynamic> payload,
  ) async {
    if (_isDemoSession) {
      return <String, dynamic>{
        'name': 'DEMO-${DateTime.now().millisecondsSinceEpoch % 10000}',
        ...payload,
      };
    }
    final Response<dynamic> res = await _dio.post<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}',
      data: payload,
    );
    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<dynamic, dynamic> data =
        (body['data'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateDoc(
    String doctype,
    String name,
    Map<String, dynamic> payload,
  ) async {
    if (_isDemoSession) {
      return <String, dynamic>{'name': name, ...payload};
    }
    final Response<dynamic> res = await _dio.put<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(name)}',
      data: payload,
    );
    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<dynamic, dynamic> data =
        (body['data'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    return Map<String, dynamic>.from(data);
  }

  Future<dynamic> callMethod(
    String method, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? data,
    bool isPost = true,
  }) async {
    if (_isDemoSession) {
      return <String, dynamic>{'status': 'ok'};
    }
    final Response<dynamic> res = isPost
        ? await _dio.post<dynamic>(
            '/api/method/$method',
            queryParameters: queryParams,
            data: data,
          )
        : await _dio.get<dynamic>(
            '/api/method/$method',
            queryParameters: queryParams,
          );
    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    return body['message'];
  }

  /// Uploads a file (Selfie photo, Expense Receipt, Requisition document) to ERPNext
  /// and returns the `file_url` (e.g., `/private/files/receipt.jpg`).
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    String? doctype,
    String? docname,
    String? fieldname,
    bool isPrivate = false,
  }) async {
    if (_isDemoSession) {
      return '/files/$fileName';
    }
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'is_private': isPrivate ? 1 : 0,
      'folder': 'Home/Attachments',
      if (doctype != null && doctype.isNotEmpty) 'doctype': doctype,
      if (docname != null && docname.isNotEmpty) 'docname': docname,
      if (fieldname != null && fieldname.isNotEmpty) 'fieldname': fieldname,
    });

    final Response<dynamic> res = await _dio.post<dynamic>(
      '/api/method/upload_file',
      data: formData,
      options: Options(
        headers: <String, dynamic>{'Content-Type': 'multipart/form-data'},
      ),
    );

    final Map<String, dynamic> body =
        (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> msg =
        (body['message'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return (msg['file_url'] ?? '').toString();
  }

  /// Downloads an official ERPNext PDF (Salary Slip, Sales Invoice, Sales Order, Quotation)
  /// and opens it natively on Android & iOS.
  Future<String> downloadAndOpenPdf({
    required String doctype,
    required String docname,
    String? printFormat,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String safeName = docname.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final String savePath = '${dir.path}/${doctype}_$safeName.pdf';

    final Map<String, dynamic> params = <String, dynamic>{
      'doctype': doctype,
      'name': docname,
      'no_letterhead': 0,
      if (printFormat != null && printFormat.isNotEmpty) 'format': printFormat,
    };

    await _dio.download(
      '/api/method/frappe.utils.print_format.download_pdf',
      savePath,
      queryParameters: params,
    );

    await OpenFilex.open(savePath);
    return savePath;
  }

  /// Replicates DIBL's `Auto Name and org Find by Number` Client Script on
  /// Sales Invoice & Sales Order: searches Contact by mobile/phone and returns
  /// linked Customer + Contact Person + Mobile Number.
  Future<Map<String, String>?> findCustomerByMobile(String rawPhone) async {
    String digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) {
      digits = digits.substring(2);
    }
    if (digits.length < 7) {
      return null;
    }

    List<Map<String, dynamic>> matches = await getList(
      'Contact',
      fields: <String>['name', 'mobile_no', 'phone', 'company_name'],
      listFilters: <List<dynamic>>[
        <dynamic>['mobile_no', 'like', '%$digits%'],
      ],
      limitPageLength: 10,
    );

    if (matches.isEmpty) {
      matches = await getList(
        'Contact',
        fields: <String>['name', 'mobile_no', 'phone', 'company_name'],
        listFilters: <List<dynamic>>[
          <dynamic>['phone', 'like', '%$digits%'],
        ],
        limitPageLength: 10,
      );
    }

    if (matches.isEmpty) {
      return null;
    }

    final Map<String, dynamic> bestMatch = matches.firstWhere((
      Map<String, dynamic> m,
    ) {
      final String numStr = ((m['mobile_no'] ?? m['phone'] ?? ''))
          .toString()
          .replaceAll(RegExp(r'\D'), '');
      return numStr == digits || numStr.endsWith(digits);
    }, orElse: () => matches.first);

    final String contactName = (bestMatch['name'] ?? '').toString();
    if (contactName.isEmpty) {
      return null;
    }

    final Map<String, dynamic> contactDoc = await getDoc(
      'Contact',
      contactName,
    );
    final List<dynamic> links =
        (contactDoc['links'] as List<dynamic>?) ?? <dynamic>[];
    String customerName = '';
    for (final dynamic item in links) {
      final Map<String, dynamic> link = Map<String, dynamic>.from(
        item as Map<dynamic, dynamic>,
      );
      if (link['link_doctype'] == 'Customer') {
        customerName = (link['link_name'] ?? '').toString();
        break;
      }
    }

    final String finalNumber =
        (contactDoc['mobile_no'] ?? contactDoc['phone'] ?? rawPhone).toString();
    return <String, String>{
      'customer': customerName,
      'contact_person': contactName,
      'contact_number': finalNumber,
    };
  }

  static String formatErrorMessage(Object error) {
    if (error is DioException) {
      final dynamic data = error.response?.data;
      if (data is Map<String, dynamic>) {
        if (data['_server_messages'] != null) {
          try {
            final List<dynamic> msgs = jsonDecode(
              data['_server_messages'].toString(),
            ) as List<dynamic>;
            if (msgs.isNotEmpty) {
              final Map<String, dynamic> firstMsg =
                  jsonDecode(msgs.first.toString()) as Map<String, dynamic>;
              final String rawMsg = (firstMsg['message'] ?? '').toString();
              return rawMsg.replaceAll(RegExp(r'<[^>]*>'), '');
            }
          } catch (_) {}
        }
        if (data['message'] != null) {
          return data['message'].toString();
        }
        if (data['exception'] != null) {
          return data['exception'].toString();
        }
      }
      return error.message ??
          'Network request failed (${error.response?.statusCode ?? 'offline'}).';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
