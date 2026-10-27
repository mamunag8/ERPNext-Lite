import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';
import '../network/api_client.dart';

/// Metadata definition for any reorderable Dashboard item (Module Card, HR Tool, or Shortcut).
class SmartDashboardItemSpec {
  const SmartDashboardItemSpec({
    required this.id,
    required this.title,
    required this.primaryDocType,
    this.fallbackDocTypes = const <String>[],
    this.matchingRoles = const <String>[],
    this.defaultOrder = 0,
    this.alwaysAvailable = false,
  });

  final String id;
  final String title;
  final String primaryDocType;
  final List<String> fallbackDocTypes;
  final List<String> matchingRoles;
  final int defaultOrder;
  final bool alwaysAvailable;
}

/// 3-Layer Smart Adaptive Dashboard Engine for ERPNext Lite.
///
/// Automatically filters and rearranges dashboard modules, HR tools, and DocType
/// shortcuts per user (`serverUrl + email`) based on:
/// 1. Available server tools & active ERPNext DocTypes
/// 2. Live ERPNext user permissions (`read`, `write`, `create`, `submit`) & roles
/// 3. Real-time user usage frequency & recency (`SharedPreferences` per user)
class SmartDashboardService extends ChangeNotifier {
  SmartDashboardService._();

  static final SmartDashboardService instance = SmartDashboardService._();

  String _activeUserKey = '';
  bool _loaded = false;
  bool _probingPermissions = false;
  bool _hideUnpermitted = true;

  final Map<String, int> _usageCounts = <String, int>{};
  final Map<String, int> _lastUsedEpochMs = <String, int>{};
  final Set<String> _pinnedIds = <String>{};
  final Map<String, Map<String, int>> _docTypePermissions =
      <String, Map<String, int>>{};

  bool get hideUnpermitted => _hideUnpermitted;
  bool get isProbingPermissions => _probingPermissions;

  /// Maps any ERPNext DocType name to its parent Module ID and Shortcut IDs.
  static const Map<String, List<String>> _docTypeToItemIds =
      <String, List<String>>{
        'ToDo': <String>['mod_todo', 'sc_todo'],
        'CRM Task': <String>['mod_todo', 'mod_crm'],
        'Comment': <String>['mod_todo'],
        'CRM Note': <String>['mod_todo', 'mod_crm'],
        'FCRM Note': <String>['mod_crm'],
        'Note': <String>['mod_crm'],
        'CRM Lead': <String>['mod_crm', 'sc_crm'],
        'Lead': <String>['mod_crm', 'sc_crm'],
        'CRM Deal': <String>['mod_crm', 'sc_crm'],
        'Opportunity': <String>['mod_crm', 'sc_crm'],
        'Employee Checkin': <String>['mod_attendance', 'hr_1'],
        'Attendance': <String>['mod_attendance', 'hr_1', 'hr_2'],
        'Employee': <String>['mod_attendance', 'hr_1', 'hr_2'],
        'Shift Request': <String>['mod_attendance'],
        'Leave Application': <String>['mod_claims', 'hr_3'],
        'Leave Allocation': <String>['mod_claims', 'hr_3'],
        'Leave Policy Assignment': <String>['mod_claims', 'hr_3'],
        'Expense Claim': <String>['mod_claims', 'hr_5', 'sc_expense_claim'],
        'Employee Advance': <String>[
          'mod_claims',
          'hr_4',
          'sc_employee_advance',
        ],
        'Salary Slip': <String>['mod_payroll', 'hr_8'],
        'Payroll Entry': <String>['mod_payroll', 'hr_6'],
        'Salary Structure': <String>['mod_payroll', 'hr_7'],
        'Salary Structure Assignment': <String>['mod_payroll', 'hr_7'],
        'Additional Salary': <String>['mod_payroll', 'hr_9'],
        'Sales Invoice': <String>['mod_sales', 'sc_sales_invoice'],
        'Sales Order': <String>['mod_sales', 'sc_sales_order'],
        'Quotation': <String>['mod_sales'],
        'Payment Entry': <String>['mod_sales'],
        'Journal Entry': <String>['mod_sales', 'sc_journal_entry'],
        'Project': <String>['mod_projects', 'sc_projects'],
        'Task': <String>['mod_projects', 'sc_tasks'],
        'Timesheet': <String>['mod_projects'],
        'Material Request': <String>['mod_projects', 'sc_material_request'],
        'Delivery Note': <String>['mod_projects', 'sc_delivery_note'],
        'Item': <String>['mod_projects', 'sc_stock_balance'],
        'Purchase Order': <String>['mod_buying', 'sc_purchase_order'],
        'Purchase Receipt': <String>['mod_buying'],
        'Purchase Invoice': <String>['mod_buying'],
        'Supplier': <String>['mod_buying'],
        'Asset': <String>['mod_buying', 'sc_assets'],
        'Asset Movement': <String>['mod_buying', 'sc_assets'],
      };

