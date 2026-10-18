import 'dart:convert';

class GeoBranchLocation {
  const GeoBranchLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 250,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };

  factory GeoBranchLocation.fromJson(Map<String, dynamic> json) {
    return GeoBranchLocation(
      name: (json['name'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 23.8103,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 90.4125,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 250,
    );
  }
}

class UserSession {
  const UserSession({
    required this.serverUrl,
    required this.username,
    required this.fullName,
    required this.email,
    required this.authType,
    this.employeeId = '',
    this.employeeName = '',
    this.designation = '',
    this.department = '',
    this.company = 'Drip Irrigation BD Ltd',
    this.currency = 'BDT',
    this.branch = '',
    this.costCenter = '',
    this.expenseApprover = '',
    this.leaveApprover = '',
    this.roles = const <String>[],
    this.hasFcrm = false,
    this.isDiblCustomized = false,
    this.departments = const <String>[],
    this.costCenters = const <String>[],
    this.projects = const <String>[],
    this.warehouses = const <String>[],
  });

  final String serverUrl;
  final String username;
  final String fullName;
  final String email;
  final String authType; // 'password' or 'api_key'
  final String employeeId;
  final String employeeName;
  final String designation;
  final String department;
  final String company;
  final String currency;
  final String branch;
  final String costCenter;
  final String expenseApprover;
  final String leaveApprover;
  final List<String> roles;
  final bool hasFcrm;
  final bool isDiblCustomized;
  final List<String> departments;
  final List<String> costCenters;
  final List<String> projects;
  final List<String> warehouses;

  bool get isApprover =>
      roles.contains('HR Manager') ||
      roles.contains('HR User') ||
      roles.contains('Expense Approver') ||
      roles.contains('Leave Approver') ||
      roles.contains('System Manager') ||
      roles.contains('Projects Manager') ||
      roles.contains('Accounts Manager');

  String get currencySymbol {
    if (currency.toUpperCase() == 'BDT') {
      return '৳';
    }
    if (currency.toUpperCase() == 'USD') {
      return r'$';
    }
    if (currency.toUpperCase() == 'EUR') {
      return '€';
    }
    return currency;
  }

  UserSession copyWith({
    String? serverUrl,
    String? username,
    String? fullName,
    String? email,
    String? authType,
    String? employeeId,
    String? employeeName,
    String? designation,
    String? department,
    String? company,
    String? currency,
    String? branch,
    String? costCenter,
    String? expenseApprover,
    String? leaveApprover,
    List<String>? roles,
    bool? hasFcrm,
    bool? isDiblCustomized,
    List<String>? departments,
    List<String>? costCenters,
    List<String>? projects,
    List<String>? warehouses,
  }) {
    return UserSession(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      authType: authType ?? this.authType,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      company: company ?? this.company,
      currency: currency ?? this.currency,
      branch: branch ?? this.branch,
      costCenter: costCenter ?? this.costCenter,
      expenseApprover: expenseApprover ?? this.expenseApprover,
      leaveApprover: leaveApprover ?? this.leaveApprover,
      roles: roles ?? this.roles,
      hasFcrm: hasFcrm ?? this.hasFcrm,
      isDiblCustomized: isDiblCustomized ?? this.isDiblCustomized,
      departments: departments ?? this.departments,
      costCenters: costCenters ?? this.costCenters,
      projects: projects ?? this.projects,
      warehouses: warehouses ?? this.warehouses,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'serverUrl': serverUrl,
    'username': username,
    'fullName': fullName,
    'email': email,
    'authType': authType,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'designation': designation,
    'department': department,
    'company': company,
    'currency': currency,
    'branch': branch,
    'costCenter': costCenter,
    'expenseApprover': expenseApprover,
    'leaveApprover': leaveApprover,
    'roles': roles,
    'hasFcrm': hasFcrm,
    'isDiblCustomized': isDiblCustomized,
    'departments': departments,
    'costCenters': costCenters,
    'projects': projects,
    'warehouses': warehouses,
  };

  String toEncodedJson() => jsonEncode(toJson());

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      serverUrl: (json['serverUrl'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      authType: (json['authType'] ?? 'password').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      designation: (json['designation'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      company: (json['company'] ?? 'Drip Irrigation BD Ltd').toString(),
      currency: (json['currency'] ?? 'BDT').toString(),
      branch: (json['branch'] ?? '').toString(),
      costCenter: (json['costCenter'] ?? '').toString(),
      expenseApprover: (json['expenseApprover'] ?? '').toString(),
      leaveApprover: (json['leaveApprover'] ?? '').toString(),
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      hasFcrm: json['hasFcrm'] == true,
      isDiblCustomized: json['isDiblCustomized'] == true,
      departments:
          (json['departments'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      costCenters:
          (json['costCenters'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      projects:
          (json['projects'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      warehouses:
          (json['warehouses'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }

  factory UserSession.fromEncodedJson(String encoded) {
    return UserSession.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  static const List<GeoBranchLocation> defaultBranches = <GeoBranchLocation>[
    GeoBranchLocation(
      name: 'Head Office / Dhaka (DIBL)',
      latitude: 23.7925,
      longitude: 90.4078,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Chattogram Branch',
      latitude: 22.3569,
      longitude: 91.7832,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Jashore Branch',
      latitude: 23.1634,
      longitude: 89.2182,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Bogura Branch',
      latitude: 24.8481,
      longitude: 89.3730,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Sylhet Branch',
      latitude: 24.8949,
      longitude: 91.8687,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Barisal Branch',
      latitude: 22.7010,
      longitude: 90.3535,
      radiusMeters: 300,
    ),
    GeoBranchLocation(
      name: 'Rangpur Branch',
      latitude: 25.7439,
      longitude: 89.2752,
      radiusMeters: 300,
    ),
  ];
}
