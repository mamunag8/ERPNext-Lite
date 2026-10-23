import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../buying_assets/buying_assets_screen.dart';
import '../crm/crm_screen.dart';
import '../explorer/doctype_explorer_screen.dart';
import '../hr/attendance_screen.dart';
import '../hr/leave_claims_screen.dart';
import '../payroll/payroll_screen.dart';
import '../projects/projects_stock_screen.dart';
import '../sales/sales_billing_screen.dart';
import '../todo/quick_todo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      _DashboardTab(
        onNavigateTab: (int tabIdx) {
          setState(() => _selectedIndex = tabIdx);
        },
      ),
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
        onDestinationSelected: (int idx) {
          setState(() => _selectedIndex = idx);
        },
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

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              session?.company ?? 'NexERP Mobile',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
            tooltip: 'Sync Metadata',
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _syncing
                ? null
                : () async {
                    setState(() => _syncing = true);
                    await ErpApiClient.instance.refreshSessionMetadata();
                    if (!context.mounted) {
                      return;
                    }
                    setState(() => _syncing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Workspace metadata synced!'),
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
                        icon: const Icon(Icons.camera_front_rounded, size: 17),
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
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => widget.onNavigateTab(1),
                        icon: const Icon(Icons.task_alt_rounded, size: 17),
                        label: const Text(
                          'Quick ToDo Dock',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick ToDo & Activity Dock Bar right on Home Screen
          Card(
            elevation: 0,
            color: colors.secondaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.bolt_rounded, size: 18, color: colors.primary),
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
          const Text(
            'Regular Company Operations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: <Widget>[
              _ModuleCard(
                title: 'Quick ToDo & Activity',
                subtitle: '1-Tap Task Dock, Priority & Activity Log',
                icon: Icons.task_alt_rounded,
                color: Colors.amber.shade800,
                onTap: () => widget.onNavigateTab(1),
              ),
              _ModuleCard(
                title: 'Frappe CRM Pipeline',
                subtitle: 'Leads, Deals, 1-Tap Stage Move & Follow-up',
                icon: Icons.handshake_rounded,
                color: Colors.orange.shade800,
                onTap: () => widget.onNavigateTab(2),
              ),
              _ModuleCard(
                title: 'HR & Attendance',
                subtitle: 'Check-In, Attendance Tool, Monthly Sheet & Shifts',
                icon: Icons.how_to_reg_rounded,
                color: Colors.teal,
                onTap: () => widget.onNavigateTab(3),
              ),
              _ModuleCard(
                title: 'Leave & Claims',
                subtitle: 'Leave Approval, Expense Receipt & Advance',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.indigo,
                onTap: () => widget.onNavigateTab(4),
              ),
              _ModuleCard(
                title: 'Payroll & Salary Ops',
                subtitle: 'Slips, Payroll Entry, Structure & Additional Salary',
                icon: Icons.picture_as_pdf_rounded,
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PayrollScreen(),
                    ),
                  );
                },
              ),
              _ModuleCard(
                title: 'Sales & Accounts',
                subtitle: 'Invoice, Order, Quote, Payment & Journal Entry',
                icon: Icons.receipt_rounded,
                color: Colors.blue.shade700,
                onTap: () => widget.onNavigateTab(5),
              ),
              _ModuleCard(
                title: 'Projects & Stock',
                subtitle: 'Projects, Tasks, Timesheet, Delivery & Bin Stock',
                icon: Icons.engineering_rounded,
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProjectsAndStockScreen(),
                    ),
                  );
                },
              ),
              _ModuleCard(
                title: 'Buying & Assets',
                subtitle: 'Purchase Order/Receipt/Invoice, Supplier & Assets',
                icon: Icons.precision_manufacturing_rounded,
                color: Colors.brown.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BuyingAndAssetsScreen(),
                    ),
                  );
                },
              ),
              _ModuleCard(
                title: 'All DocTypes Explorer',
                subtitle: 'Browse, Inspect, PDF & Create Any ERPNext DocType',
                icon: Icons.dataset_linked_rounded,
                color: Colors.cyan.shade800,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DocTypeExplorerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'ERPNext HR Operations (9 Core Tools)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.fact_check_rounded, size: 16),
                label: const Text('1. Employee Attendance Tool'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('2. Monthly Attendance Sheet'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceScreen(initialTab: 2),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.beach_access_rounded, size: 16),
                label: const Text('3. Leave Application Mgmt'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveAndClaimsScreen(initialTab: 0),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 16,
                ),
                label: const Text('4. Employee Advance Mgmt'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveAndClaimsScreen(initialTab: 2),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('5. Expense Claim Mgmt'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveAndClaimsScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance_rounded, size: 16),
                label: const Text('6. Payroll Entry'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PayrollScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.assignment_ind_rounded, size: 16),
                label: const Text('7. Salary Structure Assign'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PayrollScreen(initialTab: 2),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('8. Salary Slip Generation'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PayrollScreen(initialTab: 0),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('9. Additional Salary Slip'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PayrollScreen(initialTab: 3),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Quick Shortcuts (Most Used DocTypes)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.task_alt_rounded, size: 16),
                label: const Text('Quick ToDo Dock'),
                onPressed: () => widget.onNavigateTab(1),
              ),
              ActionChip(
                avatar: const Icon(Icons.handshake_rounded, size: 16),
                label: const Text('Frappe CRM Pipeline'),
                onPressed: () => widget.onNavigateTab(2),
              ),
              ActionChip(
                avatar: const Icon(Icons.receipt_long, size: 16),
                label: const Text('Sales Invoices (#1)'),
                onPressed: () => widget.onNavigateTab(5),
              ),
              ActionChip(
                avatar: const Icon(Icons.shopping_cart_checkout, size: 16),
                label: const Text('Sales Orders (#2)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SalesBillingScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Employee Advance (#3)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveAndClaimsScreen(initialTab: 2),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.folder_open, size: 16),
                label: const Text('Projects (#4)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ProjectsAndStockScreen(),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.task_alt, size: 16),
                label: const Text('Tasks (#5)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ProjectsAndStockScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.attach_money, size: 16),
                label: const Text('Expense Claims (#6)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveAndClaimsScreen(initialTab: 1),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance_rounded, size: 16),
                label: const Text('Journal Entry'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SalesBillingScreen(initialTab: 4),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Material Request'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ProjectsAndStockScreen(initialTab: 3),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 16,
                ),
                label: const Text('Delivery Note'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ProjectsAndStockScreen(initialTab: 4),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.warehouse_outlined, size: 16),
                label: const Text('Stock Balance (Bin)'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const ProjectsAndStockScreen(initialTab: 5),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('Purchase Order'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const BuyingAndAssetsScreen(initialTab: 0),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 16,
                ),
                label: const Text('Assets & Movement'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const BuyingAndAssetsScreen(initialTab: 4),
                    ),
                  );
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.table_chart_outlined, size: 16),
                label: const Text('All DocTypes'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const DocTypeExplorerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
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