  static const List<String> _probedDocTypes = <String>[
    'ToDo',
    'CRM Lead',
    'Lead',
    'Employee Checkin',
    'Attendance',
    'Leave Application',
    'Expense Claim',
    'Employee Advance',
    'Salary Slip',
    'Payroll Entry',
    'Salary Structure Assignment',
    'Additional Salary',
    'Sales Invoice',
    'Sales Order',
    'Journal Entry',
    'Project',
    'Task',
    'Material Request',
    'Delivery Note',
    'Item',
    'Purchase Order',
    'Asset',
  ];

  String _computeUserKey(UserSession? session) {
    if (session == null) {
      return 'guest';
    }
    final String srv = session.serverUrl
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    final String usr =
        (session.email.isNotEmpty ? session.email : session.username)
            .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            .toLowerCase();
    return '${srv}__$usr';
  }

  /// Ensures the active user's usage stats, pinned items, and cached permissions
  /// are loaded from `SharedPreferences`, then probes live ERPNext permissions.
  Future<void> ensureInitialized({bool forceProbe = false}) async {
    final UserSession? session = ErpApiClient.instance.session;
    final String key = _computeUserKey(session);
    if (_loaded && _activeUserKey == key && !forceProbe) {
      return;
    }

    _activeUserKey = key;
    _loaded = true;
    await _loadFromPrefs(key);
    notifyListeners();

    await probePermissionsInBackground(force: forceProbe);
  }

