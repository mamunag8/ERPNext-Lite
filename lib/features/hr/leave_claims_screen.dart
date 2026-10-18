import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

class LeaveAndClaimsScreen extends StatefulWidget {
  const LeaveAndClaimsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<LeaveAndClaimsScreen> createState() => _LeaveAndClaimsScreenState();
}

class _LeaveAndClaimsScreenState extends State<LeaveAndClaimsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = false;
  List<Map<String, dynamic>> _leaves = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _leaveAllocations = <Map<String, dynamic>>[];
  List<String> _leaveTypes = <String>[
    'Casual Leave',
    'Sick Leave',
    'Earned Leave',
    'Leave Without Pay',
  ];

  List<Map<String, dynamic>> _expenseClaims = <Map<String, dynamic>>[];
  List<String> _expenseTypes = <String>[
    'Travel',
    'Food & Refreshment',
    'Project Site Expense',
    'Office Supplies',
    'Transport / Fuel',
    'Accommodation',
  ];

  List<Map<String, dynamic>> _advances = <Map<String, dynamic>>[];

  static const List<String> _diblDepartments = <String>[
    'Branch Operations',
    'Marketing Department',
    'Human Resources',
    'Supply Chain & Inventory',
    'IOT & Automation',
    'Executive Management',
    'Accounts & Finance',
    'Research & Development',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<Map<String, dynamic>> leaveList = await ErpApiClient.instance
          .getList(
            'Leave Application',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'leave_type',
              'from_date',
              'to_date',
              'total_leave_days',
              'status',
              'description',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _leaves = leaveList);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> allocs = await ErpApiClient.instance
          .getList(
            'Leave Allocation',
            fields: <String>[
              'name',
              'employee_name',
              'leave_type',
              'total_leaves_allocated',
              'from_date',
              'to_date',
            ],
            limitPageLength: 20,
          );
      final List<Map<String, dynamic>> ltDocs = await ErpApiClient.instance
          .getList('Leave Type', fields: <String>['name'], limitPageLength: 20);
      if (mounted) {
        setState(() {
          _leaveAllocations = allocs;
          if (ltDocs.isNotEmpty) {
            _leaveTypes = ltDocs
                .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> claims = await ErpApiClient.instance
          .getList(
            'Expense Claim',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'posting_date',
              'project',
              'cost_center',
              'approval_status',
              'status',
              'total_claimed_amount',
              'total_sanctioned_amount',
              'total_amount_reimbursed',
            ],
            limitPageLength: 50,
          );
      final List<Map<String, dynamic>> etDocs = await ErpApiClient.instance
          .getList(
            'Expense Claim Type',
            fields: <String>['name'],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() {
          _expenseClaims = claims;
          if (etDocs.isNotEmpty) {
            _expenseTypes = etDocs
                .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> advList = await ErpApiClient.instance
          .getList(
            'Employee Advance',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'posting_date',
              'purpose',
              'project',
              'advance_amount',
              'paid_amount',
              'claimed_amount',
              'return_amount',
              'pending_amount',
              'status',
            ],
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _advances = advList);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _updateLeaveStatus(String docName, String newStatus) async {
    try {
      await ErpApiClient.instance.updateDoc(
        'Leave Application',
        docName,
        <String, dynamic>{'status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave Application $docName → $newStatus')),
        );
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _updateExpenseApproval(String docName, String newStatus) async {
    try {
      await ErpApiClient.instance.updateDoc(
        'Expense Claim',
        docName,
        <String, dynamic>{'approval_status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense Claim $docName → $newStatus')),
        );
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showCreateLeaveSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String selectedLeaveType = _leaveTypes.first;
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now().add(const Duration(days: 1));
    bool halfDay = false;
    final TextEditingController reasonCtrl = TextEditingController();

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
                      'Apply for Leave',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedLeaveType,
                      decoration: const InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _leaveTypes
                          .map(
                            (String t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedLeaveType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(fromDate)}',
                            ),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: fromDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() {
                                  fromDate = p;
                                  if (toDate.isBefore(fromDate)) {
                                    toDate = fromDate;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(toDate)}',
                            ),
                            onPressed: () async {
                              final DateTime? p = await showDatePicker(
                                context: context,
                                initialDate: toDate,
                                firstDate: fromDate,
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setModalState(() => toDate = p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Half Day Leave'),
                      value: halfDay,
                      onChanged: (bool? v) =>
                          setModalState(() => halfDay = v ?? false),
                    ),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Submit Leave Application'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            'Leave Application',
                            <String, dynamic>{
                              if (session != null &&
                                  session.employeeId.isNotEmpty)
                                'employee': session.employeeId,
                              if (session != null) 'company': session.company,
                              'leave_type': selectedLeaveType,
                              'from_date': DateFormat('yyyy-MM-dd')
                                  .format(fromDate),
                              'to_date': DateFormat('yyyy-MM-dd')
                                  .format(toDate),
                              'half_day': halfDay ? 1 : 0,
                              'description': reasonCtrl.text.trim(),
                              if (session != null &&
                                  session.leaveApprover.isNotEmpty)
                                'leave_approver': session.leaveApprover,
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Leave Application submitted!'),
                              ),
                            );
                          }
                          await _loadAllData();
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

  Future<void> _showCreateExpenseClaimSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String selectedExpenseType = _expenseTypes.first;
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController detailsCtrl = TextEditingController();
    String selectedDept = _diblDepartments.first;
    String selectedCostCenter =
        (session != null && session.costCenters.isNotEmpty)
        ? session.costCenters.first
        : '101 - Head Office CC - DIBL';
    String? selectedProject = (session != null && session.projects.isNotEmpty)
        ? session.projects.first
        : null;
    String? selectedAdvance;
    String? receiptPath;
    String? receiptFileName;
    bool uploading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Strict Advance Project Validation (replicates DIBL's Client Script)
            final List<Map<String, dynamic>> matchingAdvances = _advances.where(
              (Map<String, dynamic> adv) {
                if (selectedProject == null || selectedProject!.isEmpty) {
                  return true;
                }
                final String advProj =
                    (adv['project'] ?? adv['custom_project'] ?? '').toString();
                return advProj.isEmpty || advProj == selectedProject;
              },
            ).toList();

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
                      'New Expense Claim (with Receipt)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedExpenseType,
                      decoration: const InputDecoration(
                        labelText: 'Expense Claim Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _expenseTypes
                          .map(
                            (String t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedExpenseType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Claim Amount (${session?.currencySymbol ?? '৳'})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (session != null && session.costCenters.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedCostCenter,
                        decoration: const InputDecoration(
                          labelText: 'Branch / Cost Center',
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _diblDepartments
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
                    const SizedBox(height: 12),
                    if (session != null &&
                        session.projects.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedProject,
                        decoration: const InputDecoration(
                          labelText: 'Project (Strict Advance Filter)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: session.projects
                            .map(
                              (String p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          setModalState(() {
                            selectedProject = v;
                            selectedAdvance = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (matchingAdvances.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedAdvance,
                        decoration: const InputDecoration(
                          labelText: 'Link Employee Advance (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...matchingAdvances.map(
                            (
                              Map<String, dynamic> a,
                            ) => DropdownMenuItem<String?>(
                              value: (a['name'] ?? '').toString(),
                              child: Text(
                                '${a['name']} (${session?.currencySymbol ?? '৳'}${a['advance_amount'] ?? 0})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (String? v) {
                          setModalState(() => selectedAdvance = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: detailsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Expenses Details / Remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Camera Receipt'),
                            onPressed: () async {
                              final XFile? img = await _imagePicker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 80,
                              );
                              if (img != null) {
                                setModalState(() {
                                  receiptPath = img.path;
                                  receiptFileName = img.name;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 18,
                            ),
                            label: const Text('Gallery Receipt'),
                            onPressed: () async {
                              final XFile? img = await _imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                              );
                              if (img != null) {
                                setModalState(() {
                                  receiptPath = img.path;
                                  receiptFileName = img.name;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (receiptFileName != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Attached: $receiptFileName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: uploading
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
                        uploading
                            ? 'Uploading Receipt & Saving...'
                            : 'Submit Expense Claim',
                      ),
                      onPressed: uploading
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
                              setModalState(() => uploading = true);
                              try {
                                String uploadedUrl = '';
                                if (receiptPath != null) {
                                  uploadedUrl = await ErpApiClient.instance
                                      .uploadFile(
                                        filePath: receiptPath!,
                                        fileName:
                                            receiptFileName ?? 'receipt.jpg',
                                      );
                                }
                                final String today = DateFormat('yyyy-MM-dd')
                                    .format(DateTime.now());
                                final Map<String, dynamic>
                                payload = <String, dynamic>{
                                  if (session != null &&
                                      session.employeeId.isNotEmpty)
                                    'employee': session.employeeId,
                                  if (session != null)
                                    'company': session.company,
                                  'posting_date': today,
                                  'cost_center': selectedCostCenter,
                                  'project': ?selectedProject,
                                  if (session != null &&
                                      session.isDiblCustomized) ...<
                                    String,
                                    dynamic
                                  >{
                                    'custom_depertment': selectedDept,
                                    'custom_expenses_details_': detailsCtrl.text
                                        .trim(),
                                    'custom_add_documents':
                                        uploadedUrl.isNotEmpty
                                        ? uploadedUrl
                                        : '/files/receipt_pending.pdf',
                                  },
                                  'expense_approver':
                                      (session != null &&
                                          session.expenseApprover.isNotEmpty)
                                      ? session.expenseApprover
                                      : 'cfo@dripirrigation.com.bd',
                                  'expenses': <Map<String, dynamic>>[
                                    <String, dynamic>{
                                      'expense_date': today,
                                      'expense_type': selectedExpenseType,
                                      'description': detailsCtrl.text.trim(),
                                      'amount': amt,
                                      'sanctioned_amount': amt,
                                      'project': ?selectedProject,
                                      'cost_center': selectedCostCenter,
                                    },
                                  ],
                                };
                                await ErpApiClient.instance.createDoc(
                                  'Expense Claim',
                                  payload,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Expense Claim created with receipt!',
                                      ),
                                    ),
                                  );
                                }
                                await _loadAllData();
                              } catch (e) {
                                setModalState(() => uploading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  Future<void> _showCreateAdvanceSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController purposeCtrl = TextEditingController();
    String? selectedProject = (session != null && session.projects.isNotEmpty)
        ? session.projects.first
        : null;
    String? reqFilePath;
    String? reqFileName;
    bool uploading = false;

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
                      'New Employee Advance Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Advance Amount (${session?.currencySymbol ?? '৳'})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (session != null &&
                        session.projects.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedProject,
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                        ),
                        items: session.projects
                            .map(
                              (String p) => DropdownMenuItem<String>(
                                value: p,
                                child: Text(p),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          setModalState(() => selectedProject = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: purposeCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Purpose of Advance',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(
                        reqFileName == null
                            ? 'Attach Requisition / Application Photo'
                            : 'Attached: $reqFileName',
                      ),
                      onPressed: () async {
                        final XFile? picked = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          setModalState(() {
                            reqFilePath = picked.path;
                            reqFileName = picked.name;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        uploading
                            ? 'Submitting Advance...'
                            : 'Submit Employee Advance',
                      ),
                      onPressed: uploading
                          ? null
                          : () async {
                              final double amt =
                                  double.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (amt <= 0 || purposeCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter amount and purpose of advance',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => uploading = true);
                              try {
                                String uploadedUrl = '';
                                if (reqFilePath != null) {
                                  uploadedUrl = await ErpApiClient.instance
                                      .uploadFile(
                                        filePath: reqFilePath!,
                                        fileName:
                                            reqFileName ?? 'requisition.pdf',
                                      );
                                }
                                final String today = DateFormat('yyyy-MM-dd')
                                    .format(DateTime.now());
                                await ErpApiClient.instance.createDoc(
                                  'Employee Advance',
                                  <String, dynamic>{
                                    if (session != null &&
                                        session.employeeId.isNotEmpty)
                                      'employee': session.employeeId,
                                    if (session != null)
                                      'company': session.company,
                                    'posting_date': today,
                                    'purpose': purposeCtrl.text.trim(),
                                    'advance_amount': amt,
                                    'currency': session?.currency ?? 'BDT',
                                    'exchange_rate': 1.0,
                                    if (selectedProject !=
                                        null) ...<String, dynamic>{
                                      'project': selectedProject,
                                      'custom_project': selectedProject,
                                    },
                                    if (session != null &&
                                        session.isDiblCustomized) ...<
                                      String,
                                      dynamic
                                    >{
                                      'advance_account':
                                          '1310 - Debtors - DIBL',
                                      'custom_requisitionapplication':
                                          uploadedUrl.isNotEmpty
                                          ? uploadedUrl
                                          : '/files/requisition.pdf',
                                    },
                                  },
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Employee Advance created!',
                                          ),
                                        ),
                                      );
                                }
                                await _loadAllData();
                              } catch (e) {
                                setModalState(() => uploading = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave, Claims & Advances'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.beach_access_rounded), text: 'Leaves'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Expense Claims'),
            Tab(
              icon: Icon(Icons.account_balance_wallet_rounded),
              text: 'Emp. Advance',
            ),
          ],
        ),
      ),
      body: _loading && _leaves.isEmpty && _expenseClaims.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildLeavesTab(session),
                _buildExpenseClaimsTab(session, sym),
                _buildAdvancesTab(session, sym),
              ],
            ),
    );
  }

  Widget _buildLeavesTab(UserSession? session) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeaveSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_leaveAllocations.isNotEmpty) ...<Widget>[
              const Text(
                'Leave Allocations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _leaveAllocations.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> a = _leaveAllocations[i];
                    return Container(
                      width: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '${a['leave_type'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Allocated: ${a['total_leaves_allocated'] ?? 0} days',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${a['employee_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Leave Applications & Approvals',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._leaves.map((Map<String, dynamic> l) {
              final String status = (l['status'] ?? 'Open').toString();
              final String docName = (l['name'] ?? '').toString();
              final bool isOpen = status == 'Open';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${l['employee_name'] ?? l['employee'] ?? ''} • ${l['leave_type'] ?? ''}',
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
                      Text(
                        '${l['from_date']} → ${l['to_date']} (${l['total_leave_days'] ?? 1} days)',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (l['description'] != null &&
                          l['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l['description'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      if (isOpen && (session?.isApprover ?? true)) ...<Widget>[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton.icon(
                              onPressed: () =>
                                  _updateLeaveStatus(docName, 'Rejected'),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                              label: const Text(
                                'Reject',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _updateLeaveStatus(docName, 'Approved'),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Approve'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseClaimsTab(UserSession? session, String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateExpenseClaimSheet,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('New Expense Claim'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _expenseClaims.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> c = _expenseClaims[i];
            final String docName = (c['name'] ?? '').toString();
            final String approval = (c['approval_status'] ?? 'Draft')
                .toString();
            final double claimed =
                (c['total_claimed_amount'] as num?)?.toDouble() ?? 0;
            final double sanctioned =
                (c['total_sanctioned_amount'] as num?)?.toDouble() ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${c['employee_name'] ?? ''} ($docName)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            approval,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Claimed: $sym${claimed.toStringAsFixed(2)} • Sanctioned: $sym${sanctioned.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Date: ${c['posting_date'] ?? ''} • Project: ${c['project'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (approval == 'Draft' &&
                        (session?.isApprover ?? true)) ...<Widget>[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: () =>
                                _updateExpenseApproval(docName, 'Rejected'),
                            child: const Text(
                              'Reject',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () =>
                                _updateExpenseApproval(docName, 'Approved'),
                            child: const Text('Approve Claim'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdvancesTab(UserSession? session, String sym) {
    // Replicates DIBL's `EA List Footer Summary` Client Script 4-Card Summary
    double totalAdvance = 0;
    double totalClaimed = 0;
    double totalReturn = 0;
    double totalPending = 0;

    for (final Map<String, dynamic> row in _advances) {
      final double adv = (row['advance_amount'] as num?)?.toDouble() ?? 0;
      final double claimed = (row['claimed_amount'] as num?)?.toDouble() ?? 0;
      final double ret = (row['return_amount'] as num?)?.toDouble() ?? 0;
      totalAdvance += adv;
      totalClaimed += claimed;
      totalReturn += ret;
      totalPending += (adv - claimed - ret);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAdvanceSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Advance'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: <Widget>[
                _buildAdvanceSummaryCard(
                  'TOTAL ADVANCE',
                  '$sym ${NumberFormat('#,##0.00').format(totalAdvance)}',
                  const Color(0xFF1A73E8),
                ),
                _buildAdvanceSummaryCard(
                  'TOTAL CLAIMED',
                  '$sym ${NumberFormat('#,##0.00').format(totalClaimed)}',
                  const Color(0xFF28A745),
                ),
                _buildAdvanceSummaryCard(
                  'TOTAL RETURNED',
                  '$sym ${NumberFormat('#,##0.00').format(totalReturn)}',
                  const Color(0xFFFD7E14),
                ),
                _buildAdvanceSummaryCard(
                  'TOTAL PENDING',
                  '$sym ${NumberFormat('#,##0.00').format(totalPending)}',
                  const Color(0xFFDC3545),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._advances.map((Map<String, dynamic> adv) {
              final double amount =
                  (adv['advance_amount'] as num?)?.toDouble() ?? 0;
              final double claimed =
                  (adv['claimed_amount'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    '${adv['employee_name'] ?? ''} • $sym${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${adv['purpose'] ?? ''}\nProject: ${adv['project'] ?? 'General'} • Claimed: $sym${claimed.toStringAsFixed(0)}',
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(
                      (adv['status'] ?? 'Draft').toString(),
                      style: const TextStyle(fontSize: 11),
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

  Widget _buildAdvanceSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
