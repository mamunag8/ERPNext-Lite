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
            'email': 'rafiqul@rajshahimango.com',
            'status': 'Qualified',
            'lead_owner': 'demo@kasbpro.com',
          },
          <String, dynamic>{
            'name': 'CRM-LEAD-2026-00081',
            'lead_name': 'Engr. Kamrul Hasan',
            'first_name': 'Engr. Kamrul',
            'last_name': 'Hasan',
            'organization': 'Sylhet Citrus & Tea Agro',
            'company_name': 'Sylhet Citrus & Tea Agro',
            'mobile_no': '+8801819000000',
            'email': 'kamrul@sylhetagro.com',
            'status': 'Contacted',
            'lead_owner': 'demo@kasbpro.com',
          },
          <String, dynamic>{
            'name': 'CRM-LEAD-2026-00085',
            'lead_name': 'Abdul Kader Mia',
            'first_name': 'Abdul Kader',
            'last_name': 'Mia',
            'organization': 'Bogra High-Value Vegetable Farm',
            'company_name': 'Bogra High-Value Vegetable Farm',
            'mobile_no': '+8801911000000',
            'email': '',
            'status': 'New',
            'lead_owner': 'demo@kasbpro.com',
          },
        ];
      case 'CRM Deal':
      case 'Opportunity':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'CRM-DEAL-2026-00034',
            'organization': 'Green Valley Agro Farms Ltd',
            'party_name': 'Green Valley Agro Farms Ltd',
            'status': 'Proposal/Quotation',
            'deal_value': 320000,
            'opportunity_amount': 320000,
            'deal_owner': 'demo@kasbpro.com',
          },
          <String, dynamic>{
            'name': 'CRM-DEAL-2026-00039',
            'organization': 'Rajshahi Mango Growers',
            'party_name': 'Rajshahi Mango Growers',
            'status': 'Negotiation',
            'deal_value': 185000,
            'opportunity_amount': 185000,
            'deal_owner': 'demo@kasbpro.com',
          },
        ];
      case 'CRM Task':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TASK-CRM-0019',
            'title': 'Send 5-Acre Drip Irrigation Layout Proposal',
            'description':
                'Prepare CAD layout and BOQ for Rajshahi Mango Growers',
            'status': 'Todo',
            'priority': 'High',
            'due_date': '2026-10-23',
            'assigned_to': 'demo@kasbpro.com',
            'reference_doctype': 'CRM Lead',
            'reference_docname': 'CRM-LEAD-2026-00077',
          },
          <String, dynamic>{
            'name': 'TASK-CRM-0022',
            'title': 'Follow up on Pump & Filter Quotation',
            'description': 'Call Green Valley Agro MD regarding final discount',
            'status': 'In Progress',
            'priority': 'Medium',
            'due_date': '2026-10-24',
            'assigned_to': 'demo@kasbpro.com',
            'reference_doctype': 'CRM Deal',
            'reference_docname': 'CRM-DEAL-2026-00034',
          },
        ];
      case 'ToDo':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TODO-2026-0041',
            'description': 'Send 5-Acre Drip Irrigation Layout Proposal to Rajshahi Mango Growers',
            'status': 'Open',
            'priority': 'High',
            'date': '2026-10-23',
            'allocated_to': 'demo@kasbpro.com',
            'reference_type': 'CRM Lead',
            'reference_name': 'CRM-LEAD-2026-00077',
            'modified': '2026-10-23 08:30:00',
          },
          <String, dynamic>{
            'name': 'TODO-2026-0042',
            'description': 'Verify Gazipur Greenhouse 16mm lateral pipe stock before dispatch',
            'status': 'Open',
            'priority': 'Medium',
            'date': '2026-10-24',
            'allocated_to': 'demo@kasbpro.com',
            'reference_type': 'Project',
            'reference_name': 'PROJ-0001',
            'modified': '2026-10-22 16:15:00',
          },
          <String, dynamic>{
            'name': 'TODO-2026-0038',
            'description':
                'Complete site soil & water pressure test at Barind Orchard',
            'status': 'Closed',
            'priority': 'High',
            'date': '2026-10-20',
            'allocated_to': 'demo@kasbpro.com',
            'reference_type': 'CRM Deal',
            'reference_name': 'CRM-DEAL-2026-00034',
            'modified': '2026-10-20 17:45:00',
          },
        ];
      case 'CRM Note':
      case 'Comment':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'NOTE-2026-0012',
            'title': 'Site Survey & Water Source Discussion',
            'content': 'Client has a 5-acre mango orchard with submersible pump ready. Needs 16mm inline dripper quotation.',
            'reference_doctype': 'CRM Lead',
            'reference_docname': 'CRM-LEAD-2026-00077',
            'reference_name': 'CRM-LEAD-2026-00077',
            'owner': 'demo@kasbpro.com',
            'creation': '2026-10-22 14:20:00',
          },
          <String, dynamic>{
            'name': 'NOTE-2026-0015',
            'title': 'Follow-up Call Completed',
            'content': 'Sent BOQ via WhatsApp. Follow-up scheduled for tomorrow morning.',
            'reference_doctype': 'ToDo',
            'reference_docname': 'TODO-2026-0041',
            'reference_name': 'TODO-2026-0041',
            'owner': 'demo@kasbpro.com',
            'creation': '2026-10-23 08:15:00',
          },
        ];
      case 'Project':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'PROJ-0001',
            'project_name': 'Gazipur 10-Acre Smart Greenhouse Irrigation',
            'status': 'Open',
            'project_type': 'External',
            'project_template': '99-Not Applicable',
            'priority': 'High',
            'department': 'Engineering & Projects - DIBL',
            'cost_center': '101 - Head Office CC - DIBL',
            'company': 'Drip Irrigation BD Ltd',
            'percent_complete_method': 'Task Completion',
            'percent_complete': 75,
            'expected_start_date': '2026-09-01',
            'expected_end_date': '2026-11-15',
            'estimated_costing': 350000,
            'total_costing_amount': 125000,
            'total_expense_claim': 18500,
            'total_sales_amount': 480000,
            'total_billed_amount': 320000,
            'gross_margin': 176500,
            'customer': 'Green Valley Agro Farms Ltd',
            'is_active': 'Yes',
            'notes': '10-acre automated inline drip & fertigation system with solar pump.',
          },
          <String, dynamic>{
            'name': 'PROJ-0002',
            'project_name': 'Rajshahi 5-Acre High-Density Mango Orchard Drip',
            'status': 'Open',
            'project_type': 'External',
            'project_template': '1-Project Visit Task Sequence',
            'priority': 'Medium',
            'department': 'Branch Operations- DIBL',
            'cost_center': '105 - Bogura CC - DIBL',
            'company': 'Drip Irrigation BD Ltd',
            'percent_complete_method': 'Task Completion',
            'percent_complete': 40,
            'expected_start_date': '2026-10-01',
            'expected_end_date': '2026-12-20',
            'estimated_costing': 180000,
            'total_costing_amount': 65000,
            'total_expense_claim': 7500,
            'total_sales_amount': 240000,
            'total_billed_amount': 120000,
            'gross_margin': 47500,
            'customer': 'Barind Orchard Project',
            'is_active': 'Yes',
            'notes': 'Submersible pump filtration + 16mm inline dripper lines.',
          },
        ];
      case 'Project Template':
        return <Map<String, dynamic>>[
          <String, dynamic>{'name': '99-Not Applicable'},
          <String, dynamic>{'name': '1-Project Visit Task Sequence'},
          <String, dynamic>{
            'name': '2-General/Corporate/NGO Project Task Sequence',
          },
          <String, dynamic>{'name': '3-Govt Lead Contract Task Sequence'},
          <String, dynamic>{'name': '4-Govt Sub Contract Task Sequence'},
          <String, dynamic>{'name': '5-DIBL Product Development Task Sequence'},
          <String, dynamic>{'name': '6-IoT Product Development Task Sequence'},
        ];
      case 'Project Type':
        return <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Internal'},
          <String, dynamic>{'name': 'External'},
          <String, dynamic>{'name': 'Other'},
        ];
      case 'Cost Center':
        return <Map<String, dynamic>>[
          <String, dynamic>{'name': '101 - Head Office CC - DIBL'},
          <String, dynamic>{'name': '102 - Dhaka CC - DIBL'},
          <String, dynamic>{'name': '103 - Chattogram CC - DIBL'},
          <String, dynamic>{'name': '104 - Jashore CC - DIBL'},
          <String, dynamic>{'name': '105 - Bogura CC - DIBL'},
          <String, dynamic>{'name': '106 - Sylhet CC - DIBL'},
          <String, dynamic>{'name': '107 - Barisal CC - DIBL'},
          <String, dynamic>{'name': '108 - Rangpur CC - DIBL'},
        ];
      case 'Department':
        return <Map<String, dynamic>>[
          <String, dynamic>{'name': 'HR & Admin Department- DIBL'},
          <String, dynamic>{'name': 'Branch Operations- DIBL'},
          <String, dynamic>{'name': 'Marketing Department- DIBL'},
          <String, dynamic>{'name': 'Supply Chain & Inventory- DIBL'},
          <String, dynamic>{'name': 'IOT & Automation- DIBL'},
          <String, dynamic>{'name': 'Accounts & Finance- DIBL'},
          <String, dynamic>{'name': 'Research & Development- DIBL'},
          <String, dynamic>{'name': 'Executive Management- DIBL'},
          <String, dynamic>{'name': 'Head Office- DIBL'},
        ];
      case 'Task':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'TASK-2026-00051',
            'subject': 'Install Inline Dripper Laterals & Pressure Gauge',
            'project': 'PROJ-0001',
            'status': 'Working',
            'priority': 'High',
            'progress': 60,
            'exp_start_date': '2026-10-18 09:00:00',
            'exp_end_date': '2026-10-25 18:00:00',
            'department': 'HR & Admin Department- DIBL',
            'company': 'Drip Irrigation BD Ltd',
            'description': 'Install 16mm inline dripper lines across Block A & B and verify 1.5 bar pressure.',
          },
          <String, dynamic>{
            'name': 'TASK-2026-00052',
            'subject': 'Main Header PVC Trenching & Hydro-Test',
            'project': 'PROJ-0001',
            'status': 'Completed',
            'priority': 'Medium',
            'progress': 100,
            'exp_start_date': '2026-10-10 09:00:00',
            'exp_end_date': '2026-10-15 18:00:00',
            'department': 'Branch Operations- DIBL',
            'company': 'Drip Irrigation BD Ltd',
            'description': 'Completed 3-inch PVC main line trenching and test.',
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

  final Map<String, List<Map<String, dynamic>>> _demoStore =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, List<Map<String, dynamic>>> _doctypeFieldsCache =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Map<String, int>> _doctypePermissionsCache =
      <String, Map<String, int>>{};

  List<Map<String, dynamic>> _getMutableDemoList(String doctype) {
    return _demoStore.putIfAbsent(
      doctype,
      () =>
          _getDemoList(doctype)
              .map((Map<String, dynamic> e) => Map<String, dynamic>.from(e))
              .toList(),
    );
  }

  Map<String, dynamic> _applySmartServerDefaults(
    String doctype,
    Map<String, dynamic> payload,
  ) {
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(payload);
    final UserSession? s = _session;
    final String defaultCompany = s?.company.isNotEmpty == true
        ? s!.company
        : 'Drip Irrigation BD Ltd';
    final String defaultCostCenter = s?.costCenter.isNotEmpty == true
        ? s!.costCenter
        : (s != null && s.costCenters.isNotEmpty
              ? s.costCenters.first
              : '101 - Head Office CC - DIBL');
    final String defaultDept = s?.department.isNotEmpty == true
        ? s!.department
        : (s != null && s.departments.isNotEmpty
              ? s.departments.first
              : 'HR & Admin Department- DIBL');
    final String defaultWh = s != null && s.warehouses.isNotEmpty
        ? s.warehouses.first
        : '';
    final String nowDate = DateTime.now().toIso8601String().substring(0, 10);
    final String nowDateTime = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceFirst('T', ' ');

    if (doctype == 'Project') {
      enriched.putIfAbsent('company', () => defaultCompany);
      if ((enriched['project_template'] ?? '').toString().trim().isEmpty) {
        enriched['project_template'] = '99-Not Applicable';
      }
      if ((enriched['cost_center'] ?? '').toString().trim().isEmpty) {
        enriched['cost_center'] = defaultCostCenter;
      }
      if ((enriched['department'] ?? '').toString().trim().isEmpty &&
          defaultDept.isNotEmpty) {
        enriched['department'] = defaultDept;
      }
      enriched.putIfAbsent('status', () => 'Open');
      enriched.putIfAbsent('is_active', () => 'Yes');
      enriched.putIfAbsent('expected_start_date', () => nowDate);
    } else if (doctype == 'Task') {
      enriched.putIfAbsent('company', () => defaultCompany);
      if ((enriched['exp_start_date'] ?? '').toString().trim().isEmpty) {
        enriched['exp_start_date'] = nowDateTime;
      }
      if ((enriched['exp_end_date'] ?? '').toString().trim().isEmpty) {
        enriched['exp_end_date'] = nowDateTime;
      }
      if ((enriched['department'] ?? '').toString().trim().isEmpty &&
          defaultDept.isNotEmpty) {
        enriched['department'] = defaultDept;
      }
      enriched.putIfAbsent('status', () => 'Open');
      enriched.putIfAbsent('priority', () => 'Medium');
    } else if (doctype == 'Sales Invoice' || doctype == 'Sales Order') {
      enriched.putIfAbsent('company', () => defaultCompany);
      if ((enriched['cost_center'] ?? '').toString().trim().isEmpty &&
          defaultCostCenter.isNotEmpty) {
        enriched['cost_center'] = defaultCostCenter;
      }
      if ((enriched['department'] ?? '').toString().trim().isEmpty &&
          defaultDept.isNotEmpty) {
        enriched['department'] = defaultDept;
      }
      if ((enriched['set_warehouse'] ?? '').toString().trim().isEmpty &&
          defaultWh.isNotEmpty) {
        enriched['set_warehouse'] = defaultWh;
      }
      if (doctype == 'Sales Order' &&
          (enriched['delivery_date'] ?? '').toString().trim().isEmpty) {
        enriched['delivery_date'] = nowDate;
      }
      if (enriched['items'] is List) {
        final List<Map<String, dynamic>> updatedItems =
            (enriched['items'] as List<dynamic>).map((dynamic raw) {
              final Map<String, dynamic> row = Map<String, dynamic>.from(
                raw as Map<dynamic, dynamic>,
              );
              if (doctype == 'Sales Invoice' &&
                  (row['department'] ?? '').toString().trim().isEmpty &&
                  defaultDept.isNotEmpty) {
                row['department'] = defaultDept;
              }
              if ((row['cost_center'] ?? '').toString().trim().isEmpty &&
                  defaultCostCenter.isNotEmpty) {
                row['cost_center'] = defaultCostCenter;
              }
              if ((row['warehouse'] ?? '').toString().trim().isEmpty &&
                  defaultWh.isNotEmpty) {
                row['warehouse'] = defaultWh;
              }
              return row;
            }).toList();
        enriched['items'] = updatedItems;
      }
    } else if (doctype == 'Purchase Invoice') {
      enriched.putIfAbsent('company', () => defaultCompany);
      if (enriched['items'] is List) {
        final List<Map<String, dynamic>> updatedItems =
            (enriched['items'] as List<dynamic>).map((dynamic raw) {
              final Map<String, dynamic> row = Map<String, dynamic>.from(
                raw as Map<dynamic, dynamic>,
              );
              if ((row['department'] ?? '').toString().trim().isEmpty &&
                  defaultDept.isNotEmpty) {
                row['department'] = defaultDept;
              }
              return row;
            }).toList();
        enriched['items'] = updatedItems;
      }
    } else if (doctype == 'Payment Entry') {
      enriched.putIfAbsent('company', () => defaultCompany);
      if ((enriched['cost_center'] ?? '').toString().trim().isEmpty &&
          defaultCostCenter.isNotEmpty) {
        enriched['cost_center'] = defaultCostCenter;
      }
      if ((enriched['department'] ?? '').toString().trim().isEmpty &&
          defaultDept.isNotEmpty) {
        enriched['department'] = defaultDept;
      }
      if ((enriched['mode_of_payment'] ?? '').toString().trim().isEmpty) {
        enriched['mode_of_payment'] = 'Cash';
      }
      if ((enriched['custom_particular_description'] ?? '')
          .toString()
          .trim()
          .isEmpty) {
        enriched['custom_particular_description'] =
            (enriched['remarks'] ?? 'Payment Entry via Mobile App').toString();
      }
    } else if (doctype == 'CRM Deal') {
      if ((enriched['expected_closure_date'] ?? '').toString().trim().isEmpty) {
        enriched['expected_closure_date'] = nowDate;
      }
      if (enriched['expected_deal_value'] == null) {
        enriched['expected_deal_value'] = enriched['deal_value'] ?? 0;
      }
      if ((enriched['custom_service_category'] ?? '')
          .toString()
          .trim()
          .isEmpty) {
        enriched['custom_service_category'] = 'Drip';
      }
      if ((enriched['custom_area_coverage_in_decimal'] ?? '')
          .toString()
          .trim()
          .isEmpty) {
        enriched['custom_area_coverage_in_decimal'] = '100';
      }
      if ((enriched['custom_gender_category'] ?? '')
          .toString()
          .trim()
          .isEmpty) {
        enriched['custom_gender_category'] = 'Male';
      }
    } else if (doctype == 'CRM Task') {
      if ((enriched['due_date'] ?? '').toString().trim().isEmpty) {
        enriched['due_date'] = nowDate;
      }
      if ((enriched['assigned_to'] ?? '').toString().trim().isEmpty &&
          s != null &&
          s.email.isNotEmpty) {
        enriched['assigned_to'] = s.email;
      }
    }
    return enriched;
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
      return List<Map<String, dynamic>>.from(_getMutableDemoList(doctype));
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
      final List<Map<String, dynamic>> list = _getMutableDemoList(doctype);
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

  /// Resolves the logged-in user's DocType-level permissions (`read`, `write`,
  /// `create`, `submit`, `cancel`, `delete`) from ERPNext's DocPerm rules.
  Future<Map<String, int>> getDocTypePermissions(String doctype) async {
    if (_doctypePermissionsCache.containsKey(doctype)) {
      return _doctypePermissionsCache[doctype]!;
    }
    final Map<String, int> resolved = <String, int>{
      'read': 1,
      'write': 1,
      'create': 1,
      'submit': 1,
      'cancel': 1,
      'delete': 1,
    };
    if (_isDemoSession) {
      _doctypePermissionsCache[doctype] = resolved;
      return resolved;
    }

    try {
      await getDocTypeFields(doctype);
      if (_doctypePermissionsCache.containsKey(doctype)) {
        return _doctypePermissionsCache[doctype]!;
      }
    } catch (_) {}

    _doctypePermissionsCache[doctype] = resolved;
    return resolved;
  }

  void _extractAndCacheDocTypePermissions(
    String doctype,
    Map<String, dynamic> dtDoc,
  ) {
    final List<dynamic> rawPerms =
        (dtDoc['permissions'] as List<dynamic>?) ?? <dynamic>[];
    if (rawPerms.isEmpty) {
      return;
    }
    final List<String> userRoles = _session?.roles ?? const <String>[];
    final bool isAdminOrSysMgr =
        _session?.username.toLowerCase() == 'administrator' ||
        userRoles.contains('System Manager') ||
        userRoles.contains('Administrator');

    if (isAdminOrSysMgr) {
      final int isSubmittable = (dtDoc['is_submittable'] as num?)?.toInt() ?? 0;
      _doctypePermissionsCache[doctype] = <String, int>{
        'read': 1,
        'write': 1,
        'create': 1,
        'submit': isSubmittable,
        'cancel': isSubmittable,
        'delete': 1,
      };
      return;
    }

    int canRead = 0;
    int canWrite = 0;
    int canCreate = 0;
    int canSubmit = 0;
    int canCancel = 0;
    int canDelete = 0;
    bool matchedAnyRole = false;

    for (final dynamic raw in rawPerms) {
      if (raw is! Map) {
        continue;
      }
      final Map<String, dynamic> p = Map<String, dynamic>.from(raw);
      final int permLevel = (p['permlevel'] as num?)?.toInt() ?? 0;
      if (permLevel != 0) {
        continue;
      }
      final String role = (p['role'] ?? '').toString();
      if (userRoles.isEmpty ||
          userRoles.contains(role) ||
          role == 'All' ||
          role == 'Employee') {
        matchedAnyRole = true;
        if (((p['read'] as num?)?.toInt() ?? 0) == 1) canRead = 1;
        if (((p['write'] as num?)?.toInt() ?? 0) == 1) canWrite = 1;
        if (((p['create'] as num?)?.toInt() ?? 0) == 1) canCreate = 1;
        if (((p['submit'] as num?)?.toInt() ?? 0) == 1) canSubmit = 1;
        if (((p['cancel'] as num?)?.toInt() ?? 0) == 1) canCancel = 1;
        if (((p['delete'] as num?)?.toInt() ?? 0) == 1) canDelete = 1;
      }
    }

    if (matchedAnyRole) {
      _doctypePermissionsCache[doctype] = <String, int>{
        'read': canRead,
        'write': canWrite,
        'create': canCreate,
        'submit': canSubmit,
        'cancel': canCancel,
        'delete': canDelete,
      };
    }
  }

  /// Fetches a document along with the current user's ERPNext permissions
  /// (`read`, `write`, `create`, `submit`, `cancel`, `delete`, `amend`).
  Future<Map<String, dynamic>> getDocWithPermissions(
    String doctype,
    String name,
  ) async {
    final Map<String, int> dtPerms = await getDocTypePermissions(doctype);
    Map<String, dynamic> defaultPerms = Map<String, dynamic>.from(dtPerms);
    if (_isDemoSession) {
      final Map<String, dynamic> doc = await getDoc(doctype, name);
      return <String, dynamic>{'doc': doc, 'permissions': defaultPerms};
    }

    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/api/method/frappe.desk.form.load.getdoc',
        queryParameters: <String, dynamic>{'doctype': doctype, 'name': name},
      );
      final Map<String, dynamic> body =
          (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
      final List<dynamic> docs =
          (body['docs'] as List<dynamic>?) ?? <dynamic>[];
      final Map<String, dynamic> docinfo =
          (body['docinfo'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (docinfo['permissions'] is Map) {
        defaultPerms = <String, dynamic>{
          ...defaultPerms,
          ...Map<String, dynamic>.from(
            docinfo['permissions'] as Map<dynamic, dynamic>,
          ),
        };
      }
      if (docs.isNotEmpty && docs.first is Map) {
        return <String, dynamic>{
          'doc': Map<String, dynamic>.from(docs.first as Map<dynamic, dynamic>),
          'permissions': defaultPerms,
        };
      }
    } catch (_) {}

    final Map<String, dynamic> doc = await getDoc(doctype, name);
    return <String, dynamic>{'doc': doc, 'permissions': defaultPerms};
  }

  /// Fetches the live field metadata for [doctype] from ERPNext Desk (`getdoctype`)
  /// including all Custom Fields & Property Setters, falling back to built-in definitions.
  Future<List<Map<String, dynamic>>> getDocTypeFields(String doctype) async {
    if (_doctypeFieldsCache.containsKey(doctype)) {
      return _doctypeFieldsCache[doctype]!;
    }
    if (!_isDemoSession) {
      try {
        final Response<dynamic> res = await _dio.get<dynamic>(
          '/api/method/frappe.desk.form.load.getdoctype',
          queryParameters: <String, dynamic>{'doctype': doctype},
        );
        final Map<String, dynamic> body =
            (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
        final List<dynamic> docs =
            (body['docs'] as List<dynamic>?) ?? <dynamic>[];
        if (docs.isNotEmpty && docs.first is Map) {
          final Map<String, dynamic> dtDoc = Map<String, dynamic>.from(
            docs.first as Map<dynamic, dynamic>,
          );
          _extractAndCacheDocTypePermissions(doctype, dtDoc);
          final List<dynamic> rawFields =
              (dtDoc['fields'] as List<dynamic>?) ?? <dynamic>[];
          final List<Map<String, dynamic>> parsed = rawFields
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> f) => Map<String, dynamic>.from(f))
              .where((Map<String, dynamic> f) {
                final String ft = (f['fieldtype'] ?? '').toString();
                final int hidden = (f['hidden'] as num?)?.toInt() ?? 0;
                return hidden == 0 &&
                    ft != 'Section Break' &&
                    ft != 'Column Break' &&
                    ft != 'Tab Break' &&
                    ft != 'HTML' &&
                    ft != 'Button' &&
                    ft != 'Fold';
              })
              .toList();
          if (parsed.isNotEmpty) {
            _doctypeFieldsCache[doctype] = parsed;
            return parsed;
          }
        }
      } catch (_) {}
    }

    final List<Map<String, dynamic>> fallback = _getFallbackDocTypeFields(
      doctype,
    );
    _doctypeFieldsCache[doctype] = fallback;
    return fallback;
  }

  /// Searches records on the ERPNext server for [doctype] matching [query].
  Future<List<Map<String, dynamic>>> searchDocTypeRecords(
    String doctype,
    String query, {
    List<String> fields = const <String>[
      'name',
      'modified',
      'owner',
      'docstatus',
    ],
  }) async {
    final String q = query.trim();
    if (q.isEmpty) {
      return getList(doctype, fields: fields, limitPageLength: 80);
    }
    try {
      final List<Map<String, dynamic>> byLike = await getList(
        doctype,
        fields: fields,
        listFilters: <List<dynamic>>[
          <dynamic>['name', 'like', '%$q%'],
        ],
        limitPageLength: 50,
      );
      if (byLike.isNotEmpty) {
        return byLike;
      }
    } catch (_) {}

    try {
      final List<String> linkNames = await searchLinkOptions(doctype, query: q);
      if (linkNames.isNotEmpty) {
        return linkNames
            .map(
              (String name) => <String, dynamic>{
                'name': name,
                'modified': 'Matched via Server Search',
                'owner': '',
                'docstatus': 0,
              },
            )
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _getFallbackDocTypeFields(String doctype) {
    switch (doctype) {
      case 'Project':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'project_name',
            'label': 'Project Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Open\nCompleted\nCancelled',
            'default': 'Open',
          },
          <String, dynamic>{
            'fieldname': 'project_template',
            'label': 'From Template',
            'fieldtype': 'Link',
            'options': 'Project Template',
            'reqd': 1,
            'default': '99-Not Applicable',
          },
          <String, dynamic>{
            'fieldname': 'cost_center',
            'label': 'Default Cost Center',
            'fieldtype': 'Link',
            'options': 'Cost Center',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'department',
            'label': 'Department',
            'fieldtype': 'Link',
            'options': 'Department',
          },
          <String, dynamic>{
            'fieldname': 'project_type',
            'label': 'Project Type',
            'fieldtype': 'Link',
            'options': 'Project Type',
          },
          <String, dynamic>{
            'fieldname': 'priority',
            'label': 'Priority',
            'fieldtype': 'Select',
            'options': 'Medium\nLow\nHigh',
            'default': 'Medium',
          },
          <String, dynamic>{
            'fieldname': 'is_active',
            'label': 'Is Active',
            'fieldtype': 'Select',
            'options': 'Yes\nNo',
            'default': 'Yes',
          },
          <String, dynamic>{
            'fieldname': 'percent_complete_method',
            'label': '% Complete Method',
            'fieldtype': 'Select',
            'options': 'Manual\nTask Completion\nTask Progress\nTask Weight',
            'default': 'Task Completion',
          },
          <String, dynamic>{
            'fieldname': 'percent_complete',
            'label': '% Completed',
            'fieldtype': 'Percent',
          },
          <String, dynamic>{
            'fieldname': 'expected_start_date',
            'label': 'Expected Start Date',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'expected_end_date',
            'label': 'Expected End Date',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'estimated_costing',
            'label': 'Estimated Cost',
            'fieldtype': 'Currency',
          },
          <String, dynamic>{
            'fieldname': 'customer',
            'label': 'Customer',
            'fieldtype': 'Link',
            'options': 'Customer',
          },
          <String, dynamic>{
            'fieldname': 'sales_order',
            'label': 'Sales Order',
            'fieldtype': 'Link',
            'options': 'Sales Order',
          },
          <String, dynamic>{
            'fieldname': 'company',
            'label': 'Company',
            'fieldtype': 'Link',
            'options': 'Company',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'notes',
            'label': 'Notes',
            'fieldtype': 'Text Editor',
          },
        ];
      case 'Task':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'subject',
            'label': 'Subject',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Open\nWorking\nPending Review\nOverdue\nTemplate\nCompleted\nCancelled\nParent Task',
            'default': 'Open',
          },
          <String, dynamic>{
            'fieldname': 'priority',
            'label': 'Priority',
            'fieldtype': 'Select',
            'options': 'Low\nMedium\nHigh\nUrgent',
            'default': 'Medium',
          },
          <String, dynamic>{
            'fieldname': 'progress',
            'label': '% Progress',
            'fieldtype': 'Percent',
          },
          <String, dynamic>{
            'fieldname': 'exp_start_date',
            'label': 'Expected Start Date',
            'fieldtype': 'Datetime',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'exp_end_date',
            'label': 'Expected End Date',
            'fieldtype': 'Datetime',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'expected_time',
            'label': 'Expected Time (Hours)',
            'fieldtype': 'Float',
          },
          <String, dynamic>{
            'fieldname': 'department',
            'label': 'Department',
            'fieldtype': 'Link',
            'options': 'Department',
          },
          <String, dynamic>{
            'fieldname': 'completed_by',
            'label': 'Completed By',
            'fieldtype': 'Link',
            'options': 'User',
          },
          <String, dynamic>{
            'fieldname': 'completed_on',
            'label': 'Completed On',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'description',
            'label': 'Task Details / Description',
            'fieldtype': 'Text Editor',
          },
        ];
      case 'Timesheet':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'company',
            'label': 'Company',
            'fieldtype': 'Link',
            'options': 'Company',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'start_date',
            'label': 'Start Date',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'time_logs',
            'label': 'Time Sheets',
            'fieldtype': 'Table',
            'options': 'Timesheet Detail',
            'reqd': 1,
          },
        ];
      case 'Sales Invoice':
      case 'Sales Order':
      case 'Delivery Note':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'customer',
            'label': 'Customer',
            'fieldtype': 'Link',
            'options': 'Customer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': doctype == 'Sales Order'
                ? 'transaction_date'
                : 'posting_date',
            'label': 'Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          if (doctype == 'Sales Order')
            <String, dynamic>{
              'fieldname': 'delivery_date',
              'label': 'Delivery Date',
              'fieldtype': 'Date',
              'reqd': 1,
            },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
          <String, dynamic>{
            'fieldname': 'cost_center',
            'label': 'Cost Center',
            'fieldtype': 'Link',
            'options': 'Cost Center',
          },
          <String, dynamic>{
            'fieldname': 'department',
            'label': 'Department',
            'fieldtype': 'Link',
            'options': 'Department',
          },
          <String, dynamic>{
            'fieldname': 'set_warehouse',
            'label': 'Source Warehouse',
            'fieldtype': 'Link',
            'options': 'Warehouse',
          },
          <String, dynamic>{
            'fieldname': 'items',
            'label': 'Items',
            'fieldtype': 'Table',
            'options': '$doctype Item',
            'reqd': 1,
          },
        ];
      case 'Quotation':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'quotation_to',
            'label': 'Quotation To',
            'fieldtype': 'Select',
            'options': 'Customer\nLead',
            'default': 'Customer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'party_name',
            'label': 'Customer / Lead',
            'fieldtype': 'Link',
            'options': 'Customer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'transaction_date',
            'label': 'Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'items',
            'label': 'Items',
            'fieldtype': 'Table',
            'options': 'Quotation Item',
            'reqd': 1,
          },
        ];
      case 'Purchase Order':
      case 'Purchase Receipt':
      case 'Purchase Invoice':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'supplier',
            'label': 'Supplier',
            'fieldtype': 'Link',
            'options': 'Supplier',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': doctype == 'Purchase Order'
                ? 'transaction_date'
                : 'posting_date',
            'label': 'Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
          <String, dynamic>{
            'fieldname': 'cost_center',
            'label': 'Cost Center',
            'fieldtype': 'Link',
            'options': 'Cost Center',
          },
          <String, dynamic>{
            'fieldname': 'set_warehouse',
            'label': 'Target Warehouse',
            'fieldtype': 'Link',
            'options': 'Warehouse',
          },
          <String, dynamic>{
            'fieldname': 'items',
            'label': 'Items',
            'fieldtype': 'Table',
            'options': '$doctype Item',
            'reqd': 1,
          },
        ];
      case 'Material Request':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'material_request_type',
            'label': 'Purpose',
            'fieldtype': 'Select',
            'options':
                'Purchase\nMaterial Transfer\nMaterial Issue\nManufacture',
            'default': 'Material Transfer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'transaction_date',
            'label': 'Transaction Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'schedule_date',
            'label': 'Required By Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'set_warehouse',
            'label': 'Target Warehouse',
            'fieldtype': 'Link',
            'options': 'Warehouse',
          },
          <String, dynamic>{
            'fieldname': 'items',
            'label': 'Items',
            'fieldtype': 'Table',
            'options': 'Material Request Item',
            'reqd': 1,
          },
        ];
      case 'Stock Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'stock_entry_type',
            'label': 'Stock Entry Type',
            'fieldtype': 'Select',
            'options': 'Material Issue\nMaterial Receipt\nMaterial Transfer',
            'default': 'Material Transfer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'from_warehouse',
            'label': 'Default Source Warehouse',
            'fieldtype': 'Link',
            'options': 'Warehouse',
          },
          <String, dynamic>{
            'fieldname': 'to_warehouse',
            'label': 'Default Target Warehouse',
            'fieldtype': 'Link',
            'options': 'Warehouse',
          },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
          <String, dynamic>{
            'fieldname': 'items',
            'label': 'Items',
            'fieldtype': 'Table',
            'options': 'Stock Entry Detail',
            'reqd': 1,
          },
        ];
      case 'Payment Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'payment_type',
            'label': 'Payment Type',
            'fieldtype': 'Select',
            'options': 'Receive\nPay\nInternal Transfer',
            'default': 'Receive',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'party_type',
            'label': 'Party Type',
            'fieldtype': 'Select',
            'options': 'Customer\nSupplier\nEmployee',
            'default': 'Customer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'party',
            'label': 'Party',
            'fieldtype': 'Link',
            'options': 'Customer',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'mode_of_payment',
            'label': 'Mode of Payment',
            'fieldtype': 'Select',
            'options': 'Cash\nBank Draft\nWire Transfer\nCheque',
            'default': 'Cash',
          },
          <String, dynamic>{
            'fieldname': 'paid_amount',
            'label': 'Paid Amount',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'received_amount',
            'label': 'Received Amount',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'remarks',
            'label': 'Remarks',
            'fieldtype': 'Small Text',
          },
        ];
      case 'Journal Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'voucher_type',
            'label': 'Entry Type',
            'fieldtype': 'Select',
            'options': 'Journal Entry\nBank Entry\nCash Entry\nContra Entry',
            'default': 'Journal Entry',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'user_remark',
            'label': 'User Remark',
            'fieldtype': 'Small Text',
          },
          <String, dynamic>{
            'fieldname': 'accounts',
            'label': 'Accounting Entries',
            'fieldtype': 'Table',
            'options': 'Journal Entry Account',
            'reqd': 1,
          },
        ];
      case 'Customer':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'customer_name',
            'label': 'Customer Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'customer_type',
            'label': 'Customer Type',
            'fieldtype': 'Select',
            'options': 'Company\nIndividual',
            'default': 'Company',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'customer_group',
            'label': 'Customer Group',
            'fieldtype': 'Link',
            'options': 'Customer Group',
          },
          <String, dynamic>{
            'fieldname': 'territory',
            'label': 'Territory',
            'fieldtype': 'Link',
            'options': 'Territory',
          },
          <String, dynamic>{
            'fieldname': 'mobile_no',
            'label': 'Mobile No',
            'fieldtype': 'Data',
          },
        ];
      case 'Supplier':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'supplier_name',
            'label': 'Supplier Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'supplier_group',
            'label': 'Supplier Group',
            'fieldtype': 'Link',
            'options': 'Supplier Group',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'supplier_type',
            'label': 'Supplier Type',
            'fieldtype': 'Select',
            'options': 'Company\nIndividual',
            'default': 'Company',
          },
          <String, dynamic>{
            'fieldname': 'country',
            'label': 'Country',
            'fieldtype': 'Data',
            'default': 'Bangladesh',
          },
        ];
      case 'Item':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'item_code',
            'label': 'Item Code',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'item_name',
            'label': 'Item Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'item_group',
            'label': 'Item Group',
            'fieldtype': 'Link',
            'options': 'Item Group',
            'reqd': 1,
            'default': 'Products',
          },
          <String, dynamic>{
            'fieldname': 'stock_uom',
            'label': 'Default Unit of Measure',
            'fieldtype': 'Link',
            'options': 'UOM',
            'reqd': 1,
            'default': 'Nos',
          },
          <String, dynamic>{
            'fieldname': 'standard_rate',
            'label': 'Standard Selling Rate',
            'fieldtype': 'Currency',
          },
          <String, dynamic>{
            'fieldname': 'is_stock_item',
            'label': 'Maintain Stock',
            'fieldtype': 'Check',
            'default': 1,
          },
        ];
      case 'Item Price':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'item_code',
            'label': 'Item Code',
            'fieldtype': 'Link',
            'options': 'Item',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'price_list',
            'label': 'Price List',
            'fieldtype': 'Link',
            'options': 'Price List',
            'reqd': 1,
            'default': 'Standard Selling',
          },
          <String, dynamic>{
            'fieldname': 'price_list_rate',
            'label': 'Rate',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
        ];
      case 'Asset':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'asset_name',
            'label': 'Asset Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'item_code',
            'label': 'Item Code',
            'fieldtype': 'Link',
            'options': 'Item',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'location',
            'label': 'Location',
            'fieldtype': 'Link',
            'options': 'Location',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'gross_purchase_amount',
            'label': 'Gross Purchase Amount',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
        ];
      case 'Asset Movement':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'purpose',
            'label': 'Purpose',
            'fieldtype': 'Select',
            'options': 'Issue\nReceipt\nTransfer',
            'default': 'Issue',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'transaction_date',
            'label': 'Transaction Date',
            'fieldtype': 'Datetime',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'assets',
            'label': 'Assets',
            'fieldtype': 'Table',
            'options': 'Asset Movement Item',
            'reqd': 1,
          },
        ];
      case 'Employee':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'first_name',
            'label': 'First Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'employee_name',
            'label': 'Full Name',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'gender',
            'label': 'Gender',
            'fieldtype': 'Select',
            'options': 'Male\nFemale\nOther',
            'default': 'Male',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'date_of_birth',
            'label': 'Date of Birth',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'date_of_joining',
            'label': 'Date of Joining',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'department',
            'label': 'Department',
            'fieldtype': 'Link',
            'options': 'Department',
          },
          <String, dynamic>{
            'fieldname': 'designation',
            'label': 'Designation',
            'fieldtype': 'Link',
            'options': 'Designation',
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Active\nInactive\nSuspended\nLeft',
            'default': 'Active',
          },
        ];
      case 'Attendance':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'attendance_date',
            'label': 'Attendance Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Present\nAbsent\nOn Leave\nHalf Day\nWork From Home',
            'default': 'Present',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'shift',
            'label': 'Shift',
            'fieldtype': 'Link',
            'options': 'Shift Type',
          },
          <String, dynamic>{
            'fieldname': 'late_entry',
            'label': 'Late Entry',
            'fieldtype': 'Check',
          },
          <String, dynamic>{
            'fieldname': 'early_exit',
            'label': 'Early Exit',
            'fieldtype': 'Check',
          },
        ];
      case 'Employee Checkin':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'log_type',
            'label': 'Log Type',
            'fieldtype': 'Select',
            'options': 'IN\nOUT',
            'default': 'IN',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'time',
            'label': 'Time',
            'fieldtype': 'Datetime',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'device_id',
            'label': 'Location / Device ID',
            'fieldtype': 'Data',
          },
        ];
      case 'Shift Request':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'shift_type',
            'label': 'Shift Type',
            'fieldtype': 'Link',
            'options': 'Shift Type',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'from_date',
            'label': 'From Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'to_date',
            'label': 'To Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Draft\nApproved\nRejected',
            'default': 'Draft',
          },
        ];
      case 'Leave Application':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'leave_type',
            'label': 'Leave Type',
            'fieldtype': 'Link',
            'options': 'Leave Type',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'from_date',
            'label': 'From Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'to_date',
            'label': 'To Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Open\nApproved\nRejected\nCancelled',
            'default': 'Open',
          },
          <String, dynamic>{
            'fieldname': 'description',
            'label': 'Reason',
            'fieldtype': 'Small Text',
          },
        ];
      case 'Leave Allocation':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'leave_type',
            'label': 'Leave Type',
            'fieldtype': 'Link',
            'options': 'Leave Type',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'from_date',
            'label': 'From Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'to_date',
            'label': 'To Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'new_leaves_allocated',
            'label': 'New Leaves Allocated',
            'fieldtype': 'Float',
            'reqd': 1,
          },
        ];
      case 'Expense Claim':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'approval_status',
            'label': 'Approval Status',
            'fieldtype': 'Select',
            'options': 'Draft\nApproved\nRejected',
            'default': 'Draft',
          },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
          <String, dynamic>{
            'fieldname': 'cost_center',
            'label': 'Cost Center',
            'fieldtype': 'Link',
            'options': 'Cost Center',
          },
          <String, dynamic>{
            'fieldname': 'expenses',
            'label': 'Expenses',
            'fieldtype': 'Table',
            'options': 'Expense Claim Detail',
            'reqd': 1,
          },
        ];
      case 'Employee Advance':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'advance_amount',
            'label': 'Advance Amount',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'purpose',
            'label': 'Purpose',
            'fieldtype': 'Small Text',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'project',
            'label': 'Project',
            'fieldtype': 'Link',
            'options': 'Project',
          },
        ];
      case 'Salary Slip':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'start_date',
            'label': 'Start Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'end_date',
            'label': 'End Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'salary_structure',
            'label': 'Salary Structure',
            'fieldtype': 'Link',
            'options': 'Salary Structure',
          },
          <String, dynamic>{
            'fieldname': 'earnings',
            'label': 'Earnings',
            'fieldtype': 'Table',
            'options': 'Salary Detail',
          },
          <String, dynamic>{
            'fieldname': 'deductions',
            'label': 'Deductions',
            'fieldtype': 'Table',
            'options': 'Salary Detail',
          },
        ];
      case 'Payroll Entry':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'posting_date',
            'label': 'Posting Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'payroll_frequency',
            'label': 'Payroll Frequency',
            'fieldtype': 'Select',
            'options': 'Monthly\nFortnightly\nBimonthly\nWeekly\nDaily',
            'default': 'Monthly',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'start_date',
            'label': 'Start Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'end_date',
            'label': 'End Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'department',
            'label': 'Department',
            'fieldtype': 'Link',
            'options': 'Department',
          },
        ];
      case 'Salary Structure':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'name',
            'label': 'Structure Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'company',
            'label': 'Company',
            'fieldtype': 'Link',
            'options': 'Company',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'is_active',
            'label': 'Is Active',
            'fieldtype': 'Select',
            'options': 'Yes\nNo',
            'default': 'Yes',
          },
          <String, dynamic>{
            'fieldname': 'payroll_frequency',
            'label': 'Payroll Frequency',
            'fieldtype': 'Select',
            'options': 'Monthly\nFortnightly\nBimonthly\nWeekly\nDaily',
            'default': 'Monthly',
          },
        ];
      case 'Salary Structure Assignment':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'salary_structure',
            'label': 'Salary Structure',
            'fieldtype': 'Link',
            'options': 'Salary Structure',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'from_date',
            'label': 'From Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'base',
            'label': 'Base Salary',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'variable',
            'label': 'Variable Pay',
            'fieldtype': 'Currency',
          },
        ];
      case 'Additional Salary':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'employee',
            'label': 'Employee',
            'fieldtype': 'Link',
            'options': 'Employee',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'salary_component',
            'label': 'Salary Component',
            'fieldtype': 'Link',
            'options': 'Salary Component',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'payroll_date',
            'label': 'Payroll Date',
            'fieldtype': 'Date',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'amount',
            'label': 'Amount',
            'fieldtype': 'Currency',
            'reqd': 1,
          },
        ];
      case 'CRM Lead':
      case 'Lead':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'first_name',
            'label': 'First Name',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'last_name',
            'label': 'Last Name',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': doctype == 'CRM Lead'
                ? 'organization'
                : 'company_name',
            'label': 'Organization / Company',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'mobile_no',
            'label': 'Mobile No',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'email',
            'label': 'Email',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'New\nContacted\nNurture\nQualified\nConverted\nJunk',
            'default': 'New',
          },
        ];
      case 'CRM Deal':
      case 'Opportunity':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': doctype == 'CRM Deal' ? 'organization' : 'party_name',
            'label': 'Organization / Party',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Pipeline Stage',
            'fieldtype': 'Select',
            'options': 'Qualification\nDemo/Making\nProposal/Quotation\nNegotiation\nReady to Close\nWon\nLost',
            'default': 'Qualification',
          },
          <String, dynamic>{
            'fieldname': doctype == 'CRM Deal'
                ? 'deal_value'
                : 'opportunity_amount',
            'label': 'Deal Value',
            'fieldtype': 'Currency',
          },
          <String, dynamic>{
            'fieldname': 'expected_closure_date',
            'label': 'Expected Closure Date',
            'fieldtype': 'Date',
          },
        ];
      case 'CRM Task':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'title',
            'label': 'Task Title',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Todo\nIn Progress\nDone\nCancelled',
            'default': 'Todo',
          },
          <String, dynamic>{
            'fieldname': 'priority',
            'label': 'Priority',
            'fieldtype': 'Select',
            'options': 'Low\nMedium\nHigh',
            'default': 'Medium',
          },
          <String, dynamic>{
            'fieldname': 'due_date',
            'label': 'Due Date',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'assigned_to',
            'label': 'Assigned To',
            'fieldtype': 'Link',
            'options': 'User',
          },
          <String, dynamic>{
            'fieldname': 'description',
            'label': 'Description',
            'fieldtype': 'Small Text',
          },
        ];
      case 'ToDo':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'description',
            'label': 'Description / Task',
            'fieldtype': 'Small Text',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'status',
            'label': 'Status',
            'fieldtype': 'Select',
            'options': 'Open\nClosed\nCancelled',
            'default': 'Open',
          },
          <String, dynamic>{
            'fieldname': 'priority',
            'label': 'Priority',
            'fieldtype': 'Select',
            'options': 'Low\nMedium\nHigh',
            'default': 'Medium',
          },
          <String, dynamic>{
            'fieldname': 'date',
            'label': 'Due Date',
            'fieldtype': 'Date',
          },
          <String, dynamic>{
            'fieldname': 'allocated_to',
            'label': 'Allocated To',
            'fieldtype': 'Link',
            'options': 'User',
          },
          <String, dynamic>{
            'fieldname': 'reference_type',
            'label': 'Reference DocType',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'reference_name',
            'label': 'Reference Name',
            'fieldtype': 'Data',
          },
        ];
      case 'FCRM Note':
      case 'CRM Note':
      case 'Note':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'fieldname': 'title',
            'label': 'Title',
            'fieldtype': 'Data',
            'reqd': 1,
          },
          <String, dynamic>{
            'fieldname': 'content',
            'label': 'Content',
            'fieldtype': 'Text Editor',
          },
          <String, dynamic>{
            'fieldname': 'reference_doctype',
            'label': 'Reference DocType',
            'fieldtype': 'Data',
          },
          <String, dynamic>{
            'fieldname': 'reference_docname',
            'label': 'Reference Name',
            'fieldtype': 'Data',
          },
        ];
      default:
        return <Map<String, dynamic>>[];
    }
  }

  /// Searches records of a linked DocType (`frappe.desk.search.search_link` or `getList`)
  /// so Link fields can display a live dropdown/picker of allowed ERPNext records.
  Future<List<String>> searchLinkOptions(
    String linkDocType, {
    String query = '',
  }) async {
    if (linkDocType.trim().isEmpty) {
      return <String>[];
    }
    if (!_isDemoSession) {
      try {
        final Response<dynamic> res = await _dio.get<dynamic>(
          '/api/method/frappe.desk.search.search_link',
          queryParameters: <String, dynamic>{
            'doctype': linkDocType,
            'txt': query,
            'page_length': 40,
          },
        );
        final Map<String, dynamic> body =
            (res.data as Map<String, dynamic>?) ?? <String, dynamic>{};
        final List<dynamic> list =
            (body['message'] as List<dynamic>?) ??
            (body['results'] as List<dynamic>?) ??
            <dynamic>[];
        final List<String> vals = list
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> r) => (r['value'] ?? '').toString())
            .where((String s) => s.isNotEmpty)
            .toList();
        if (vals.isNotEmpty) {
          return vals;
        }
      } catch (_) {}
    }

    try {
      final List<Map<String, dynamic>> rows = await getList(
        linkDocType,
        fields: const <String>['name'],
        listFilters: query.trim().isNotEmpty
            ? <List<dynamic>>[
                <dynamic>['name', 'like', '%${query.trim()}%'],
              ]
            : null,
        limitPageLength: 50,
      );
      return rows
          .map((Map<String, dynamic> r) => (r['name'] ?? '').toString())
          .where((String s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<Map<String, dynamic>> createDoc(
    String doctype,
    Map<String, dynamic> payload,
  ) async {
    final Map<String, dynamic> enriched = _applySmartServerDefaults(
      doctype,
      payload,
    );
    if (_isDemoSession) {
      final Map<String, dynamic> created = <String, dynamic>{
        'name':
            '${doctype.substring(0, doctype.length.clamp(0, 4)).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 10000}',
        ...enriched,
      };
      _getMutableDemoList(doctype).insert(0, created);
      return created;
    }
    final Response<dynamic> res = await _dio.post<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}',
      data: enriched,
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
      final List<Map<String, dynamic>> list = _getMutableDemoList(doctype);
      final int idx = list.indexWhere(
        (Map<String, dynamic> e) => e['name'] == name,
      );
      if (idx >= 0) {
        list[idx] = <String, dynamic>{...list[idx], ...payload, 'name': name};
        return list[idx];
      }
      final Map<String, dynamic> updated = <String, dynamic>{
        'name': name,
        ...payload,
      };
      list.insert(0, updated);
      return updated;
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

  Future<void> deleteDoc(String doctype, String name) async {
    if (_isDemoSession) {
      _getMutableDemoList(doctype)
          .removeWhere((Map<String, dynamic> e) => e['name'] == name);
      return;
    }
    await _dio.delete<dynamic>(
      '/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(name)}',
    );
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