  Future<void> _loadFromPrefs(String userKey) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('smart_dash_v1_$userKey');
      _usageCounts.clear();
      _lastUsedEpochMs.clear();
      _pinnedIds.clear();
      _docTypePermissions.clear();
      _hideUnpermitted = true;

      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data =
            jsonDecode(raw) as Map<String, dynamic>;
        _hideUnpermitted = (data['hideUnpermitted'] as bool?) ?? true;
        if (data['usageCounts'] is Map) {
          (data['usageCounts'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            _usageCounts[k] = (v as num?)?.toInt() ?? 0;
          });
        }
        if (data['lastUsedEpochMs'] is Map) {
          (data['lastUsedEpochMs'] as Map<String, dynamic>).forEach((
            String k,
            dynamic v,
          ) {
            _lastUsedEpochMs[k] = (v as num?)?.toInt() ?? 0;
          });
        }
        if (data['pinnedIds'] is List) {
          for (final dynamic item in data['pinnedIds'] as List<dynamic>) {
            _pinnedIds.add(item.toString());
          }
        }
        if (data['docTypePermissions'] is Map) {
          (data['docTypePermissions'] as Map<String, dynamic>).forEach((
            String dt,
            dynamic permMap,
          ) {
            if (permMap is Map) {
              final Map<String, int> parsed = <String, int>{};
              permMap.forEach((dynamic pk, dynamic pv) {
                parsed[pk.toString()] = (pv as num?)?.toInt() ?? 0;
              });
              _docTypePermissions[dt] = parsed;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    if (_activeUserKey.isEmpty) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> payload = <String, dynamic>{
        'hideUnpermitted': _hideUnpermitted,
        'usageCounts': _usageCounts,
        'lastUsedEpochMs': _lastUsedEpochMs,
        'pinnedIds': _pinnedIds.toList(),
        'docTypePermissions': _docTypePermissions,
      };
      await prefs.setString(
        'smart_dash_v1_$_activeUserKey',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  /// Probes the connected ERPNext server for the current user's DocType permissions.
  Future<void> probePermissionsInBackground({bool force = false}) async {
    if (_probingPermissions) {
      return;
    }
    if (!force && _docTypePermissions.length >= 8) {
      return;
    }

    _probingPermissions = true;
    notifyListeners();

    try {
      for (final String dt in _probedDocTypes) {
        try {
          final Map<String, int> perms = await ErpApiClient.instance
              .getDocTypePermissions(dt);
          _docTypePermissions[dt] = perms;
        } catch (_) {}
      }
      await _saveToPrefs();
    } finally {
      _probingPermissions = false;
      notifyListeners();
    }
  }

  /// Toggles whether unpermitted modules/tools are hidden or shown at the bottom.
  Future<void> setHideUnpermitted(bool value) async {
    _hideUnpermitted = value;
    notifyListeners();
    await _saveToPrefs();
  }

  /// Pins or unpins a specific dashboard card/tool to the top of its section.
  Future<void> togglePin(String itemId) async {
    if (_pinnedIds.contains(itemId)) {
      _pinnedIds.remove(itemId);
    } else {
      _pinnedIds.add(itemId);
    }
    notifyListeners();
    await _saveToPrefs();
  }

  bool isPinned(String itemId) => _pinnedIds.contains(itemId);

  int usageCountOf(String itemId) => _usageCounts[itemId] ?? 0;

  int get totalInteractions {
    int sum = 0;
    for (final int v in _usageCounts.values) {
      sum += v;
    }
    return sum;
  }

  /// Records a direct user tap on a Dashboard card, HR tool chip, or Shortcut chip.
  Future<void> recordItemTap(
    String itemId, {
    String? primaryDocType,
    String? parentModuleId,
  }) async {
    await ensureInitialized();
    final int now = DateTime.now().millisecondsSinceEpoch;
    _usageCounts[itemId] = (_usageCounts[itemId] ?? 0) + 1;
    _lastUsedEpochMs[itemId] = now;

    if (parentModuleId != null &&
        parentModuleId.isNotEmpty &&
        parentModuleId != itemId) {
      _usageCounts[parentModuleId] = (_usageCounts[parentModuleId] ?? 0) + 1;
      _lastUsedEpochMs[parentModuleId] = now;
    }
    if (primaryDocType != null && primaryDocType.isNotEmpty) {
      final List<String>? linked = _docTypeToItemIds[primaryDocType];
      if (linked != null) {
        for (final String lid in linked) {
          if (lid != itemId && lid != parentModuleId) {
            _usageCounts[lid] = (_usageCounts[lid] ?? 0) + 1;
            _lastUsedEpochMs[lid] = now;
          }
        }
      }
    }

    notifyListeners();
    await _saveToPrefs();
  }

  /// Automatically called when a user views, creates, edits, or submits any DocType
  /// anywhere in the app so the dashboard adapts to their real workflow.
  Future<void> recordDocTypeInteraction(
    String doctype, {
    bool isMutation = false,
  }) async {
    await ensureInitialized();
    final List<String>? ids = _docTypeToItemIds[doctype];
    if (ids == null || ids.isEmpty) {
      return;
    }
    final int weight = isMutation ? 2 : 1;
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final String id in ids) {
      _usageCounts[id] = (_usageCounts[id] ?? 0) + weight;
      _lastUsedEpochMs[id] = now;
    }
    notifyListeners();
    await _saveToPrefs();
  }

  /// Resets usage counts and pinned items for the current user back to defaults.
  Future<void> resetUserStats() async {
    _usageCounts.clear();
    _lastUsedEpochMs.clear();
    _pinnedIds.clear();
    notifyListeners();
    await _saveToPrefs();
  }

  /// Returns merged permission map (`read`, `write`, `create`, `submit`) for a spec.
  Map<String, int> permissionsForSpec(SmartDashboardItemSpec spec) {
    if (spec.alwaysAvailable) {
      return const <String, int>{
        'read': 1,
        'write': 1,
        'create': 1,
        'submit': 1,
      };
    }

    final List<String> candidates = <String>[
      spec.primaryDocType,
      ...spec.fallbackDocTypes,
    ];
    bool anyFoundInCache = false;
    int read = 0;
    int write = 0;
    int create = 0;
    int submit = 0;

    for (final String dt in candidates) {
      if (dt.isEmpty) {
        continue;
      }
      final Map<String, int>? p = _docTypePermissions[dt];
      if (p != null) {
        anyFoundInCache = true;
        if ((p['read'] ?? 0) == 1) {
          read = 1;
        }
        if ((p['write'] ?? 0) == 1) {
          write = 1;
        }
        if ((p['create'] ?? 0) == 1) {
          create = 1;
        }
        if ((p['submit'] ?? 0) == 1) {
          submit = 1;
        }
      }
    }

    if (!anyFoundInCache) {
      return const <String, int>{
        'read': 1,
        'write': 1,
        'create': 1,
        'submit': 0,
      };
    }

    return <String, int>{
      'read': read,
      'write': write,
      'create': create,
      'submit': submit,
    };
  }

  bool isSpecPermitted(SmartDashboardItemSpec spec) {
    if (spec.alwaysAvailable) {
      return true;
    }
    final Map<String, int> perms = permissionsForSpec(spec);
    return (perms['read'] ?? 1) == 1;
  }

  String accessBadgeForSpec(SmartDashboardItemSpec spec) {
    if (spec.alwaysAvailable) {
      return 'Full Access';
    }
    final Map<String, int> perms = permissionsForSpec(spec);
    if ((perms['read'] ?? 1) == 0) {
      return 'No Access';
    }
    if ((perms['create'] ?? 0) == 1 || (perms['write'] ?? 0) == 1) {
      return 'Full Access';
    }
    return 'View Only';
  }

  /// Computes the composite smart score for sorting dashboard items.
  double computeScore(SmartDashboardItemSpec spec) {
    final UserSession? session = ErpApiClient.instance.session;
    final Map<String, int> perms = permissionsForSpec(spec);
    final bool canRead = (perms['read'] ?? 1) == 1;

    double score = 0;

    // 1. User Pin Override
    if (_pinnedIds.contains(spec.id)) {
      score += 10000;
    }

    // 2. Permission Score
    if (!canRead) {
      score -= 1000;
    } else {
      score += 100;
      if ((perms['write'] ?? 0) == 1) {
        score += 30;
      }
      if ((perms['create'] ?? 0) == 1) {
        score += 40;
      }
      if ((perms['submit'] ?? 0) == 1) {
        score += 20;
      }
    }

    // 3. Role Match Boost
    if (session != null &&
        session.roles.isNotEmpty &&
        spec.matchingRoles.isNotEmpty) {
      final Set<String> lowerUserRoles = session.roles
          .map((String r) => r.toLowerCase())
          .toSet();
      final bool matchedRole = spec.matchingRoles.any(
        (String r) => lowerUserRoles.contains(r.toLowerCase()),
      );
      if (matchedRole) {
        score += 60;
      }
    }

    // 4. Server App Availability Boost (e.g., Frappe CRM active)
    if (session != null && session.hasFcrm && spec.id == 'mod_crm') {
      score += 15;
    }

    // 5. Usage Frequency & Recency Score
    final int count = _usageCounts[spec.id] ?? 0;
    score += count * 25;

    final int lastMs = _lastUsedEpochMs[spec.id] ?? 0;
    if (lastMs > 0) {
      final int elapsedMs = DateTime.now().millisecondsSinceEpoch - lastMs;
      const int oneHourMs = 3600 * 1000;
      const int oneDayMs = 24 * oneHourMs;
      const int sevenDaysMs = 7 * oneDayMs;
      if (elapsedMs <= oneHourMs) {
        score += 80;
      } else if (elapsedMs <= oneDayMs) {
        score += 50;
      } else if (elapsedMs <= sevenDaysMs) {
        score += 25;
      }
    }

    // Tie-breaker: preserve clean default order when scores are equal
    score -= spec.defaultOrder * 0.1;
    return score;
  }

  /// Filters and sorts a list of [SmartDashboardItemSpec] items in descending
  /// order of their smart score.
  List<T> filterAndSort<T>(
    List<T> items,
    SmartDashboardItemSpec Function(T item) specOf,
  ) {
    final List<T> visible = _hideUnpermitted
        ? items.where((T item) => isSpecPermitted(specOf(item))).toList()
        : List<T>.from(items);

    visible.sort((T a, T b) {
      final double scoreA = computeScore(specOf(a));
      final double scoreB = computeScore(specOf(b));
      return scoreB.compareTo(scoreA);
    });
    return visible;
  }
}
