import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';
import '../../core/widgets/erp_search_bar.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = false;
  String? _downloadingSlipName;

  List<Map<String, dynamic>> _employees = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _slips = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payrollEntries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _structureAssignments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salaryStructures = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _additionalSalaries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salaryComponents = <Map<String, dynamic>>[];

  String _slipQuery = '';
  String _slipStatusFilter = 'All';
  String _payrollEntryQuery = '';
  String _payrollEntryStatusFilter = 'All';
  String _structureQuery = '';
  String _structureStatusFilter = 'All';
  String _additionalSalaryQuery = '';
  String _additionalSalaryTypeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadAllPayrollData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _effectiveEmployees {
    if (_employees.isNotEmpty) {
      return _employees;
    }
    final UserSession? session = ErpApiClient.instance.session;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'name': session?.employeeId.isNotEmpty == true
            ? session!.employeeId
            : 'HR-EMP-00001',
        'employee_name': session?.employeeName.isNotEmpty == true
            ? session!.employeeName
            : (session?.fullName ?? 'Current Employee'),
        'department': session?.department ?? 'Operations - DIBL',
        'designation': session?.designation ?? 'Employee',
        'company': session?.company ?? 'Drip Irrigation BD Ltd',
      },
    ];
  }

  List<String> get _effectiveStructureNames {
    final List<String> names = _salaryStructures
        .map((Map<String, dynamic> s) => (s['name'] ?? '').toString())
        .where((String s) => s.isNotEmpty)
        .toList();
    for (final Map<String, dynamic> a in _structureAssignments) {
      final String st = (a['salary_structure'] ?? '').toString();
      if (st.isNotEmpty && !names.contains(st)) {
        names.add(st);
      }
    }
    if (names.isEmpty) {
      names.addAll(<String>[
        'DIBL Monthly Regular Structure',
        'Standard Monthly Structure',
      ]);
    }
    return names;
  }

  List<String> get _effectiveComponentNames {
    final List<String> names = _salaryComponents
        .map((Map<String, dynamic> c) => (c['name'] ?? '').toString())
        .where((String s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      names.addAll(<String>[
        'Performance Bonus',
        'Project Site Overtime Allowance',
        'Festival Bonus',
        'Mobile & Internet Allowance',
        'Arrear Salary',
        'Advance Salary Deduction',
        'Late Attendance Deduction',
      ]);
    }
    return names;
  }

  Future<void> _loadAllPayrollData() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<Map<String, dynamic>> empList = await ErpApiClient.instance
          .getList(
            'Employee',
            fields: <String>[
              'name',
              'employee_name',
              'department',
              'designation',
              'company',
            ],
            filters: <String, dynamic>{'status': 'Active'},
            orderBy: 'employee_name asc',
            limitPageLength: 200,
          );
      if (mounted && empList.isNotEmpty) {
        setState(() => _employees = empList);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> rows = await ErpApiClient.instance
          .getList(
            'Salary Slip',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'department',
              'designation',
              'posting_date',
              'start_date',
              'end_date',
              'gross_pay',
              'total_deduction',
              'net_pay',
              'status',
              'docstatus',
              'currency',
            ],
            orderBy: 'posting_date desc',
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _slips = rows);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> entries = await ErpApiClient.instance
          .getList(
            'Payroll Entry',
            fields: <String>[
              'name',
              'company',
              'posting_date',
              'payroll_frequency',
              'start_date',
              'end_date',
              'department',
              'branch',
              'currency',
              'status',
              'docstatus',
            ],
            orderBy: 'posting_date desc',
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _payrollEntries = entries);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> ssa = await ErpApiClient.instance
          .getList(
            'Salary Structure Assignment',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'department',
              'designation',
              'salary_structure',
              'from_date',
              'base',
              'variable',
              'company',
              'docstatus',
            ],
            orderBy: 'from_date desc',
            limitPageLength: 80,
          );
      if (mounted) {
        setState(() => _structureAssignments = ssa);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> structs = await ErpApiClient.instance
          .getList(
            'Salary Structure',
            fields: <String>[
              'name',
              'company',
              'is_active',
              'payroll_frequency',
              'currency',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _salaryStructures = structs);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> addSals = await ErpApiClient.instance
          .getList(
            'Additional Salary',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'department',
              'salary_component',
              'type',
              'payroll_date',
              'amount',
              'currency',
              'overwrite_salary_structure_amount',
              'docstatus',
            ],
            orderBy: 'payroll_date desc',
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _additionalSalaries = addSals);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> comps = await ErpApiClient.instance
          .getList(
            'Salary Component',
            fields: <String>['name', 'type'],
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _salaryComponents = comps);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _downloadPdf(String doctype, String docName) async {
    setState(() {
      _downloadingSlipName = docName;
    });
    try {
      final String savedPath = await ErpApiClient.instance.downloadAndOpenPdf(
        doctype: doctype,
        docname: docName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved & opened: $savedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              'PDF download failed: ${ErpApiClient.formatErrorMessage(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingSlipName = null;
        });
      }
    }
  }

  /// #8. Salary Slip Generation Modal (Supports both regular Salary Slip & Additional Salary Slip generation)
  Future<void> _showGenerateSalarySlipSheet({
    String? preselectedEmp,
    DateTime? referenceDate,
  }) async {
    final UserSession? session = ErpApiClient.instance.session;
    final List<Map<String, dynamic>> emps = _effectiveEmployees;
    String selectedEmp =
        preselectedEmp ??
        (session?.employeeId.isNotEmpty == true
            ? session!.employeeId
            : (emps.first['name'] ?? '').toString());
    if (!emps.any((Map<String, dynamic> e) => e['name'] == selectedEmp)) {
      selectedEmp = (emps.first['name'] ?? '').toString();
    }

    final DateTime ref = referenceDate ?? DateTime.now();
    DateTime startDate = DateTime(ref.year, ref.month, 1);
    DateTime endDate = DateTime(
      ref.year,
      ref.month,
      DateUtils.getDaysInMonth(ref.year, ref.month),
    );
    DateTime postingDate = DateTime.now();
    bool submitImmediately = false;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Find any Additional Salary entries for this employee in this period
            final String startStr = DateFormat('yyyy-MM-dd').format(startDate);
            final String endStr = DateFormat('yyyy-MM-dd').format(endDate);
            final List<Map<String, dynamic>> matchingAdditional =
                _additionalSalaries.where((Map<String, dynamic> a) {
                  final String emp = (a['employee'] ?? '').toString();
                  final String pDate = (a['payroll_date'] ?? '').toString();
                  return emp == selectedEmp &&
                      pDate.compareTo(startStr) >= 0 &&
                      pDate.compareTo(endStr) <= 0;
                }).toList();

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
                      'Generate Salary Slip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Automatically pulls Salary Structure Assignment & Additional Salaries for the selected period.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEmp,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: emps
                          .map(
                            (
                              Map<String, dynamic> e,
                            ) => DropdownMenuItem<String>(
                              value: (e['name'] ?? '').toString(),
                              child: Text(
                                '${e['employee_name'] ?? e['name']} (${e['name']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedEmp = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text('Start: $startStr'),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() {
                                  startDate = p;
                                  endDate = DateTime(
                                    p.year,
                                    p.month,
                                    DateUtils.getDaysInMonth(p.year, p.month),
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 16),
                            label: Text('End: $endStr'),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() => endDate = p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.today_rounded, size: 16),
                      label: Text(
                        'Posting Date: ${DateFormat('yyyy-MM-dd').format(postingDate)}',
                      ),
                      onPressed: () async {
                        final DateTime? p = await showDatePicker(
                          context: context,
                          initialDate: postingDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030),
                        );
                        if (p != null) {
                          setModalState(() => postingDate = p);
                        }
                      },
                    ),
                    if (matchingAdditional.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.teal.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Included Additional Salaries (${matchingAdditional.length}):',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...matchingAdditional.map(
                              (Map<String, dynamic> a) => Text(
                                '• ${a['salary_component']}: ${session?.currencySymbol ?? '৳'}${a['amount']} (${a['payroll_date']})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Submit Salary Slip Immediately'),
                      value: submitImmediately,
                      onChanged: (bool? v) =>
                          setModalState(() => submitImmediately = v ?? false),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.receipt_long_rounded),
                      label: Text(
                        saving
                            ? 'Generating Salary Slip...'
                            : 'Generate Salary Slip',
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                final Map<String, dynamic> empObj = emps
                                    .firstWhere(
                                      (Map<String, dynamic> e) =>
                                          e['name'] == selectedEmp,
                                      orElse: () => <String, dynamic>{},
                                    );
                                final Map<String, dynamic> created =
                                    await ErpApiClient.instance.createDoc(
                                      'Salary Slip',
                                      <String, dynamic>{
                                        'employee': selectedEmp,
                                        if (empObj['employee_name'] != null)
                                          'employee_name':
                                              empObj['employee_name'],
                                        'company':
                                            empObj['company'] ??
                                            session?.company ??
                                            'Drip Irrigation BD Ltd',
                                        'posting_date': DateFormat('yyyy-MM-dd')
                                            .format(postingDate),
                                        'start_date': startStr,
                                        'end_date': endStr,
                                        ' payroll_frequency': 'Monthly',
                                        if (submitImmediately) 'docstatus': 1,
                                      },
                                    );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.green.shade700,
                                      content: Text(
                                        'Salary Slip generated: ${created['name'] ?? selectedEmp}!',
                                      ),
                                    ),
                                  );
                                }
                                await _loadAllPayrollData();
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  /// #6. Payroll Entry Creation Modal
  Future<void> _showCreatePayrollEntrySheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = DateTime(
      now.year,
      now.month,
      DateUtils.getDaysInMonth(now.year, now.month),
    );
    DateTime postingDate = now;
    String frequency = 'Monthly';
    String selectedDept = 'All Departments';
    String selectedCostCenter =
        (session != null && session.costCenters.isNotEmpty)
        ? session.costCenters.first
        : 'Main - DIBL';
    bool autoGenerateSlips = true;
    bool saving = false;

    final List<String> deptOptions = <String>[
      'All Departments',
      if (session != null) ...session.departments,
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final String startStr = DateFormat('yyyy-MM-dd').format(startDate);
            final String endStr = DateFormat('yyyy-MM-dd').format(endDate);
            final String postStr = DateFormat('yyyy-MM-dd').format(postingDate);

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
                      'New Payroll Entry (Bulk Payroll Run)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: frequency,
                            decoration: const InputDecoration(
                              labelText: 'Payroll Frequency',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items:
                                const <String>[
                                      'Monthly',
                                      'Bimonthly',
                                      'Fortnightly',
                                      'Weekly',
                                      'Daily',
                                    ]
                                    .map(
                                      (String f) => DropdownMenuItem<String>(
                                        value: f,
                                        child: Text(f),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => frequency = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.today_rounded, size: 16),
                            label: Text('Post: $postStr'),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: postingDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() => postingDate = p);
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
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text('Start: $startStr'),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() {
                                  startDate = p;
                                  endDate = DateTime(
                                    p.year,
                                    p.month,
                                    DateUtils.getDaysInMonth(p.year, p.month),
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 16),
                            label: Text('End: $endStr'),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() => endDate = p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      decoration: const InputDecoration(
                        labelText: 'Department Filter',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: deptOptions
                          .toSet()
                          .map(
                            (String d) => DropdownMenuItem<String>(
                              value: d,
                              child: Text(d),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedDept = v);
                        }
                      },
                    ),
                    if (session != null &&
                        session.costCenters.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCostCenter,
                        decoration: const InputDecoration(
                          labelText: 'Cost Center',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: session.costCenters
                            .map(
                              (String c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => selectedCostCenter = v);
                          }
                        },
                      ),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Auto-Create Salary Slips for Active Employees',
                      ),
                      value: autoGenerateSlips,
                      onChanged: (bool? v) =>
                          setModalState(() => autoGenerateSlips = v ?? true),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.account_balance_rounded),
                      label: Text(
                        saving
                            ? 'Processing Payroll Entry...'
                            : 'Create Payroll Entry',
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                final Map<String, dynamic> created =
                                    await ErpApiClient.instance.createDoc(
                                      'Payroll Entry',
                                      <String, dynamic>{
                                        'company':
                                            session?.company ??
                                            'Drip Irrigation BD Ltd',
                                        'posting_date': postStr,
                                        'payroll_frequency': frequency,
                                        'start_date': startStr,
                                        'end_date': endStr,
                                        'currency': session?.currency ?? 'BDT',
                                        'exchange_rate': 1.0,
                                        'cost_center': selectedCostCenter,
                                        if (selectedDept != 'All Departments')
                                          'department': selectedDept,
                                      },
                                    );

                                if (autoGenerateSlips) {
                                  await _createSlipsForPayrollPeriod(
                                    payrollEntryName: (created['name'] ?? '')
                                        .toString(),
                                    startDate: startStr,
                                    endDate: endStr,
                                    postingDate: postStr,
                                    department:
                                        selectedDept == 'All Departments'
                                        ? null
                                        : selectedDept,
                                  );
                                }

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.green.shade700,
                                      content: Text(
                                        'Payroll Entry ${created['name'] ?? ''} created!',
                                      ),
                                    ),
                                  );
                                }
                                await _loadAllPayrollData();
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  Future<int> _createSlipsForPayrollPeriod({
    required String payrollEntryName,
    required String startDate,
    required String endDate,
    required String postingDate,
    String? department,
  }) async {
    int createdCount = 0;
    final UserSession? session = ErpApiClient.instance.session;
    final List<Map<String, dynamic>> targetEmps = _effectiveEmployees.where((
      Map<String, dynamic> e,
    ) {
      if (department == null ||
          department.isEmpty ||
          department == 'All Departments') {
        return true;
      }
      return (e['department'] ?? '').toString() == department;
    }).toList();

    for (final Map<String, dynamic> emp in targetEmps) {
      final String empId = (emp['name'] ?? '').toString();
      if (empId.isEmpty) {
        continue;
      }
      try {
        await ErpApiClient.instance.createDoc('Salary Slip', <String, dynamic>{
          'employee': empId,
          'employee_name': emp['employee_name'],
          'company':
              emp['company'] ?? session?.company ?? 'Drip Irrigation BD Ltd',
          'posting_date': postingDate,
          'start_date': startDate,
          'end_date': endDate,
          'payroll_frequency': 'Monthly',
          if (payrollEntryName.isNotEmpty) 'payroll_entry': payrollEntryName,
        });
        createdCount++;
      } catch (_) {}
    }
    return createdCount;
  }

  /// #7. Salary Structure Assignment Creation Modal
  Future<void> _showAssignSalaryStructureSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final List<Map<String, dynamic>> emps = _effectiveEmployees;
    String selectedEmp = session?.employeeId.isNotEmpty == true
        ? session!.employeeId
        : (emps.first['name'] ?? '').toString();
    if (!emps.any((Map<String, dynamic> e) => e['name'] == selectedEmp)) {
      selectedEmp = (emps.first['name'] ?? '').toString();
    }

    final List<String> structures = _effectiveStructureNames;
    String selectedStructure = structures.first;
    DateTime fromDate = DateTime(DateTime.now().year, 1, 1);
    final TextEditingController baseCtrl = TextEditingController(text: '50000');
    final TextEditingController variableCtrl = TextEditingController(text: '0');
    bool submitImmediately = true;
    bool saving = false;

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
                      'Assign Salary Structure',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEmp,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: emps
                          .map(
                            (
                              Map<String, dynamic> e,
                            ) => DropdownMenuItem<String>(
                              value: (e['name'] ?? '').toString(),
                              child: Text(
                                '${e['employee_name'] ?? e['name']} (${e['name']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedEmp = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStructure,
                      decoration: const InputDecoration(
                        labelText: 'Salary Structure',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: structures
                          .map(
                            (String s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedStructure = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        'From Date: ${DateFormat('yyyy-MM-dd').format(fromDate)}',
                      ),
                      onPressed: () async {
                        final DateTime? p = await showDatePicker(
                          context: context,
                          initialDate: fromDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (p != null) {
                          setModalState(() => fromDate = p);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: baseCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Base Pay (${session?.currencySymbol ?? '৳'})',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: variableCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Variable (${session?.currencySymbol ?? '৳'})',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Submit Assignment Immediately'),
                      value: submitImmediately,
                      onChanged: (bool? v) =>
                          setModalState(() => submitImmediately = v ?? true),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.assignment_ind_rounded),
                      label: Text(
                        saving
                            ? 'Assigning Salary Structure...'
                            : 'Save Salary Structure Assignment',
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final double baseAmt =
                                  double.tryParse(baseCtrl.text.trim()) ?? 0;
                              final double varAmt =
                                  double.tryParse(variableCtrl.text.trim()) ??
                                  0;
                              setModalState(() => saving = true);
                              try {
                                final Map<String, dynamic> empObj = emps
                                    .firstWhere(
                                      (Map<String, dynamic> e) =>
                                          e['name'] == selectedEmp,
                                      orElse: () => <String, dynamic>{},
                                    );
                                await ErpApiClient.instance.createDoc(
                                  'Salary Structure Assignment',
                                  <String, dynamic>{
                                    'employee': selectedEmp,
                                    if (empObj['employee_name'] != null)
                                      'employee_name': empObj['employee_name'],
                                    'salary_structure': selectedStructure,
                                    'from_date': DateFormat('yyyy-MM-dd')
                                        .format(fromDate),
                                    'base': baseAmt,
                                    'variable': varAmt,
                                    'company':
                                        empObj['company'] ??
                                        session?.company ??
                                        'Drip Irrigation BD Ltd',
                                    'currency': session?.currency ?? 'BDT',
                                    if (submitImmediately) 'docstatus': 1,
                                  },
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.green.shade700,
                                      content: const Text(
                                        'Salary Structure Assignment saved!',
                                      ),
                                    ),
                                  );
                                }
                                await _loadAllPayrollData();
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  /// #9. Additional Salary & Additional Salary Slip Generation Modal
  Future<void> _showCreateAdditionalSalarySheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final List<Map<String, dynamic>> emps = _effectiveEmployees;
    String selectedEmp = session?.employeeId.isNotEmpty == true
        ? session!.employeeId
        : (emps.first['name'] ?? '').toString();
    if (!emps.any((Map<String, dynamic> e) => e['name'] == selectedEmp)) {
      selectedEmp = (emps.first['name'] ?? '').toString();
    }

    final List<String> components = _effectiveComponentNames;
    String selectedComponent = components.first;
    DateTime payrollDate = DateTime.now();
    final TextEditingController amountCtrl = TextEditingController();
    bool overwriteStructureAmount = false;
    bool deductFullTax = false;
    bool alsoGenerateSlip = false;
    bool saving = false;

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
                      'New Additional Salary / Bonus / Overtime',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Creates an Additional Salary entry and optionally generates the updated Salary Slip immediately.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEmp,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: emps
                          .map(
                            (
                              Map<String, dynamic> e,
                            ) => DropdownMenuItem<String>(
                              value: (e['name'] ?? '').toString(),
                              child: Text(
                                '${e['employee_name'] ?? e['name']} (${e['name']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedEmp = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedComponent,
                      decoration: const InputDecoration(
                        labelText:
                            'Salary Component (Bonus / Overtime / Deduction)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: components
                          .map(
                            (String c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedComponent = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Amount (${session?.currencySymbol ?? '৳'})',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(
                              DateFormat('yyyy-MM-dd').format(payrollDate),
                            ),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: payrollDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() => payrollDate = p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Overwrite Salary Structure Amount'),
                      value: overwriteStructureAmount,
                      onChanged: (bool? v) => setModalState(
                        () => overwriteStructureAmount = v ?? false,
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Deduct Full Tax on Selected Payroll Date',
                      ),
                      value: deductFullTax,
                      onChanged: (bool? v) =>
                          setModalState(() => deductFullTax = v ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Also Generate Salary Slip for this Period Now',
                      ),
                      value: alsoGenerateSlip,
                      onChanged: (bool? v) =>
                          setModalState(() => alsoGenerateSlip = v ?? false),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_card_rounded),
                      label: Text(
                        saving
                            ? 'Saving Additional Salary...'
                            : (alsoGenerateSlip
                                  ? 'Save & Generate Additional Salary Slip'
                                  : 'Save & Submit Additional Salary'),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final double amt =
                                  double.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid amount'),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                final Map<String, dynamic> empObj = emps
                                    .firstWhere(
                                      (Map<String, dynamic> e) =>
                                          e['name'] == selectedEmp,
                                      orElse: () => <String, dynamic>{},
                                    );
                                final String pDateStr = DateFormat('yyyy-MM-dd')
                                    .format(payrollDate);

                                await ErpApiClient.instance.createDoc(
                                  'Additional Salary',
                                  <String, dynamic>{
                                    'employee': selectedEmp,
                                    if (empObj['employee_name'] != null)
                                      'employee_name': empObj['employee_name'],
                                    'company':
                                        empObj['company'] ??
                                        session?.company ??
                                        'Drip Irrigation BD Ltd',
                                    'salary_component': selectedComponent,
                                    'payroll_date': pDateStr,
                                    'amount': amt,
                                    'currency': session?.currency ?? 'BDT',
                                    'overwrite_salary_structure_amount':
                                        overwriteStructureAmount ? 1 : 0,
                                    'deduct_full_tax_on_selected_payroll_date':
                                        deductFullTax ? 1 : 0,
                                    'docstatus': 1,
                                  },
                                );

                                if (alsoGenerateSlip) {
                                  final DateTime sDate = DateTime(
                                    payrollDate.year,
                                    payrollDate.month,
                                    1,
                                  );
                                  final DateTime eDate = DateTime(
                                    payrollDate.year,
                                    payrollDate.month,
                                    DateUtils.getDaysInMonth(
                                      payrollDate.year,
                                      payrollDate.month,
                                    ),
                                  );
                                  try {
                                    await ErpApiClient.instance.createDoc(
                                      'Salary Slip',
                                      <String, dynamic>{
                                        'employee': selectedEmp,
                                        if (empObj['employee_name'] != null)
                                          'employee_name':
                                              empObj['employee_name'],
                                        'company':
                                            empObj['company'] ??
                                            session?.company ??
                                            'Drip Irrigation BD Ltd',
                                        'posting_date': pDateStr,
                                        'start_date': DateFormat('yyyy-MM-dd')
                                            .format(sDate),
                                        'end_date': DateFormat('yyyy-MM-dd')
                                            .format(eDate),
                                        'payroll_frequency': 'Monthly',
                                      },
                                    );
                                  } catch (_) {}
                                }

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.green.shade700,
                                      content: Text(
                                        alsoGenerateSlip
                                            ? 'Additional Salary & Salary Slip generated!'
                                            : 'Additional Salary saved & submitted!',
                                      ),
                                    ),
                                  );
                                }
                                await _loadAllPayrollData();
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  Future<void> _showSlipDetailSheet(
    Map<String, dynamic> slipSummary,
    String sym,
  ) async {
    final String name = (slipSummary['name'] ?? '').toString();
    Map<String, dynamic> fullSlip = slipSummary;
    try {
      fullSlip = await ErpApiClient.instance.getDoc('Salary Slip', name);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final List<dynamic> earnings =
        (fullSlip['earnings'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> deductions =
        (fullSlip['deductions'] as List<dynamic>?) ?? <dynamic>[];
    final int docstatus = (fullSlip['docstatus'] as num?)?.toInt() ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (BuildContext context, ScrollController scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${fullSlip['employee_name'] ?? ''} • ${fullSlip['designation'] ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Period: ${fullSlip['start_date'] ?? ''} to ${fullSlip['end_date'] ?? ''}',
                  style: const TextStyle(fontSize: 13),
                ),
                const Divider(height: 24),
                if (earnings.isNotEmpty) ...<Widget>[
                  const Text(
                    'Earnings Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...earnings.map((dynamic e) {
                    final Map<String, dynamic> row = Map<String, dynamic>.from(
                      e as Map<dynamic, dynamic>,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text((row['salary_component'] ?? '').toString()),
                          Text(
                            '$sym${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                ],
                if (deductions.isNotEmpty) ...<Widget>[
                  const Text(
                    'Deductions Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...deductions.map((dynamic d) {
                    final Map<String, dynamic> row = Map<String, dynamic>.from(
                      d as Map<dynamic, dynamic>,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text((row['salary_component'] ?? '').toString()),
                          Text(
                            '$sym${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Net Pay',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$sym${((fullSlip['net_pay'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (docstatus == 0) ...<Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.updateDoc(
                          'Salary Slip',
                          name,
                          <String, dynamic>{'docstatus': 1},
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Submitted $name!')),
                          );
                        }
                        await _loadAllPayrollData();
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
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Submit Draft Salary Slip'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ErpDocSheet.showViewAndEdit(
                      this.context,
                      doctype: 'Salary Slip',
                      docname: name,
                      onSaved: _loadAllPayrollData,
                    );
                  },
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('View / Edit All ERP Fields'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadPdf('Salary Slip', name);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Download Official Salary Slip PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll & Salary Operations'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllPayrollData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Salary Slips'),
            Tab(
              icon: Icon(Icons.account_balance_rounded),
              text: 'Payroll Entry',
            ),
            Tab(
              icon: Icon(Icons.assignment_ind_rounded),
              text: 'Salary Structure',
            ),
            Tab(icon: Icon(Icons.add_card_rounded), text: 'Additional Salary'),
          ],
        ),
      ),
      body: _loading && _slips.isEmpty && _payrollEntries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildSalarySlipsTab(sym),
                _buildPayrollEntryTab(sym),
                _buildSalaryStructureTab(sym),
                _buildAdditionalSalaryTab(sym),
              ],
            ),
    );
  }

  /// Tab 0: #8 Salary Slip Generation & PDF Download
  Widget _buildSalarySlipsTab(String sym) {
    final List<Map<String, dynamic>> filteredSlips = _slips.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _slipStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _slipQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateSalarySlipSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Generate Salary Slip'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Salary Slips (ID, employee, department, period, net pay)...',
            query: _slipQuery,
            onQueryChanged: (String v) => setState(() => _slipQuery = v),
            filters: const <String>['All', 'Submitted', 'Draft'],
            selectedFilter: _slipStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _slipStatusFilter = f),
            resultCount: filteredSlips.length,
            totalCount: _slips.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllPayrollData,
              child: filteredSlips.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        Center(
                          child: Text(
                            'No matching Salary Slips found. Tap "+ Generate Salary Slip" to create one.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: filteredSlips.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Map<String, dynamic> s = filteredSlips[i];
                        final String name = (s['name'] ?? '').toString();
                        final double gross =
                            (s['gross_pay'] as num?)?.toDouble() ?? 0;
                        final double deduct =
                            (s['total_deduction'] as num?)?.toDouble() ?? 0;
                        final double net =
                            (s['net_pay'] as num?)?.toDouble() ?? 0;
                        final bool isDownloading = _downloadingSlipName == name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showSlipDetailSheet(s, sym),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          '${s['employee_name'] ?? s['employee'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          (s['status'] ?? 'Draft').toString(),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$name • ${s['start_date'] ?? ''} → ${s['end_date'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text(
                                            'Gross Pay',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '$sym${NumberFormat('#,##0').format(gross)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text(
                                            'Deductions',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '$sym${NumberFormat('#,##0').format(deduct)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          const Text(
                                            'Net Pay',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '$sym${NumberFormat('#,##0').format(net)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: <Widget>[
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showSlipDetailSheet(s, sym),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('View Breakdown'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonalIcon(
                                        onPressed: isDownloading
                                            ? null
                                            : () => _downloadPdf(
                                                'Salary Slip',
                                                name,
                                              ),
                                        icon: isDownloading
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.picture_as_pdf_rounded,
                                                size: 18,
                                              ),
                                        label: Text(
                                          isDownloading
                                              ? 'Downloading...'
                                              : 'PDF',
                                        ),
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
          ),
        ],
      ),
    );
  }

  /// Tab 1: #6 Payroll Entry
  Widget _buildPayrollEntryTab(String sym) {
    final List<Map<String, dynamic>> filteredEntries = _payrollEntries.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _payrollEntryStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _payrollEntryQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePayrollEntrySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Payroll Entry'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search Payroll Entries (ID, frequency, department, period)...',
            query: _payrollEntryQuery,
            onQueryChanged: (String v) =>
                setState(() => _payrollEntryQuery = v),
            filters: const <String>['All', 'Submitted', 'Draft'],
            selectedFilter: _payrollEntryStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _payrollEntryStatusFilter = f),
            resultCount: filteredEntries.length,
            totalCount: _payrollEntries.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllPayrollData,
              child: filteredEntries.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        Center(
                          child: Text(
                            'No matching Payroll Entries found. Tap "+ New Payroll Entry" to run monthly payroll.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: filteredEntries.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Map<String, dynamic> pe = filteredEntries[i];
                        final String name = (pe['name'] ?? '').toString();
                        final String status = (pe['status'] ?? 'Draft')
                            .toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => ErpDocSheet.showViewAndEdit(
                              context,
                              doctype: 'Payroll Entry',
                              docname: name,
                              onSaved: _loadAllPayrollData,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          '$name (${pe['payroll_frequency'] ?? 'Monthly'})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          status,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Period: ${pe['start_date'] ?? ''} → ${pe['end_date'] ?? ''}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    'Department: ${pe['department'] ?? 'All Departments'} • Posting: ${pe['posting_date'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const Divider(),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: <Widget>[
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.edit_note_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('View / Edit'),
                                        onPressed: () =>
                                            ErpDocSheet.showViewAndEdit(
                                              context,
                                              doctype: 'Payroll Entry',
                                              docname: name,
                                              onSaved: _loadAllPayrollData,
                                            ),
                                      ),
                                      FilledButton.tonalIcon(
                                        icon: const Icon(
                                          Icons.playlist_add_check_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Create Salary Slips',
                                        ),
                                        onPressed: () async {
                                          final int count =
                                              await _createSlipsForPayrollPeriod(
                                                payrollEntryName: name,
                                                startDate:
                                                    (pe['start_date'] ?? '')
                                                        .toString(),
                                                endDate: (pe['end_date'] ?? '')
                                                    .toString(),
                                                postingDate:
                                                    (pe['posting_date'] ?? '')
                                                        .toString(),
                                                department:
                                                    (pe['department'] ?? '')
                                                        .toString(),
                                              );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                backgroundColor:
                                                    Colors.green.shade700,
                                                content: Text(
                                                  'Generated $count Salary Slip(s) for $name!',
                                                ),
                                              ),
                                            );
                                          }
                                          await _loadAllPayrollData();
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('PDF'),
                                        onPressed: () =>
                                            _downloadPdf('Payroll Entry', name),
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
          ),
        ],
      ),
    );
  }

  /// Tab 2: #7 Salary Structure Assignment
  Widget _buildSalaryStructureTab(String sym) {
    final List<Map<String, dynamic>> filteredStructures = _salaryStructures
        .where(
          (Map<String, dynamic> row) =>
              ErpSearchBar.matchesQuery(row, _structureQuery),
        )
        .toList();

    final List<Map<String, dynamic>> filteredAssignments = _structureAssignments
        .where((Map<String, dynamic> row) {
          return ErpSearchBar.matchesFilter(row, _structureStatusFilter) &&
              ErpSearchBar.matchesQuery(row, _structureQuery);
        })
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignSalaryStructureSheet,
        icon: const Icon(Icons.assignment_ind_rounded),
        label: const Text('Assign Structure'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Salary Structures & Assignments (employee, structure, base pay)...',
            query: _structureQuery,
            onQueryChanged: (String v) => setState(() => _structureQuery = v),
            filters: const <String>['All', 'Submitted', 'Draft'],
            selectedFilter: _structureStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _structureStatusFilter = f),
            resultCount: filteredAssignments.length + filteredStructures.length,
            totalCount: _structureAssignments.length + _salaryStructures.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllPayrollData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  if (filteredStructures.isNotEmpty) ...<Widget>[
                    Text(
                      'Active Salary Structures (${filteredStructures.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredStructures.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (BuildContext context, int i) {
                          final Map<String, dynamic> st = filteredStructures[i];
                          final String stName = (st['name'] ?? '').toString();
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: stName.isEmpty
                                ? null
                                : () => ErpDocSheet.showViewAndEdit(
                                    context,
                                    doctype: 'Salary Structure',
                                    docname: stName,
                                    onSaved: _loadAllPayrollData,
                                  ),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    stName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${st['payroll_frequency'] ?? 'Monthly'} • Active: ${st['is_active'] ?? 'Yes'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Salary Structure Assignments (${filteredAssignments.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredAssignments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No matching Salary Structure Assignments found. Tap "+ Assign Structure" to assign base pay & structure to an employee.',
                        ),
                      ),
                    )
                  else
                    ...filteredAssignments.map((Map<String, dynamic> a) {
                      final String name = (a['name'] ?? '').toString();
                      final double baseAmt =
                          (a['base'] as num?)?.toDouble() ?? 0;
                      final double varAmt =
                          (a['variable'] as num?)?.toDouble() ?? 0;
                      final int docstatus =
                          (a['docstatus'] as num?)?.toInt() ?? 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.assignment_ind_rounded),
                          ),
                          title: Text(
                            '${a['employee_name'] ?? a['employee'] ?? ''} • $sym${NumberFormat('#,##0').format(baseAmt)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Structure: ${a['salary_structure'] ?? ''}\nFrom: ${a['from_date'] ?? ''} ${varAmt > 0 ? '• Variable: $sym${NumberFormat('#,##0').format(varAmt)}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Chip(
                                label: Text(
                                  docstatus == 1 ? 'Submitted' : 'Draft',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                tooltip: 'Download PDF',
                                icon: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 18,
                                ),
                                onPressed: () => _downloadPdf(
                                  'Salary Structure Assignment',
                                  name,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => ErpDocSheet.showViewAndEdit(
                            context,
                            doctype: 'Salary Structure Assignment',
                            docname: name,
                            onSaved: _loadAllPayrollData,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 3: #9 Additional Salary & Additional Salary Slip Generation
  Widget _buildAdditionalSalaryTab(String sym) {
    final List<Map<String, dynamic>> filteredAdditional = _additionalSalaries
        .where((Map<String, dynamic> row) {
          return ErpSearchBar.matchesFilter(
                row,
                _additionalSalaryTypeFilter,
                field: 'type',
              ) &&
              ErpSearchBar.matchesQuery(row, _additionalSalaryQuery);
        })
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAdditionalSalarySheet,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('New Additional Salary'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Additional Salary (employee, component, date, amount)...',
            query: _additionalSalaryQuery,
            onQueryChanged: (String v) =>
                setState(() => _additionalSalaryQuery = v),
            filters: const <String>['All', 'Earning', 'Deduction'],
            selectedFilter: _additionalSalaryTypeFilter,
            onFilterChanged: (String f) =>
                setState(() => _additionalSalaryTypeFilter = f),
            resultCount: filteredAdditional.length,
            totalCount: _additionalSalaries.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllPayrollData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  Text(
                    'Additional Salary & Bonus / Overtime Slips (${filteredAdditional.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (filteredAdditional.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No matching Additional Salary records found. Tap "+ New Additional Salary" to add bonus, overtime, allowance, or deduction and generate its Salary Slip.',
                        ),
                      ),
                    )
                  else
                    ...filteredAdditional.map((Map<String, dynamic> ads) {
                      final String name = (ads['name'] ?? '').toString();
                      final String empId = (ads['employee'] ?? '').toString();
                      final String comp = (ads['salary_component'] ?? '')
                          .toString();
                      final String type = (ads['type'] ?? 'Earning').toString();
                      final double amt =
                          (ads['amount'] as num?)?.toDouble() ?? 0;
                      final String pDate = (ads['payroll_date'] ?? '')
                          .toString();
                      final bool isEarning = type != 'Deduction';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => ErpDocSheet.showViewAndEdit(
                            context,
                            doctype: 'Additional Salary',
                            docname: name,
                            onSaved: _loadAllPayrollData,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        '${ads['employee_name'] ?? empId} • $comp',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${isEarning ? '+' : '-'}$sym${NumberFormat('#,##0').format(amt)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: isEarning
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$name • Payroll Date: $pDate • Type: $type',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Divider(),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('View / Edit'),
                                      onPressed: () =>
                                          ErpDocSheet.showViewAndEdit(
                                            context,
                                            doctype: 'Additional Salary',
                                            docname: name,
                                            onSaved: _loadAllPayrollData,
                                          ),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('PDF'),
                                      onPressed: () => _downloadPdf(
                                        'Additional Salary',
                                        name,
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      icon: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Generate Salary Slip'),
                                      onPressed: () {
                                        DateTime? parsedDate;
                                        try {
                                          parsedDate = DateTime.parse(pDate);
                                        } catch (_) {}
                                        _showGenerateSalarySlipSheet(
                                          preselectedEmp: empId,
                                          referenceDate: parsedDate,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
