import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

class ProjectsAndStockScreen extends StatefulWidget {
  const ProjectsAndStockScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ProjectsAndStockScreen> createState() => _ProjectsAndStockScreenState();
}

class _ProjectsAndStockScreenState extends State<ProjectsAndStockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _projects = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _tasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _timesheets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _materialRequests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stockEntries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _deliveryNotes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _bins = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _itemPrices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customers = <Map<String, dynamic>>[];
  List<String> _activityTypes = <String>[
    'Execution',
    'Site Survey',
    'Installation',
    'Maintenance',
    'Planning',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final List<Map<String, dynamic>> projs = await ErpApiClient.instance
          .getList(
            'Project',
            fields: <String>[
              'name',
              'project_name',
              'status',
              'percent_complete',
              'expected_end_date',
              'total_expense_claim',
              'total_costing_amount',
              'total_billed_amount',
              'gross_margin',
            ],
            limitPageLength: 50,
          );
      if (mounted) {
        setState(() => _projects = projs);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> tList = await ErpApiClient.instance
          .getList(
            'Task',
            fields: <String>[
              'name',
              'subject',
              'project',
              'status',
              'priority',
              'progress',
              'exp_end_date',
            ],
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _tasks = tList);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> tsList = await ErpApiClient.instance
          .getList(
            'Timesheet',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'start_date',
              'end_date',
              'total_hours',
              'status',
            ],
            limitPageLength: 30,
          );
      final List<Map<String, dynamic>> actDocs = await ErpApiClient.instance
          .getList(
            'Activity Type',
            fields: <String>['name'],
            limitPageLength: 20,
          );
      if (mounted) {
        setState(() {
          _timesheets = tsList;
          if (actDocs.isNotEmpty) {
            _activityTypes = actDocs
                .map((Map<String, dynamic> a) => (a['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> mrList = await ErpApiClient.instance
          .getList(
            'Material Request',
            fields: <String>[
              'name',
              'material_request_type',
              'transaction_date',
              'schedule_date',
              'status',
              'per_ordered',
              'set_warehouse',
            ],
            limitPageLength: 40,
          );
      final List<Map<String, dynamic>> seList = await ErpApiClient.instance
          .getList(
            'Stock Entry',
            fields: <String>[
              'name',
              'stock_entry_type',
              'posting_date',
              'from_warehouse',
              'to_warehouse',
              'project',
            ],
            limitPageLength: 30,
          );
      final List<Map<String, dynamic>> itemDocs = await ErpApiClient.instance
          .getList(
            'Item',
            fields: <String>['name', 'item_code', 'item_name', 'stock_uom'],
            filters: <String, dynamic>{'disabled': 0},
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() {
          _materialRequests = mrList;
          _stockEntries = seList;
          _items = itemDocs;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> dnList = await ErpApiClient.instance
          .getList(
            'Delivery Note',
            fields: <String>[
              'name',
              'customer',
              'customer_name',
              'posting_date',
              'grand_total',
              'status',
              'project',
            ],
            limitPageLength: 40,
          );
      final List<Map<String, dynamic>> binList = await ErpApiClient.instance
          .getList(
            'Bin',
            fields: <String>[
              'name',
              'item_code',
              'warehouse',
              'actual_qty',
              'projected_qty',
              'valuation_rate',
            ],
            limitPageLength: 80,
          );
      final List<Map<String, dynamic>> ipList = await ErpApiClient.instance
          .getList(
            'Item Price',
            fields: <String>[
              'name',
              'item_code',
              'item_name',
              'price_list',
              'price_list_rate',
              'currency',
            ],
            limitPageLength: 60,
          );
      final List<Map<String, dynamic>> custList = await ErpApiClient.instance
          .getList(
            'Customer',
            fields: <String>['name', 'customer_name'],
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() {
          _deliveryNotes = dnList;
          _bins = binList;
          _itemPrices = ipList;
          _customers = custList;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateTaskSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController subjectCtrl = TextEditingController();
    final TextEditingController assignToCtrl = TextEditingController();
    String? selectedProject = _projects.isNotEmpty
        ? (_projects.first['name'] ?? '').toString()
        : (session != null && session.projects.isNotEmpty
              ? session.projects.first
              : null);
    String priority = 'Medium';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'New Project Task & Assignment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Task Subject *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_projects.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedProject,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects.map((Map<String, dynamic> p) {
                          final String pName = (p['name'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: pName,
                            child: Text(
                              '$pName — ${p['project_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          setModalState(() => selectedProject = v);
                        },
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: const <String>['Low', 'Medium', 'High', 'Urgent']
                          .map(
                            (String p) => DropdownMenuItem<String>(
                              value: p,
                              child: Text(p),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => priority = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: assignToCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Assign to User Email (Optional)',
                        hintText: 'engineer@dripirrigation.com.bd',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.assignment_turned_in_rounded),
                      label: const Text('Create & Assign Task'),
                      onPressed: () async {
                        if (subjectCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          final Map<String, dynamic> taskDoc =
                              await ErpApiClient.instance.createDoc(
                                'Task',
                                <String, dynamic>{
                                  'subject': subjectCtrl.text.trim(),
                                  'project': ?selectedProject,
                                  'priority': priority,
                                  'status': 'Open',
                                },
                              );
                          final String createdTaskName = (taskDoc['name'] ?? '')
                              .toString();
                          if (assignToCtrl.text.trim().isNotEmpty &&
                              createdTaskName.isNotEmpty) {
                            try {
                              await ErpApiClient.instance.createDoc('ToDo', <
                                String,
                                dynamic
                              >{
                                'allocated_to': assignToCtrl.text.trim(),
                                'reference_type': 'Task',
                                'reference_name': createdTaskName,
                                'description':
                                    'Assigned Task: ${subjectCtrl.text.trim()}',
                                'priority': priority,
                              });
                            } catch (_) {}
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Task $createdTaskName created!'),
                              ),
                            );
                          }
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErpApiClient.formatErrorMessage(e),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateTimesheetSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController hoursCtrl = TextEditingController(text: '4.0');
    final TextEditingController noteCtrl = TextEditingController();
    String selectedActivity = _activityTypes.first;
    String? selectedProject = _projects.isNotEmpty
        ? (_projects.first['name'] ?? '').toString()
        : null;
    String? selectedTask = _tasks.isNotEmpty
        ? (_tasks.first['name'] ?? '').toString()
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Log Project Timesheet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedActivity,
                      decoration: const InputDecoration(
                        labelText: 'Activity Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _activityTypes
                          .map(
                            (String a) => DropdownMenuItem<String>(
                              value: a,
                              child: Text(a),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedActivity = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_projects.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedProject,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects.map((Map<String, dynamic> p) {
                          final String pName = (p['name'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: pName,
                            child: Text(
                              '$pName — ${p['project_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          setModalState(() => selectedProject = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_tasks.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedTask,
                        decoration: const InputDecoration(
                          labelText: 'Task',
                          border: OutlineInputBorder(),
                        ),
                        items: _tasks.map((Map<String, dynamic> t) {
                          final String tName = (t['name'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: tName,
                            child: Text(
                              '$tName — ${t['subject'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          setModalState(() => selectedTask = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Hours Worked',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Work Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.timer_rounded),
                      label: const Text('Save Timesheet'),
                      onPressed: () async {
                        final double hrs =
                            double.tryParse(hoursCtrl.text.trim()) ?? 1.0;
                        final String nowStr = DateFormat('yyyy-MM-dd HH:mm:ss')
                            .format(DateTime.now());
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            'Timesheet',
                            <String, dynamic>{
                              if (session != null &&
                                  session.employeeId.isNotEmpty)
                                'employee': session.employeeId,
                              if (session != null) 'company': session.company,
                              'time_logs': <Map<String, dynamic>>[
                                <String, dynamic>{
                                  'activity_type': selectedActivity,
                                  'from_time': nowStr,
                                  'hours': hrs,
                                  'project': ?selectedProject,
                                  'task': ?selectedTask,
                                  'description': noteCtrl.text.trim(),
                                },
                              ],
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Timesheet logged!'),
                              ),
                            );
                          }
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErpApiClient.formatErrorMessage(e),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateMaterialRequestSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String mrType = 'Material Transfer';
    String selectedItemCode = _items.isNotEmpty
        ? (_items.first['item_code'] ?? _items.first['name'] ?? '').toString()
        : '';
    final TextEditingController qtyCtrl = TextEditingController(text: '10');
    String selectedWarehouse =
        (session != null && session.warehouses.isNotEmpty)
        ? session.warehouses.first
        : '';
    String? selectedProject = _projects.isNotEmpty
        ? (_projects.first['name'] ?? '').toString()
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'New Material Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mrType,
                      decoration: const InputDecoration(
                        labelText: 'Request Purpose',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const <String>[
                                'Material Transfer',
                                'Material Issue',
                                'Purchase',
                              ]
                              .map(
                                (String t) => DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => mrType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_items.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedItemCode,
                        decoration: const InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(),
                        ),
                        items: _items.map((Map<String, dynamic> item) {
                          final String code =
                              (item['item_code'] ?? item['name'] ?? '')
                                  .toString();
                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(
                              '$code — ${item['item_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => selectedItemCode = v);
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Required Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (session != null &&
                        session.warehouses.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedWarehouse,
                        decoration: const InputDecoration(
                          labelText: 'Target Warehouse',
                          border: OutlineInputBorder(),
                        ),
                        items: session.warehouses
                            .map(
                              (String w) => DropdownMenuItem<String>(
                                value: w,
                                child: Text(w),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => selectedWarehouse = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_projects.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedProject,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects.map((Map<String, dynamic> p) {
                          final String pName = (p['name'] ?? '').toString();
                          return DropdownMenuItem<String>(
                            value: pName,
                            child: Text(
                              '$pName — ${p['project_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          setModalState(() => selectedProject = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: const Text('Create Material Request'),
                      onPressed: () async {
                        final double qty =
                            double.tryParse(qtyCtrl.text.trim()) ?? 1;
                        final String today = DateFormat('yyyy-MM-dd')
                            .format(DateTime.now());
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            'Material Request',
                            <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'material_request_type': mrType,
                              'transaction_date': today,
                              'schedule_date': today,
                              if (selectedWarehouse.isNotEmpty)
                                'set_warehouse': selectedWarehouse,
                              'items': <Map<String, dynamic>>[
                                <String, dynamic>{
                                  'item_code': selectedItemCode,
                                  'qty': qty,
                                  'schedule_date': today,
                                  if (selectedWarehouse.isNotEmpty)
                                    'warehouse': selectedWarehouse,
                                  'project': ?selectedProject,
                                },
                              ],
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Material Request created!'),
                              ),
                            );
                          }
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErpApiClient.formatErrorMessage(e),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fulfillMaterialRequest(Map<String, dynamic> mrSummary) async {
    final String mrName = (mrSummary['name'] ?? '').toString();
    final UserSession? session = ErpApiClient.instance.session;
    try {
      final Map<String, dynamic> fullMr = await ErpApiClient.instance.getDoc(
        'Material Request',
        mrName,
      );
      final List<dynamic> mrItems =
          (fullMr['items'] as List<dynamic>?) ?? <dynamic>[];
      if (mrItems.isEmpty) {
        throw Exception('No items found in Material Request $mrName');
      }

      final String mrType =
          (fullMr['material_request_type'] ?? 'Material Issue').toString();
      final String stockEntryType = mrType == 'Material Transfer'
          ? 'Material Transfer'
          : 'Material Issue';
      final String defaultWh =
          (session != null && session.warehouses.isNotEmpty)
          ? session.warehouses.first
          : '';

      final List<Map<String, dynamic>> seItems = mrItems.map((dynamic raw) {
        final Map<String, dynamic> r = Map<String, dynamic>.from(
          raw as Map<dynamic, dynamic>,
        );
        final String wh = (r['warehouse'] ?? defaultWh).toString();
        return <String, dynamic>{
          'item_code': r['item_code'],
          'qty': r['qty'] ?? 1,
          if (stockEntryType == 'Material Issue') 's_warehouse': wh,
          if (stockEntryType == 'Material Transfer') ...<String, dynamic>{
            's_warehouse': defaultWh,
            't_warehouse': wh,
          },
          'material_request': mrName,
          'material_request_item': r['name'],
          if (r['project'] != null) 'project': r['project'],
        };
      }).toList();

      final Map<String, dynamic> seDoc = await ErpApiClient.instance.createDoc(
        'Stock Entry',
        <String, dynamic>{
          if (session != null) 'company': session.company,
          'stock_entry_type': stockEntryType,
          'items': seItems,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Fulfillment Stock Entry ${seDoc['name']} created from $mrName!',
            ),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects, Tasks & Stock'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.folder_special_rounded), text: 'Projects'),
            Tab(icon: Icon(Icons.checklist_rounded), text: 'Tasks'),
            Tab(icon: Icon(Icons.more_time_rounded), text: 'Timesheets'),
            Tab(
              icon: Icon(Icons.local_shipping_rounded),
              text: 'Material & Stock',
            ),
            Tab(
              icon: Icon(Icons.assignment_turned_in_rounded),
              text: 'Delivery Notes',
            ),
            Tab(icon: Icon(Icons.warehouse_rounded), text: 'Stock Balance'),
          ],
        ),
      ),
      body: _loading && _projects.isEmpty && _tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildProjectsTab(sym),
                _buildTasksTab(),
                _buildTimesheetsTab(),
                _buildMaterialRequestsTab(),
                _buildDeliveryNotesTab(sym),
                _buildStockBalanceTab(sym),
              ],
            ),
    );
  }

  Widget _buildProjectsTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectSheet,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('New Project'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _projects.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> p = _projects[i];
            final double pct =
                (p['percent_complete'] as num?)?.toDouble() ?? 0.0;
            final double expClaim =
                (p['total_expense_claim'] as num?)?.toDouble() ?? 0.0;
            final double billed =
                (p['total_billed_amount'] as num?)?.toDouble() ?? 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${p['project_name'] ?? p['name']} (${p['name']})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${p['status'] ?? 'Open'} • ${pct.toInt()}%',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (pct / 100.0).clamp(0.0, 1.0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Billed: $sym${NumberFormat('#,##0').format(billed)} • Expense Claims: $sym${NumberFormat('#,##0').format(expClaim)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Task'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tasks.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> t = _tasks[i];
            final String taskName = (t['name'] ?? '').toString();
            final String status = (t['status'] ?? 'Open').toString();
            final bool isCompleted = status == 'Completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isCompleted
                      ? Icons.task_alt_rounded
                      : Icons.pending_actions_rounded,
                  color: isCompleted ? Colors.green : Colors.blue,
                ),
                title: Text(
                  '${t['subject'] ?? taskName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$taskName • Project: ${t['project'] ?? 'General'} • $status (${t['priority'] ?? 'Medium'})',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (String newStatus) async {
                    try {
                      await ErpApiClient.instance.updateDoc(
                        'Task',
                        taskName,
                        <String, dynamic>{
                          'status': newStatus,
                          if (newStatus == 'Completed') 'progress': 100,
                        },
                      );
                      await _loadData();
                    } catch (_) {}
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'Open',
                          child: Text('Set Open'),
                        ),
                        PopupMenuItem<String>(
                          value: 'Working',
                          child: Text('Set Working'),
                        ),
                        PopupMenuItem<String>(
                          value: 'Pending Review',
                          child: Text('Set Pending Review'),
                        ),
                        PopupMenuItem<String>(
                          value: 'Completed',
                          child: Text('Mark Completed'),
                        ),
                      ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimesheetsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTimesheetSheet,
        icon: const Icon(Icons.more_time_rounded),
        label: const Text('Log Hours'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _timesheets.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const <Widget>[
                  Center(
                    child: Text(
                      'No Timesheets logged yet. Tap "+ Log Hours" to record project time.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _timesheets.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> ts = _timesheets[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(
                        '${ts['employee_name'] ?? ts['employee'] ?? ts['name']} • ${ts['total_hours'] ?? 0} hrs',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${ts['name']} • Date: ${ts['start_date'] ?? ''} • ${ts['status'] ?? 'Draft'}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMaterialRequestsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMaterialRequestSheet,
        icon: const Icon(Icons.add_box_rounded),
        label: const Text('New Material Req.'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'Material Requests & Fulfillment',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_materialRequests.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No Material Requests found.'),
                ),
              )
            else
              ..._materialRequests.map((Map<String, dynamic> mr) {
                final String mrName = (mr['name'] ?? '').toString();
                final String mrType =
                    (mr['material_request_type'] ?? 'Purchase').toString();
                final String status = (mr['status'] ?? 'Draft').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.inventory_rounded),
                    ),
                    title: Text(
                      '$mrName • $mrType',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Date: ${mr['transaction_date'] ?? ''} • Warehouse: ${mr['set_warehouse'] ?? 'Default'} • Status: $status',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton.tonal(
                      onPressed: () => _fulfillMaterialRequest(mr),
                      child: const Text('Fulfill'),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            const Text(
              'Recent Stock Entries (Transfers / Issues)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._stockEntries.map((Map<String, dynamic> se) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.compare_arrows_rounded),
                  title: Text(
                    '${se['name']} • ${se['stock_entry_type'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Date: ${se['posting_date'] ?? ''} • Project: ${se['project'] ?? 'N/A'}',
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryNotesTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDeliveryNoteSheet,
        icon: const Icon(Icons.local_shipping_rounded),
        label: const Text('New Delivery Note'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _deliveryNotes.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> dn = _deliveryNotes[i];
            final String docName = (dn['name'] ?? '').toString();
            final double gt = (dn['grand_total'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.assignment_turned_in_rounded),
                ),
                title: Text(
                  '${dn['customer_name'] ?? dn['customer'] ?? docName} • $sym${NumberFormat('#,##0').format(gt)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$docName • ${dn['posting_date'] ?? ''} • ${dn['status'] ?? ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Download Delivery Note PDF',
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => ErpApiClient.instance.downloadAndOpenPdf(
                    doctype: 'Delivery Note',
                    docname: docName,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStockBalanceTab(String sym) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Warehouse Stock Balance (Bin)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._bins.map((Map<String, dynamic> bin) {
            final double actualQty =
                (bin['actual_qty'] as num?)?.toDouble() ?? 0;
            final double projQty =
                (bin['projected_qty'] as num?)?.toDouble() ?? 0;
            final double valRate =
                (bin['valuation_rate'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: actualQty > 0
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.warehouse_rounded,
                    color: actualQty > 0 ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  '${bin['item_code'] ?? ''} • Qty: ${NumberFormat('#,##0.##').format(actualQty)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Warehouse: ${bin['warehouse'] ?? ''}\nProjected: ${NumberFormat('#,##0.##').format(projQty)} • Valuation: $sym${NumberFormat('#,##0.##').format(valRate)}',
                ),
                isThreeLine: true,
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Item Price List',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._itemPrices.map((Map<String, dynamic> ip) {
            final double rate =
                (ip['price_list_rate'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.sell_rounded, color: Colors.teal),
                title: Text(
                  '${ip['item_name'] ?? ip['item_code'] ?? ''} (${ip['item_code'] ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${ip['price_list'] ?? 'Standard Selling'}'),
                trailing: Text(
                  '$sym${NumberFormat('#,##0.##').format(rate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showCreateProjectSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController nameCtrl = TextEditingController();
    String status = 'Open';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'New Project',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Project Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'Open',
                        child: Text('Open'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => status = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Create Project'),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'Project',
                          <String, dynamic>{
                            if (session != null) 'company': session.company,
                            'project_name': nameCtrl.text.trim(),
                            'status': status,
                          },
                        );
                        await _loadData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(ErpApiClient.formatErrorMessage(e)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateDeliveryNoteSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController customerCtrl = TextEditingController(
      text: _customers.isNotEmpty
          ? (_customers.first['name'] ?? '').toString()
          : '',
    );
    String selectedItemCode = _items.isNotEmpty
        ? (_items.first['item_code'] ?? _items.first['name'] ?? '').toString()
        : '';
    final TextEditingController qtyCtrl = TextEditingController(text: '1');
    final TextEditingController rateCtrl = TextEditingController(text: '1000');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'New Delivery Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_items.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedItemCode,
                        decoration: const InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _items.map((Map<String, dynamic> item) {
                          final String code =
                              (item['item_code'] ?? item['name'] ?? '')
                                  .toString();
                          return DropdownMenuItem<String>(
                            value: code,
                            child: Text(
                              '$code — ${item['item_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => selectedItemCode = v);
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Rate',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Create Delivery Note'),
                      onPressed: () async {
                        final double qty =
                            double.tryParse(qtyCtrl.text.trim()) ?? 1;
                        final double rate =
                            double.tryParse(rateCtrl.text.trim()) ?? 0;
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            'Delivery Note',
                            <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'customer': customerCtrl.text.trim(),
                              'posting_date': DateFormat('yyyy-MM-dd')
                                  .format(DateTime.now()),
                              'items': <Map<String, dynamic>>[
                                <String, dynamic>{
                                  'item_code': selectedItemCode,
                                  'qty': qty,
                                  'rate': rate,
                                },
                              ],
                            },
                          );
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ErpApiClient.formatErrorMessage(e),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
