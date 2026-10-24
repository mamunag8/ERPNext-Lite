import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';

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
  List<String> _projectTemplates = <String>[
    '99-Not Applicable',
    '1-Project Visit Task Sequence',
    '2-General/Corporate/NGO Project Task Sequence',
    '3-Govt Lead Contract Task Sequence',
    '4-Govt Sub Contract Task Sequence',
    '5-DIBL Product Development Task Sequence',
    '6-IoT Product Development Task Sequence',
  ];
  List<String> _costCenters = <String>[
    '101 - Head Office CC - DIBL',
    '102 - Dhaka CC - DIBL',
    '103 - Chattogram CC - DIBL',
    '104 - Jashore CC - DIBL',
    '105 - Bogura CC - DIBL',
    '106 - Sylhet CC - DIBL',
    '107 - Barisal CC - DIBL',
    '108 - Rangpur CC - DIBL',
  ];
  List<String> _departments = <String>[
    'HR & Admin Department- DIBL',
    'Branch Operations- DIBL',
    'Marketing Department- DIBL',
    'Supply Chain & Inventory- DIBL',
    'IOT & Automation- DIBL',
    'Accounts & Finance- DIBL',
    'Research & Development- DIBL',
    'Executive Management- DIBL',
    'Head Office- DIBL',
  ];
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
              'project_type',
              'project_template',
              'priority',
              'department',
              'cost_center',
              'percent_complete',
              'expected_start_date',
              'expected_end_date',
              'estimated_costing',
              'total_expense_claim',
              'total_costing_amount',
              'total_billed_amount',
              'gross_margin',
              'customer',
            ],
            limitPageLength: 80,
          );
      if (mounted) {
        setState(() => _projects = projs);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> tmplDocs = await ErpApiClient.instance
          .getList(
            'Project Template',
            fields: <String>['name'],
            limitPageLength: 40,
          );
      final List<Map<String, dynamic>> ccDocs = await ErpApiClient.instance
          .getList(
            'Cost Center',
            fields: <String>['name'],
            filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
            limitPageLength: 50,
          );
      final List<Map<String, dynamic>> deptDocs = await ErpApiClient.instance
          .getList(
            'Department',
            fields: <String>['name'],
            filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
            limitPageLength: 50,
          );
      if (mounted) {
        setState(() {
          if (tmplDocs.isNotEmpty) {
            _projectTemplates = tmplDocs
                .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
          if (ccDocs.isNotEmpty) {
            _costCenters = ccDocs
                .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
          if (deptDocs.isNotEmpty) {
            _departments = deptDocs
                .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
        });
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
              'exp_start_date',
              'exp_end_date',
              'department',
            ],
            limitPageLength: 80,
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

  Future<void> _showCreateTaskSheet({String? initialProject}) async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController subjectCtrl = TextEditingController();
    final TextEditingController descCtrl = TextEditingController();
    final TextEditingController assignToCtrl = TextEditingController();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final TextEditingController startDateCtrl = TextEditingController(
      text: '$today 09:00:00',
    );
    final TextEditingController endDateCtrl = TextEditingController(
      text: '$today 18:00:00',
    );
    String? selectedProject =
        initialProject ??
        (_projects.isNotEmpty
            ? (_projects.first['name'] ?? '').toString()
            : (session != null && session.projects.isNotEmpty
                  ? session.projects.first
                  : null));
    String selectedDepartment = _departments.first;
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'New Project Task & Assignment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ErpDocSheet.showCreate(
                              this.context,
                              doctype: 'Task',
                              initialValues: <String, dynamic>{
                                'project': ?selectedProject,
                              },
                              onCreated: _loadData,
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('All Fields'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Task Subject *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_projects.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue:
                            _projects.any(
                              (Map<String, dynamic> p) =>
                                  p['name'] == selectedProject,
                            )
                            ? selectedProject
                            : (_projects.first['name'] ?? '').toString(),
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                          isDense: true,
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
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items:
                                const <String>[
                                      'Low',
                                      'Medium',
                                      'High',
                                      'Urgent',
                                    ]
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
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                _departments.contains(selectedDepartment)
                                ? selectedDepartment
                                : _departments.first,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _departments
                                .map(
                                  (String d) => DropdownMenuItem<String>(
                                    value: d,
                                    child: Text(
                                      d,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => selectedDepartment = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: startDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'Start Date/Time *',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      startDateCtrl.text =
                                          '${DateFormat('yyyy-MM-dd').format(picked)} 09:00:00';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endDateCtrl,
                            decoration: InputDecoration(
                              labelText: 'End Date/Time *',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      endDateCtrl.text =
                                          '${DateFormat('yyyy-MM-dd').format(picked)} 18:00:00';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Task Details / Description',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: assignToCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Assign to User Email (Optional)',
                        hintText: 'engineer@dripirrigation.com.bd',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                                  'department': selectedDepartment,
                                  'exp_start_date': startDateCtrl.text.trim(),
                                  'exp_end_date': endDateCtrl.text.trim(),
                                  if (descCtrl.text.trim().isNotEmpty)
                                    'description': descCtrl.text.trim(),
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
        child: _projects.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const <Widget>[
                  Center(
                    child: Text(
                      'No Projects found. Tap "+ New Project" to create one.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                itemCount: _projects.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> p = _projects[i];
                  final String docName = (p['name'] ?? '').toString();
                  final String projTitle = (p['project_name'] ?? docName)
                      .toString();
                  final String status = (p['status'] ?? 'Open').toString();
                  final double pct =
                      (p['percent_complete'] as num?)?.toDouble() ?? 0.0;
                  final double expClaim =
                      (p['total_expense_claim'] as num?)?.toDouble() ?? 0.0;
                  final double billed =
                      (p['total_billed_amount'] as num?)?.toDouble() ?? 0.0;
                  final String dept = (p['department'] ?? '').toString();
                  final String costCenter = (p['cost_center'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openProjectDetailsAndEditSheet(p, sym),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: status == 'Completed'
                                      ? Colors.green.withValues(alpha: 0.14)
                                      : Colors.teal.withValues(alpha: 0.14),
                                  child: Icon(
                                    status == 'Completed'
                                        ? Icons.check_circle_rounded
                                        : Icons.folder_special_rounded,
                                    size: 18,
                                    color: status == 'Completed'
                                        ? Colors.green
                                        : Colors.teal,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        projTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        <String>[
                                          docName,
                                          if (dept.isNotEmpty) dept,
                                          if (costCenter.isNotEmpty) costCenter,
                                        ].join(' • '),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    '$status • ${pct.toInt()}%',
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Billed: $sym${NumberFormat('#,##0').format(billed)} • Claims: $sym${NumberFormat('#,##0').format(expClaim)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  children: <Widget>[
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.add_task_rounded,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        '+ Task',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showCreateTaskSheet(
                                        initialProject: docName,
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 15,
                                      ),
                                      label: const Text(
                                        'View / Edit',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _openProjectDetailsAndEditSheet(
                                            p,
                                            sym,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openProjectDetailsAndEditSheet(
    Map<String, dynamic> summary,
    String sym,
  ) async {
    final String docName = (summary['name'] ?? '').toString();
    if (docName.isEmpty) {
      return;
    }

    Map<String, dynamic> fullDoc = Map<String, dynamic>.from(summary);
    try {
      final Map<String, dynamic> loaded = await ErpApiClient.instance.getDoc(
        'Project',
        docName,
      );
      fullDoc = <String, dynamic>{...summary, ...loaded};
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final TextEditingController nameCtrl = TextEditingController(
      text: (fullDoc['project_name'] ?? docName).toString(),
    );
    final TextEditingController startCtrl = TextEditingController(
      text: (fullDoc['expected_start_date'] ?? '').toString(),
    );
    final TextEditingController endCtrl = TextEditingController(
      text: (fullDoc['expected_end_date'] ?? '').toString(),
    );
    final TextEditingController estCostCtrl = TextEditingController(
      text: ((fullDoc['estimated_costing'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(0),
    );
    final TextEditingController customerCtrl = TextEditingController(
      text: (fullDoc['customer'] ?? '').toString(),
    );
    final TextEditingController notesCtrl = TextEditingController(
      text: (fullDoc['notes'] ?? '')
          .toString()
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim(),
    );

    String status = (fullDoc['status'] ?? 'Open').toString();
    String projectType = (fullDoc['project_type'] ?? 'Internal').toString();
    String priority = (fullDoc['priority'] ?? 'Medium').toString();
    String isActive = (fullDoc['is_active'] ?? 'Yes').toString();
    String selectedTemplate =
        (fullDoc['project_template'] ?? '99-Not Applicable').toString();
    if (!_projectTemplates.contains(selectedTemplate)) {
      _projectTemplates = <String>[selectedTemplate, ..._projectTemplates];
    }
    String selectedCostCenter = (fullDoc['cost_center'] ?? _costCenters.first)
        .toString();
    if (selectedCostCenter.isNotEmpty &&
        !_costCenters.contains(selectedCostCenter)) {
      _costCenters = <String>[selectedCostCenter, ..._costCenters];
    }
    String selectedDepartment = (fullDoc['department'] ?? _departments.first)
        .toString();
    if (selectedDepartment.isNotEmpty &&
        !_departments.contains(selectedDepartment)) {
      _departments = <String>[selectedDepartment, ..._departments];
    }
    double pctComplete =
        ((fullDoc['percent_complete'] as num?)?.toDouble() ?? 0.0).clamp(
          0.0,
          100.0,
        );
    bool saving = false;

    final List<Map<String, dynamic>> projectTasks = _tasks
        .where((Map<String, dynamic> t) => t['project'] == docName)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              maxChildSize: 0.96,
              minChildSize: 0.5,
              builder: (BuildContext context, ScrollController scrollCtrl) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Project $docName',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Tap any field to edit • Linked Tasks (${projectTasks.length})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ErpDocSheet.showViewAndEdit(
                                this.context,
                                doctype: 'Project',
                                docname: docName,
                                onSaved: _loadData,
                              );
                            },
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('All ERP Fields'),
                          ),
                          IconButton(
                            tooltip: 'Download Project PDF',
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                ErpApiClient.instance.downloadAndOpenPdf(
                                  doctype: 'Project',
                                  docname: docName,
                                ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          children: <Widget>[
                            TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Project Name *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        const <String>[
                                          'Open',
                                          'Completed',
                                          'Cancelled',
                                        ].contains(status)
                                        ? status
                                        : 'Open',
                                    decoration: const InputDecoration(
                                      labelText: 'Status',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items:
                                        const <String>[
                                              'Open',
                                              'Completed',
                                              'Cancelled',
                                            ]
                                            .map(
                                              (String s) =>
                                                  DropdownMenuItem<String>(
                                                    value: s,
                                                    child: Text(s),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setModalState(() => status = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        const <String>[
                                          'Low',
                                          'Medium',
                                          'High',
                                        ].contains(priority)
                                        ? priority
                                        : 'Medium',
                                    decoration: const InputDecoration(
                                      labelText: 'Priority',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items:
                                        const <String>['Low', 'Medium', 'High']
                                            .map(
                                              (String p) =>
                                                  DropdownMenuItem<String>(
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
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedTemplate,
                              decoration: const InputDecoration(
                                labelText: 'From Template (Project Template) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _projectTemplates
                                  .map(
                                    (String t) => DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(
                                        t,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) {
                                if (v != null) {
                                  setModalState(() => selectedTemplate = v);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCostCenter,
                              decoration: const InputDecoration(
                                labelText: 'Default Cost Center *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _costCenters
                                  .map(
                                    (String c) => DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(
                                        c,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) {
                                if (v != null) {
                                  setModalState(() => selectedCostCenter = v);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: selectedDepartment,
                                    decoration: const InputDecoration(
                                      labelText: 'Department',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: _departments
                                        .map(
                                          (String d) =>
                                              DropdownMenuItem<String>(
                                                value: d,
                                                child: Text(
                                                  d,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setModalState(
                                          () => selectedDepartment = v,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        const <String>[
                                          'Internal',
                                          'External',
                                          'Other',
                                        ].contains(projectType)
                                        ? projectType
                                        : 'Internal',
                                    decoration: const InputDecoration(
                                      labelText: 'Project Type',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items:
                                        const <String>[
                                              'Internal',
                                              'External',
                                              'Other',
                                            ]
                                            .map(
                                              (String pt) =>
                                                  DropdownMenuItem<String>(
                                                    value: pt,
                                                    child: Text(pt),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setModalState(() => projectType = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: startCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Expected Start Date',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                        ),
                                        onPressed: () async {
                                          final DateTime? picked =
                                              await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    DateTime.tryParse(
                                                      startCtrl.text,
                                                    ) ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2035),
                                              );
                                          if (picked != null) {
                                            setModalState(() {
                                              startCtrl.text = DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(picked);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: endCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Expected End Date',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: IconButton(
                                        icon: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                        ),
                                        onPressed: () async {
                                          final DateTime? picked =
                                              await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    DateTime.tryParse(
                                                      endCtrl.text,
                                                    ) ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2035),
                                              );
                                          if (picked != null) {
                                            setModalState(() {
                                              endCtrl.text = DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(picked);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: estCostCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Estimated Cost ($sym)',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        const <String>[
                                          'Yes',
                                          'No',
                                        ].contains(isActive)
                                        ? isActive
                                        : 'Yes',
                                    decoration: const InputDecoration(
                                      labelText: 'Is Active',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: const <String>['Yes', 'No']
                                        .map(
                                          (String a) =>
                                              DropdownMenuItem<String>(
                                                value: a,
                                                child: Text(a),
                                              ),
                                        )
                                        .toList(),
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setModalState(() => isActive = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: customerCtrl,
                              decoration: InputDecoration(
                                labelText: 'Customer (Optional)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.manage_search_rounded),
                                  onPressed: () async {
                                    final String? picked =
                                        await ErpDocSheet.pickLinkValue(
                                          context,
                                          linkDocType: 'Customer',
                                          currentValue: customerCtrl.text
                                              .trim(),
                                        );
                                    if (picked != null) {
                                      setModalState(
                                        () => customerCtrl.text = picked,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Text(
                                  'Completion: ${pctComplete.toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: pctComplete,
                                    max: 100,
                                    divisions: 20,
                                    label: '${pctComplete.toInt()}%',
                                    onChanged: (double v) {
                                      setModalState(() => pctComplete = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            TextField(
                              controller: notesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Project Notes / Scope',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Project Tasks (${projectTasks.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showCreateTaskSheet(
                                      initialProject: docName,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.add_task_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('+ Add Task'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (projectTasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No tasks linked to this project yet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            else
                              ...projectTasks.map((Map<String, dynamic> t) {
                                final String tName = (t['name'] ?? '')
                                    .toString();
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      t['status'] == 'Completed'
                                          ? Icons.task_alt_rounded
                                          : Icons.pending_actions_rounded,
                                      color: t['status'] == 'Completed'
                                          ? Colors.green
                                          : Colors.blue,
                                      size: 18,
                                    ),
                                    title: Text(
                                      '${t['subject'] ?? tName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '$tName • ${t['status'] ?? 'Open'} • ${t['priority'] ?? 'Medium'}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      ErpDocSheet.showViewAndEdit(
                                        this.context,
                                        doctype: 'Task',
                                        docname: tName,
                                        onSaved: _loadData,
                                      );
                                    },
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SafeArea(
                        top: false,
                        child: FilledButton.icon(
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Save Project Changes'),
                          onPressed: saving
                              ? null
                              : () async {
                                  if (nameCtrl.text.trim().isEmpty) {
                                    return;
                                  }
                                  setModalState(() => saving = true);
                                  try {
                                    await ErpApiClient.instance.updateDoc(
                                      'Project',
                                      docName,
                                      <String, dynamic>{
                                        'project_name': nameCtrl.text.trim(),
                                        'status': status,
                                        'priority': priority,
                                        'project_template': selectedTemplate,
                                        'cost_center': selectedCostCenter,
                                        'department': selectedDepartment,
                                        'project_type': projectType,
                                        'is_active': isActive,
                                        'percent_complete': pctComplete,
                                        if (startCtrl.text.trim().isNotEmpty)
                                          'expected_start_date': startCtrl.text
                                              .trim(),
                                        if (endCtrl.text.trim().isNotEmpty)
                                          'expected_end_date': endCtrl.text
                                              .trim(),
                                        'estimated_costing':
                                            double.tryParse(
                                              estCostCtrl.text.trim(),
                                            ) ??
                                            0.0,
                                        if (customerCtrl.text.trim().isNotEmpty)
                                          'customer': customerCtrl.text.trim(),
                                        if (notesCtrl.text.trim().isNotEmpty)
                                          'notes': notesCtrl.text.trim(),
                                      },
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                            SnackBar(
                                              backgroundColor:
                                                  Colors.green.shade700,
                                              content: Text(
                                                'Project $docName updated!',
                                              ),
                                            ),
                                          );
                                    }
                                    await _loadData();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.red.shade700,
                                          content: Text(
                                            ErpApiClient.formatErrorMessage(e),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => saving = false);
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          itemCount: _tasks.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> t = _tasks[i];
            final String taskName = (t['name'] ?? '').toString();
            final String status = (t['status'] ?? 'Open').toString();
            final bool isCompleted = status == 'Completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Task',
                  docname: taskName,
                  onSaved: _loadData,
                ),
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
                  onSelected: (String action) async {
                    if (action == '__EDIT__') {
                      await ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Task',
                        docname: taskName,
                        onSaved: _loadData,
                      );
                      return;
                    }
                    try {
                      await ErpApiClient.instance.updateDoc(
                        'Task',
                        taskName,
                        <String, dynamic>{
                          'status': action,
                          if (action == 'Completed') 'progress': 100,
                        },
                      );
                      await _loadData();
                    } catch (_) {}
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: '__EDIT__',
                          child: Text('View / Edit Full Task'),
                        ),
                        PopupMenuDivider(),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                itemCount: _timesheets.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> ts = _timesheets[i];
                  final String docName = (ts['name'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Timesheet',
                        docname: docName,
                        onSaved: _loadData,
                      ),
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(
                        '${ts['employee_name'] ?? ts['employee'] ?? docName} • ${ts['total_hours'] ?? 0} hrs',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$docName • Date: ${ts['start_date'] ?? ''} • ${ts['status'] ?? 'Draft'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          children: <Widget>[
            const Text(
              'Material Requests & Fulfillment (Tap any card to View / Edit)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    onTap: () => ErpDocSheet.showViewAndEdit(
                      context,
                      doctype: 'Material Request',
                      docname: mrName,
                      onSaved: _loadData,
                    ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Recent Stock Entries (Transfers / Issues)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => ErpDocSheet.showCreate(
                    context,
                    doctype: 'Stock Entry',
                    onCreated: _loadData,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Stock Entry'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._stockEntries.map((Map<String, dynamic> se) {
              final String seName = (se['name'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => ErpDocSheet.showViewAndEdit(
                    context,
                    doctype: 'Stock Entry',
                    docname: seName,
                    onSaved: _loadData,
                  ),
                  leading: const Icon(Icons.compare_arrows_rounded),
                  title: Text(
                    '$seName • ${se['stock_entry_type'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Date: ${se['posting_date'] ?? ''} • Project: ${se['project'] ?? 'N/A'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          itemCount: _deliveryNotes.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> dn = _deliveryNotes[i];
            final String docName = (dn['name'] ?? '').toString();
            final double gt = (dn['grand_total'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Delivery Note',
                  docname: docName,
                  onSaved: _loadData,
                ),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ErpDocSheet.showCreate(
          context,
          doctype: 'Item Price',
          onCreated: _loadData,
        ),
        icon: const Icon(Icons.sell_rounded),
        label: const Text('New Item Price'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Warehouse Stock Balance (Bin)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => ErpDocSheet.showCreate(
                    context,
                    doctype: 'Item',
                    onCreated: _loadData,
                  ),
                  icon: const Icon(Icons.add_box_outlined, size: 16),
                  label: const Text('+ New Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._bins.map((Map<String, dynamic> bin) {
              final String binName = (bin['name'] ?? '').toString();
              final double actualQty =
                  (bin['actual_qty'] as num?)?.toDouble() ?? 0;
              final double projQty =
                  (bin['projected_qty'] as num?)?.toDouble() ?? 0;
              final double valRate =
                  (bin['valuation_rate'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => ErpDocSheet.showViewAndEdit(
                    context,
                    doctype: 'Bin',
                    docname: binName,
                    onSaved: _loadData,
                  ),
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
              'Item Price List (Tap to Edit Rate)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._itemPrices.map((Map<String, dynamic> ip) {
              final String ipName = (ip['name'] ?? '').toString();
              final double rate =
                  (ip['price_list_rate'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => ErpDocSheet.showViewAndEdit(
                    context,
                    doctype: 'Item Price',
                    docname: ipName,
                    onSaved: _loadData,
                  ),
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
      ),
    );
  }

  Future<void> _showCreateProjectSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController nameCtrl = TextEditingController();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final TextEditingController startCtrl = TextEditingController(text: today);
    final TextEditingController endCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 60))),
    );
    final TextEditingController estCostCtrl = TextEditingController(text: '0');
    final TextEditingController customerCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();

    String status = 'Open';
    String priority = 'Medium';
    String projectType = 'Internal';
    String selectedTemplate = _projectTemplates.contains('99-Not Applicable')
        ? '99-Not Applicable'
        : _projectTemplates.first;
    String selectedCostCenter = _costCenters.first;
    String selectedDepartment = _departments.first;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'New Project',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ErpDocSheet.showCreate(
                              this.context,
                              doctype: 'Project',
                              onCreated: _loadData,
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('All ERP Fields'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Project Name *',
                        hintText: 'e.g. Gazipur 10-Acre Drip Irrigation',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTemplate,
                      decoration: const InputDecoration(
                        labelText: 'From Template (Project Template) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _projectTemplates
                          .map(
                            (String t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedTemplate = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCostCenter,
                      decoration: const InputDecoration(
                        labelText: 'Default Cost Center *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _costCenters
                          .map(
                            (String c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedCostCenter = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDepartment,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _departments
                                .map(
                                  (String d) => DropdownMenuItem<String>(
                                    value: d,
                                    child: Text(
                                      d,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => selectedDepartment = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: projectType,
                            decoration: const InputDecoration(
                              labelText: 'Project Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items:
                                const <String>['Internal', 'External', 'Other']
                                    .map(
                                      (String pt) => DropdownMenuItem<String>(
                                        value: pt,
                                        child: Text(pt),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => projectType = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
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
                              DropdownMenuItem<String>(
                                value: 'Cancelled',
                                child: Text('Cancelled'),
                              ),
                            ],
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => status = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const <String>['Low', 'Medium', 'High']
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: startCtrl,
                            decoration: InputDecoration(
                              labelText: 'Expected Start Date',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      startCtrl.text = DateFormat('yyyy-MM-dd')
                                          .format(picked);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endCtrl,
                            decoration: InputDecoration(
                              labelText: 'Expected End Date',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().add(
                                      const Duration(days: 60),
                                    ),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      endCtrl.text = DateFormat('yyyy-MM-dd')
                                          .format(picked);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: estCostCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Estimated Cost',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: customerCtrl,
                            decoration: InputDecoration(
                              labelText: 'Customer (Opt)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.manage_search_rounded,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  final String? picked =
                                      await ErpDocSheet.pickLinkValue(
                                        context,
                                        linkDocType: 'Customer',
                                        currentValue: customerCtrl.text.trim(),
                                      );
                                  if (picked != null) {
                                    setModalState(
                                      () => customerCtrl.text = picked,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Project Notes / Description',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
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
                          final Map<String, dynamic>
                          created = await ErpApiClient.instance.createDoc(
                            'Project',
                            <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'project_name': nameCtrl.text.trim(),
                              'project_template': selectedTemplate,
                              'cost_center': selectedCostCenter,
                              'department': selectedDepartment,
                              'project_type': projectType,
                              'status': status,
                              'priority': priority,
                              'is_active': 'Yes',
                              if (startCtrl.text.trim().isNotEmpty)
                                'expected_start_date': startCtrl.text.trim(),
                              if (endCtrl.text.trim().isNotEmpty)
                                'expected_end_date': endCtrl.text.trim(),
                              'estimated_costing':
                                  double.tryParse(estCostCtrl.text.trim()) ??
                                  0.0,
                              if (customerCtrl.text.trim().isNotEmpty)
                                'customer': customerCtrl.text.trim(),
                              if (notesCtrl.text.trim().isNotEmpty)
                                'notes': notesCtrl.text.trim(),
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade700,
                                content: Text(
                                  'Project ${created['name'] ?? ''} created!',
                                ),
                              ),
                            );
                          }
                          await _loadData();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red.shade700,
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
