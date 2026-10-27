import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/services/smart_dashboard_service.dart';
import '../buying_assets/buying_assets_screen.dart';
import '../crm/crm_screen.dart';
import '../explorer/doctype_explorer_screen.dart';
import '../hr/attendance_screen.dart';
import '../hr/leave_claims_screen.dart';
import '../payroll/payroll_screen.dart';
import '../projects/projects_stock_screen.dart';
import '../sales/sales_billing_screen.dart';
import '../todo/quick_todo_screen.dart';

class _DashboardModuleEntry {
  const _DashboardModuleEntry({
    required this.spec,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onOpen,
  });

  final SmartDashboardItemSpec spec;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onOpen;
}

class _DashboardQuickChipEntry {
  const _DashboardQuickChipEntry({
    required this.spec,
    required this.icon,
    required this.parentModuleId,
    required this.onOpen,
  });

  final SmartDashboardItemSpec spec;
  final IconData icon;
  final String parentModuleId;
  final VoidCallback onOpen;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const Map<int, String> _tabToModuleId = <int, String>{
    1: 'mod_todo',
    2: 'mod_crm',
    3: 'mod_attendance',
    4: 'mod_claims',
    5: 'mod_sales',
  };

  void _selectTab(int idx) {
    setState(() => _selectedIndex = idx);
    final String? modId = _tabToModuleId[idx];
    if (modId != null) {
      SmartDashboardService.instance.recordItemTap(modId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      _DashboardTab(onNavigateTab: _selectTab),
      const QuickTodoScreen(),
      const CrmAndTasksScreen(),
      const AttendanceScreen(),
      const LeaveAndClaimsScreen(),
      const SalesBillingScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _selectTab,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: 'ToDo',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake_rounded),
            label: 'CRM',
          ),
          NavigationDestination(
            icon: Icon(Icons.pin_drop_outlined),
            selectedIcon: Icon(Icons.pin_drop_rounded),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({required this.onNavigateTab});

  final ValueChanged<int> onNavigateTab;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _syncing = false;
  bool _addingTodo = false;
  final TextEditingController _quickTodoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SmartDashboardService.instance.ensureInitialized();
  }

  @override
  void dispose() {
    _quickTodoCtrl.dispose();
    super.dispose();
  }

  Future<void> _addQuickHomeTodo() async {
    final String text = _quickTodoCtrl.text.trim();
    if (text.isEmpty) {
      widget.onNavigateTab(1);
      return;
    }
    setState(() => _addingTodo = true);
    final UserSession? session = ErpApiClient.instance.session;
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await ErpApiClient.instance.createDoc('ToDo', <String, dynamic>{
        'description': text,
        'priority': 'High',
        'status': 'Open',
        'date': todayStr,
        if (session != null && session.email.isNotEmpty)
          'allocated_to': session.email,
      });
      _quickTodoCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: const Text('Quick ToDo added!'),
            action: SnackBarAction(
              label: 'View ToDo Dock',
              textColor: Colors.white,
              onPressed: () => widget.onNavigateTab(1),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingTodo = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          'Your ERPNext session is saved permanently. Logging out will clear stored credentials from this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ErpApiClient.instance.logout();
    }
  }

  List<_DashboardModuleEntry> _buildModuleCatalog(
    BuildContext context,
    UserSession? session,
  ) {
    final bool hasFcrm = session?.hasFcrm ?? true;
    return <_DashboardModuleEntry>[
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_todo',
          title: 'Quick ToDo & Activity',
          primaryDocType: 'ToDo',
          fallbackDocTypes: <String>['CRM Task', 'Comment'],
          defaultOrder: 0,
          alwaysAvailable: true,
        ),
        subtitle: '1-Tap Task Dock, Priority & Activity Log',
        icon: Icons.task_alt_rounded,
        color: Colors.amber.shade800,
        onOpen: () => widget.onNavigateTab(1),
      ),
      _DashboardModuleEntry(
        spec: SmartDashboardItemSpec(
          id: 'mod_crm',
          title: hasFcrm ? 'Frappe CRM Pipeline' : 'CRM & Leads Pipeline',
          primaryDocType: 'CRM Lead',
          fallbackDocTypes: const <String>['Lead', 'CRM Deal', 'Opportunity'],
          matchingRoles: const <String>[
            'Sales User',
            'Sales Manager',
            'Sales Master Manager',
            'System Manager',
          ],
          defaultOrder: 1,
        ),
        subtitle: 'Leads, Deals, 1-Tap Stage Move & Follow-up',
        icon: Icons.handshake_rounded,
        color: Colors.orange.shade800,
        onOpen: () => widget.onNavigateTab(2),
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_attendance',
          title: 'HR & Attendance',
          primaryDocType: 'Employee Checkin',
          fallbackDocTypes: <String>['Attendance', 'Employee', 'Shift Request'],
          matchingRoles: <String>['Employee', 'HR User', 'HR Manager'],
          defaultOrder: 2,
        ),
        subtitle: 'Check-In, Attendance Tool, Monthly Sheet & Shifts',
        icon: Icons.how_to_reg_rounded,
        color: Colors.teal,
        onOpen: () => widget.onNavigateTab(3),
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_claims',
          title: 'Leave & Claims',
          primaryDocType: 'Leave Application',
          fallbackDocTypes: <String>['Expense Claim', 'Employee Advance'],
          matchingRoles: <String>[
            'Employee',
            'Leave Approver',
            'Expense Approver',
            'HR User',
            'HR Manager',
          ],
          defaultOrder: 3,
        ),
        subtitle: 'Leave Approval, Expense Receipt & Advance',
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.indigo,
        onOpen: () => widget.onNavigateTab(4),
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_payroll',
          title: 'Payroll & Salary Ops',
          primaryDocType: 'Salary Slip',
          fallbackDocTypes: <String>[
            'Payroll Entry',
            'Salary Structure Assignment',
            'Additional Salary',
          ],
          matchingRoles: <String>[
            'HR Manager',
            'HR User',
            'Accounts Manager',
            'Employee',
          ],
          defaultOrder: 4,
        ),
        subtitle: 'Slips, Payroll Entry, Structure & Additional Salary',
        icon: Icons.picture_as_pdf_rounded,
        color: Colors.deepPurple,
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PayrollScreen()),
          );
        },
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_sales',
          title: 'Sales & Accounts',
          primaryDocType: 'Sales Invoice',
          fallbackDocTypes: <String>[
            'Sales Order',
            'Quotation',
            'Payment Entry',
            'Journal Entry',
          ],
          matchingRoles: <String>[
            'Sales User',
            'Sales Manager',
            'Accounts User',
            'Accounts Manager',
          ],
          defaultOrder: 5,
        ),
        subtitle: 'Invoice, Order, Quote, Payment & Journal Entry',
        icon: Icons.receipt_rounded,
        color: Colors.blue.shade700,
        onOpen: () => widget.onNavigateTab(5),
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_projects',
          title: 'Projects & Stock',
          primaryDocType: 'Project',
          fallbackDocTypes: <String>[
            'Task',
            'Timesheet',
            'Material Request',
            'Delivery Note',
            'Item',
          ],
          matchingRoles: <String>[
            'Projects User',
            'Projects Manager',
            'Stock User',
            'Stock Manager',
          ],
          defaultOrder: 6,
        ),
        subtitle: 'Projects, Tasks, Timesheet, Delivery & Bin Stock',
        icon: Icons.engineering_rounded,
        color: Colors.green.shade700,
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(),
            ),
          );
        },
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_buying',
          title: 'Buying & Assets',
          primaryDocType: 'Purchase Order',
          fallbackDocTypes: <String>[
            'Purchase Receipt',
            'Purchase Invoice',
            'Supplier',
            'Asset',
          ],
          matchingRoles: <String>[
            'Purchase User',
            'Purchase Manager',
            'Purchase Master Manager',
            'Accounts User',
          ],
          defaultOrder: 7,
        ),
        subtitle: 'Purchase Order/Receipt/Invoice, Supplier & Assets',
        icon: Icons.precision_manufacturing_rounded,
        color: Colors.brown.shade700,
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const BuyingAndAssetsScreen(),
            ),
          );
        },
      ),
      _DashboardModuleEntry(
        spec: const SmartDashboardItemSpec(
          id: 'mod_explorer',
          title: 'All DocTypes Explorer',
          primaryDocType: 'Customer',
          defaultOrder: 8,
          alwaysAvailable: true,
        ),
        subtitle: 'Browse, Inspect, PDF & Create Any ERPNext DocType',
        icon: Icons.dataset_linked_rounded,
        color: Colors.cyan.shade800,
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DocTypeExplorerScreen(),
            ),
          );
        },
      ),
    ];
  }

  List<_DashboardQuickChipEntry> _buildHrToolsCatalog(BuildContext context) {
    return <_DashboardQuickChipEntry>[
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_1',
          title: '1. Employee Attendance Tool',
          primaryDocType: 'Attendance',
          fallbackDocTypes: <String>['Employee Checkin'],
          matchingRoles: <String>['HR Manager', 'HR User'],
          defaultOrder: 0,
        ),
        icon: Icons.fact_check_rounded,
        parentModuleId: 'mod_attendance',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AttendanceScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_2',
          title: '2. Monthly Attendance Sheet',
          primaryDocType: 'Attendance',
          fallbackDocTypes: <String>['Employee Checkin'],
          matchingRoles: <String>['Employee', 'HR User', 'HR Manager'],
          defaultOrder: 1,
        ),
        icon: Icons.calendar_month_rounded,
        parentModuleId: 'mod_attendance',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AttendanceScreen(initialTab: 2),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_3',
          title: '3. Leave Application Mgmt',
          primaryDocType: 'Leave Application',
          fallbackDocTypes: <String>['Leave Allocation'],
          matchingRoles: <String>['Employee', 'Leave Approver', 'HR Manager'],
          defaultOrder: 2,
        ),
        icon: Icons.beach_access_rounded,
        parentModuleId: 'mod_claims',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LeaveAndClaimsScreen(initialTab: 0),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_4',
          title: '4. Employee Advance Mgmt',
          primaryDocType: 'Employee Advance',
          matchingRoles: <String>['Employee', 'Expense Approver', 'HR Manager'],
          defaultOrder: 3,
        ),
        icon: Icons.account_balance_wallet_rounded,
        parentModuleId: 'mod_claims',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LeaveAndClaimsScreen(initialTab: 2),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_5',
          title: '5. Expense Claim Mgmt',
          primaryDocType: 'Expense Claim',
          matchingRoles: <String>['Employee', 'Expense Approver', 'HR Manager'],
          defaultOrder: 4,
        ),
        icon: Icons.receipt_long_rounded,
        parentModuleId: 'mod_claims',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LeaveAndClaimsScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_6',
          title: '6. Payroll Entry',
          primaryDocType: 'Payroll Entry',
          matchingRoles: <String>['HR Manager', 'Accounts Manager'],
          defaultOrder: 5,
        ),
        icon: Icons.account_balance_rounded,
        parentModuleId: 'mod_payroll',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PayrollScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_7',
          title: '7. Salary Structure Assign',
          primaryDocType: 'Salary Structure Assignment',
          fallbackDocTypes: <String>['Salary Structure'],
          matchingRoles: <String>['HR Manager', 'HR User'],
          defaultOrder: 6,
        ),
        icon: Icons.assignment_ind_rounded,
        parentModuleId: 'mod_payroll',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PayrollScreen(initialTab: 2),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_8',
          title: '8. Salary Slip Generation',
          primaryDocType: 'Salary Slip',
          matchingRoles: <String>['Employee', 'HR User', 'HR Manager'],
          defaultOrder: 7,
        ),
        icon: Icons.picture_as_pdf_rounded,
        parentModuleId: 'mod_payroll',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PayrollScreen(initialTab: 0),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'hr_9',
          title: '9. Additional Salary Slip',
          primaryDocType: 'Additional Salary',
          matchingRoles: <String>['HR Manager', 'HR User'],
          defaultOrder: 8,
        ),
        icon: Icons.add_card_rounded,
        parentModuleId: 'mod_payroll',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PayrollScreen(initialTab: 3),
            ),
          );
        },
      ),
    ];
  }

  List<_DashboardQuickChipEntry> _buildShortcutsCatalog(BuildContext context) {
    return <_DashboardQuickChipEntry>[
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_todo',
          title: 'Quick ToDo Dock',
          primaryDocType: 'ToDo',
          defaultOrder: 0,
          alwaysAvailable: true,
        ),
        icon: Icons.task_alt_rounded,
        parentModuleId: 'mod_todo',
        onOpen: () => widget.onNavigateTab(1),
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_crm',
          title: 'Frappe CRM Pipeline',
          primaryDocType: 'CRM Lead',
          fallbackDocTypes: <String>['Lead', 'CRM Deal', 'Opportunity'],
          matchingRoles: <String>['Sales User', 'Sales Manager'],
          defaultOrder: 1,
        ),
        icon: Icons.handshake_rounded,
        parentModuleId: 'mod_crm',
        onOpen: () => widget.onNavigateTab(2),
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_sales_invoice',
          title: 'Sales Invoices',
          primaryDocType: 'Sales Invoice',
          matchingRoles: <String>[
            'Sales User',
            'Accounts User',
            'Accounts Manager',
          ],
          defaultOrder: 2,
        ),
        icon: Icons.receipt_long,
        parentModuleId: 'mod_sales',
        onOpen: () => widget.onNavigateTab(5),
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_sales_order',
          title: 'Sales Orders',
          primaryDocType: 'Sales Order',
          matchingRoles: <String>['Sales User', 'Sales Manager'],
          defaultOrder: 3,
        ),
        icon: Icons.shopping_cart_checkout,
        parentModuleId: 'mod_sales',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const SalesBillingScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_employee_advance',
          title: 'Employee Advance',
          primaryDocType: 'Employee Advance',
          matchingRoles: <String>['Employee', 'Expense Approver', 'HR Manager'],
          defaultOrder: 4,
        ),
        icon: Icons.payments_outlined,
        parentModuleId: 'mod_claims',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LeaveAndClaimsScreen(initialTab: 2),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_projects',
          title: 'Projects',
          primaryDocType: 'Project',
          matchingRoles: <String>['Projects User', 'Projects Manager'],
          defaultOrder: 5,
        ),
        icon: Icons.folder_open,
        parentModuleId: 'mod_projects',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_tasks',
          title: 'Tasks',
          primaryDocType: 'Task',
          matchingRoles: <String>['Projects User', 'Projects Manager'],
          defaultOrder: 6,
        ),
        icon: Icons.task_alt,
        parentModuleId: 'mod_projects',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_expense_claim',
          title: 'Expense Claims',
          primaryDocType: 'Expense Claim',
          matchingRoles: <String>['Employee', 'Expense Approver', 'HR Manager'],
          defaultOrder: 7,
        ),
        icon: Icons.attach_money,
        parentModuleId: 'mod_claims',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LeaveAndClaimsScreen(initialTab: 1),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_journal_entry',
          title: 'Journal Entry',
          primaryDocType: 'Journal Entry',
          matchingRoles: <String>['Accounts User', 'Accounts Manager'],
          defaultOrder: 8,
        ),
        icon: Icons.account_balance_rounded,
        parentModuleId: 'mod_sales',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const SalesBillingScreen(initialTab: 4),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_material_request',
          title: 'Material Request',
          primaryDocType: 'Material Request',
          matchingRoles: <String>['Stock User', 'Projects User'],
          defaultOrder: 9,
        ),
        icon: Icons.local_shipping_outlined,
        parentModuleId: 'mod_projects',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(initialTab: 3),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_delivery_note',
          title: 'Delivery Note',
          primaryDocType: 'Delivery Note',
          matchingRoles: <String>['Stock User', 'Sales User'],
          defaultOrder: 10,
        ),
        icon: Icons.assignment_turned_in_outlined,
        parentModuleId: 'mod_projects',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(initialTab: 4),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_stock_balance',
          title: 'Stock Balance (Bin)',
          primaryDocType: 'Item',
          matchingRoles: <String>['Stock User', 'Stock Manager'],
          defaultOrder: 11,
        ),
        icon: Icons.warehouse_outlined,
        parentModuleId: 'mod_projects',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProjectsAndStockScreen(initialTab: 5),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_purchase_order',
          title: 'Purchase Order',
          primaryDocType: 'Purchase Order',
          matchingRoles: <String>['Purchase User', 'Purchase Manager'],
          defaultOrder: 12,
        ),
        icon: Icons.shopping_bag_outlined,
        parentModuleId: 'mod_buying',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const BuyingAndAssetsScreen(initialTab: 0),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_assets',
          title: 'Assets & Movement',
          primaryDocType: 'Asset',
          fallbackDocTypes: <String>['Asset Movement'],
          matchingRoles: <String>['Accounts User', 'Purchase User'],
          defaultOrder: 13,
        ),
        icon: Icons.precision_manufacturing_outlined,
        parentModuleId: 'mod_buying',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const BuyingAndAssetsScreen(initialTab: 4),
            ),
          );
        },
      ),
      _DashboardQuickChipEntry(
        spec: const SmartDashboardItemSpec(
          id: 'sc_all_doctypes',
          title: 'All DocTypes',
          primaryDocType: 'Customer',
          defaultOrder: 14,
          alwaysAvailable: true,
        ),
        icon: Icons.table_chart_outlined,
        parentModuleId: 'mod_explorer',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DocTypeExplorerScreen(),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SmartDashboardService smart = SmartDashboardService.instance;

    return ListenableBuilder(
      listenable: smart,
      builder: (BuildContext context, _) {
        final List<_DashboardModuleEntry> allModules = _buildModuleCatalog(
          context,
          session,
        );
        final List<_DashboardModuleEntry> sortedModules = smart
            .filterAndSort<_DashboardModuleEntry>(
              allModules,
              (_DashboardModuleEntry e) => e.spec,
            );

        final List<_DashboardQuickChipEntry> allHrTools = _buildHrToolsCatalog(
          context,
        );
        final List<_DashboardQuickChipEntry> sortedHrTools = smart
            .filterAndSort<_DashboardQuickChipEntry>(
              allHrTools,
              (_DashboardQuickChipEntry e) => e.spec,
            );

        final List<_DashboardQuickChipEntry> allShortcuts =
            _buildShortcutsCatalog(context);
        final List<_DashboardQuickChipEntry> sortedShortcuts = smart
            .filterAndSort<_DashboardQuickChipEntry>(
              allShortcuts,
              (_DashboardQuickChipEntry e) => e.spec,
            );

        final List<_DashboardModuleEntry> topUsedModules = sortedModules
            .where(
              (_DashboardModuleEntry m) =>
                  smart.usageCountOf(m.spec.id) > 0 ||
                  smart.isPinned(m.spec.id),
            )
            .take(4)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        session?.company ?? 'ERPNext Lite',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ERPNext Lite',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  session?.serverUrl ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Quick ToDo & Activity Dock',
                icon: const Icon(Icons.task_alt_rounded),
                onPressed: () => widget.onNavigateTab(1),
              ),
              IconButton(
                tooltip: 'Sync Metadata & Permissions',
                icon: _syncing || smart.isProbingPermissions
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                onPressed: _syncing
                    ? null
                    : () async {
                        final ScaffoldMessengerState messenger =
                            ScaffoldMessenger.of(context);
                        setState(() => _syncing = true);
                        await ErpApiClient.instance.refreshSessionMetadata();
                        await smart.ensureInitialized(forceProbe: true);
                        if (!mounted) {
                          return;
                        }
                        setState(() => _syncing = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Workspace metadata & permissions synced!',
                            ),
                          ),
                        );
                      },
              ),
              IconButton(
                tooltip: 'Manual Logout',
                icon: const Icon(Icons.logout_rounded),
                onPressed: _confirmLogout,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Employee & Company Hero Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[colors.primary, colors.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                session?.employeeName.isNotEmpty == true
                                    ? session!.employeeName
                                    : (session?.fullName ?? 'ERPNext User'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${session?.designation.isNotEmpty == true ? '${session!.designation} • ' : ''}${session?.department.isNotEmpty == true ? session!.department : session?.email ?? ''}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                              if (session?.employeeId.isNotEmpty == true)
                                Text(
                                  'Employee ID: ${session!.employeeId} • Currency: ${session.currency}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: colors.primary,
                            ),
                            onPressed: () => widget.onNavigateTab(3),
                            icon: const Icon(
                              Icons.camera_front_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'Selfie Check-In',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (topUsedModules.isNotEmpty &&
                                  topUsedModules.first.spec.id !=
                                      'mod_attendance') {
                                final _DashboardModuleEntry top =
                                    topUsedModules.first;
                                smart.recordItemTap(
                                  top.spec.id,
                                  primaryDocType: top.spec.primaryDocType,
                                );
                                top.onOpen();
                              } else {
                                widget.onNavigateTab(1);
                              }
                            },
                            icon: Icon(
                              topUsedModules.isNotEmpty &&
                                      topUsedModules.first.spec.id !=
                                          'mod_attendance'
                                  ? topUsedModules.first.icon
                                  : Icons.task_alt_rounded,
                              size: 17,
                            ),
                            label: Text(
                              topUsedModules.isNotEmpty &&
                                      topUsedModules.first.spec.id !=
                                          'mod_attendance'
                                  ? topUsedModules.first.spec.title
                                  : 'Quick ToDo Dock',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Smart Adaptive Dashboard Control Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Smart Auto-Order • Sorted by your ERP access & frequency (${smart.totalInteractions} uses)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        smart.hideUnpermitted ? 'Permitted Only' : 'Show All',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: smart.hideUnpermitted,
                      visualDensity: VisualDensity.compact,
                      onSelected: (bool v) => smart.setHideUnpermitted(v),
                    ),
                    if (smart.totalInteractions > 0)
                      IconButton(
                        tooltip: 'Reset Smart Order',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        onPressed: () async {
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          await smart.resetUserStats();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Dashboard order reset to default!',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Top Frequently Used by You Bar (appears automatically as user works)
              if (topUsedModules.isNotEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Colors.deepOrange.shade700,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Frequently Used by You',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Hold any card to Pin 📌',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: topUsedModules.map((_DashboardModuleEntry m) {
                      final int count = smart.usageCountOf(m.spec.id);
                      final bool pinned = smart.isPinned(m.spec.id);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: Icon(m.icon, size: 16, color: m.color),
                          label: Text(
                            '${pinned ? '📌 ' : ''}${m.spec.title}${count > 0 ? ' ($count×)' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            smart.recordItemTap(
                              m.spec.id,
                              primaryDocType: m.spec.primaryDocType,
                            );
                            m.onOpen();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Quick ToDo & Activity Dock Bar right on Home Screen
              Card(
                elevation: 0,
                color: colors.secondaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Quick ToDo & Activity Tracker',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => widget.onNavigateTab(2),
                            icon: const Icon(Icons.handshake_rounded, size: 15),
                            label: const Text(
                              'Frappe CRM',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _quickTodoCtrl,
                              onSubmitted: (_) => _addQuickHomeTodo(),
                              decoration: InputDecoration(
                                hintText: 'Add a quick task or follow-up...',
                                filled: true,
                                fillColor: colors.surface,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _addingTodo ? null : _addQuickHomeTodo,
                            icon: const Icon(Icons.add_task_rounded, size: 16),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Regular Company Operations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${sortedModules.length} Active Modules',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
                children: sortedModules.asMap().entries.map((
                  MapEntry<int, _DashboardModuleEntry> entry,
                ) {
                  final int rankIdx = entry.key;
                  final _DashboardModuleEntry m = entry.value;
                  final int count = smart.usageCountOf(m.spec.id);
                  final bool pinned = smart.isPinned(m.spec.id);
                  final String accessBadge = smart.accessBadgeForSpec(m.spec);

                  String? topBadge;
                  if (pinned) {
                    topBadge = '📌 Pinned';
                  } else if (count > 0 && rankIdx == 0) {
                    topBadge = '🔥 #1 ($count×)';
                  } else if (count > 0) {
                    topBadge = '⚡ $count×';
                  } else {
                    topBadge = accessBadge;
                  }

                  return _ModuleCard(
                    title: m.spec.title,
                    subtitle: m.subtitle,
                    icon: m.icon,
                    color: m.color,
                    badgeText: topBadge,
                    isPinned: pinned,
                    onTap: () {
                      smart.recordItemTap(
                        m.spec.id,
                        primaryDocType: m.spec.primaryDocType,
                      );
                      m.onOpen();
                    },
                    onLongPress: () async {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      await smart.togglePin(m.spec.id);
                      final bool nowPinned = smart.isPinned(m.spec.id);
                      messenger.showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(
                            nowPinned
                                ? '📌 Pinned "${m.spec.title}" to top of dashboard!'
                                : 'Unpinned "${m.spec.title}".',
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'ERPNext HR Operations (Auto-Sorted)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${sortedHrTools.length} Tools',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedHrTools.map((_DashboardQuickChipEntry tool) {
                  final int count = smart.usageCountOf(tool.spec.id);
                  return ActionChip(
                    avatar: Icon(tool.icon, size: 16),
                    label: Text(
                      count > 0
                          ? '${tool.spec.title} ($count×)'
                          : tool.spec.title,
                    ),
                    onPressed: () {
                      smart.recordItemTap(
                        tool.spec.id,
                        primaryDocType: tool.spec.primaryDocType,
                        parentModuleId: tool.parentModuleId,
                      );
                      tool.onOpen();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Quick Shortcuts (Most Used DocTypes)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${sortedShortcuts.length} DocTypes',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedShortcuts.asMap().entries.map((
                  MapEntry<int, _DashboardQuickChipEntry> entry,
                ) {
                  final int idx = entry.key;
                  final _DashboardQuickChipEntry sc = entry.value;
                  final int count = smart.usageCountOf(sc.spec.id);
                  final String rankLabel = idx < 5 ? ' (#${idx + 1})' : '';
                  final String countLabel = count > 0 ? ' • $count×' : '';
                  return ActionChip(
                    avatar: Icon(sc.icon, size: 16),
                    label: Text('${sc.spec.title}$rankLabel$countLabel'),
                    onPressed: () {
                      smart.recordItemTap(
                        sc.spec.id,
                        primaryDocType: sc.spec.primaryDocType,
                        parentModuleId: sc.parentModuleId,
                      );
                      sc.onOpen();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.badgeText,
    this.isPinned = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? badgeText;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isPinned ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: isPinned ? 0.55 : 0.25),
            width: isPinned ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, color: color, size: 19),
                ),
                if (badgeText != null && badgeText!.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
