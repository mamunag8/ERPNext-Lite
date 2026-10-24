import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';
import '../../core/widgets/erp_search_bar.dart';

class CrmAndTasksScreen extends StatefulWidget {
  const CrmAndTasksScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CrmAndTasksScreen> createState() => _CrmAndTasksScreenState();
}

class _CrmAndTasksScreenState extends State<CrmAndTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = false;
  bool _usingFcrm = true;

  String _leadQuery = '';
  String _selectedLeadStage = 'All';
  String _dealQuery = '';
  String _selectedDealStage = 'All';
  String _crmTaskQuery = '';
  String _crmTaskStatusFilter = 'All';
  String _crmNoteQuery = '';
  String _crmNoteFilter = 'All';

  List<Map<String, dynamic>> _leads = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _deals = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _crmTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _todos = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _notes = <Map<String, dynamic>>[];

  static const List<String> _leadPipelineStages = <String>[
    'New',
    'Contacted',
    'Nurture',
    'Qualified',
    'Converted',
    'Unqualified',
  ];

  static const List<String> _dealPipelineStages = <String>[
    'Qualification',
    'Demo/Making',
    'Proposal/Quotation',
    'Negotiation',
    'Ready to Close',
    'Won',
    'Lost',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    final UserSession? s = ErpApiClient.instance.session;
    _usingFcrm = s?.hasFcrm ?? true;
    _loadCrmData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCrmData() async {
    setState(() => _loading = true);

    // 1. Leads: Try FCRM `CRM Lead` first, fallback to standard `Lead`
    try {
      if (_usingFcrm) {
        final List<Map<String, dynamic>> fcrmLeads = await ErpApiClient.instance
            .getList(
              'CRM Lead',
              fields: <String>[
                'name',
                'lead_name',
                'first_name',
                'last_name',
                'organization',
                'status',
                'mobile_no',
                'email',
                'lead_owner',
              ],
              limitPageLength: 80,
            );
        if (mounted) {
          setState(() => _leads = fcrmLeads);
        }
      } else {
        throw Exception('Use Standard CRM');
      }
    } catch (_) {
      try {
        final List<Map<String, dynamic>> stdLeads = await ErpApiClient.instance
            .getList(
              'Lead',
              fields: <String>[
                'name',
                'lead_name',
                'company_name',
                'status',
                'mobile_no',
                'email_id',
                'lead_owner',
              ],
              limitPageLength: 80,
            );
        if (mounted) {
          setState(() {
            _usingFcrm = false;
            _leads = stdLeads;
          });
        }
      } catch (_) {}
    }

    // 2. Deals / Opportunities: Try `CRM Deal` or `Opportunity`
    try {
      if (_usingFcrm) {
        final List<Map<String, dynamic>> fcrmDeals = await ErpApiClient.instance
            .getList(
              'CRM Deal',
              fields: <String>[
                'name',
                'organization',
                'status',
                'deal_value',
                'deal_owner',
              ],
              limitPageLength: 60,
            );
        if (mounted) {
          setState(() => _deals = fcrmDeals);
        }
      } else {
        final List<Map<String, dynamic>> opps = await ErpApiClient.instance
            .getList(
              'Opportunity',
              fields: <String>[
                'name',
                'customer_name',
                'party_name',
                'status',
                'opportunity_amount',
                'opportunity_owner',
              ],
              limitPageLength: 60,
            );
        if (mounted) {
          setState(() => _deals = opps);
        }
      }
    } catch (_) {}

    // 3. CRM Tasks & ToDos
    try {
      if (_usingFcrm) {
        final List<Map<String, dynamic>> tasks = await ErpApiClient.instance
            .getList(
              'CRM Task',
              fields: <String>[
                'name',
                'title',
                'description',
                'status',
                'priority',
                'due_date',
                'assigned_to',
                'reference_doctype',
                'reference_docname',
              ],
              limitPageLength: 60,
            );
        if (mounted) {
          setState(() => _crmTasks = tasks);
        }
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> todoDocs = await ErpApiClient.instance
          .getList(
            'ToDo',
            fields: <String>[
              'name',
              'description',
              'status',
              'priority',
              'date',
              'allocated_to',
              'reference_type',
              'reference_name',
            ],
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _todos = todoDocs);
      }
    } catch (_) {}

    // 4. CRM Notes / Comments
    try {
      final List<Map<String, dynamic>> crmNotes = await ErpApiClient.instance
          .getList(
            _usingFcrm ? 'CRM Note' : 'Comment',
            fields: _usingFcrm
                ? <String>[
                    'name',
                    'title',
                    'content',
                    'reference_doctype',
                    'reference_docname',
                    'owner',
                    'creation',
                  ]
                : <String>[
                    'name',
                    'content',
                    'reference_doctype',
                    'reference_name',
                    'owner',
                    'creation',
                  ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _notes = crmNotes);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _nextLeadStage(String current) {
    final int idx = _leadPipelineStages.indexOf(current);
    if (idx >= 0 && idx < _leadPipelineStages.length - 2) {
      return _leadPipelineStages[idx + 1];
    }
    return 'Qualified';
  }

  String _nextDealStage(String current) {
    final int idx = _dealPipelineStages.indexOf(current);
    if (idx >= 0 && idx < _dealPipelineStages.length - 2) {
      return _dealPipelineStages[idx + 1];
    }
    return 'Won';
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'New':
      case 'Qualification':
        return Colors.blue;
      case 'Contacted':
      case 'Demo/Making':
        return Colors.teal;
      case 'Nurture':
      case 'Proposal/Quotation':
        return Colors.indigo;
      case 'Qualified':
      case 'Negotiation':
      case 'Ready to Close':
        return Colors.orange.shade800;
      case 'Converted':
      case 'Won':
        return Colors.green.shade700;
      case 'Unqualified':
      case 'Lost':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _updateRecordStatus({
    required String doctype,
    required String name,
    required String newStatus,
  }) async {
    try {
      await ErpApiClient.instance.updateDoc(doctype, name, <String, dynamic>{
        'status': newStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green.shade700,
            content: Text('$name moved to "$newStatus"!'),
          ),
        );
      }
      await _loadCrmData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _convertLeadToDeal(Map<String, dynamic> lead) async {
    final String leadId = (lead['name'] ?? '').toString();
    final String org =
        (lead['organization'] ??
                lead['company_name'] ??
                lead['lead_name'] ??
                lead['first_name'] ??
                leadId)
            .toString();
    final TextEditingController valueCtrl = TextEditingController(
      text: '150000',
    );
    String dealStage = 'Qualification';

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
                  Text(
                    'Convert Lead → ${_usingFcrm ? 'CRM Deal' : 'Opportunity'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$org ($leadId)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: dealStage,
                    decoration: const InputDecoration(
                      labelText: 'Initial Deal Stage',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _dealPipelineStages
                        .map(
                          (String s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => dealStage = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Expected Deal Value',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Create Deal & Mark Lead Converted'),
                    onPressed: () async {
                      final double val =
                          double.tryParse(valueCtrl.text.trim()) ?? 0;
                      Navigator.pop(ctx);
                      try {
                        if (_usingFcrm) {
                          await ErpApiClient.instance.createDoc(
                            'CRM Deal',
                            <String, dynamic>{
                              'organization': org,
                              'lead': leadId,
                              'status': dealStage,
                              'deal_value': val,
                            },
                          );
                          await ErpApiClient.instance.updateDoc(
                            'CRM Lead',
                            leadId,
                            <String, dynamic>{'status': 'Converted'},
                          );
                        } else {
                          await ErpApiClient.instance.createDoc(
                            'Opportunity',
                            <String, dynamic>{
                              'opportunity_from': 'Lead',
                              'party_name': leadId,
                              'customer_name': org,
                              'status': 'Open',
                              'opportunity_amount': val,
                            },
                          );
                          await ErpApiClient.instance.updateDoc(
                            'Lead',
                            leadId,
                            <String, dynamic>{'status': 'Converted'},
                          );
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.green.shade700,
                              content: Text(
                                'Converted $org into Deal & marked Converted!',
                              ),
                            ),
                          );
                        }
                        await _loadCrmData();
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

  /// Quick Follow-up Note Logger for any CRM Lead or CRM Deal
  Future<void> _showQuickCrmNoteSheet({
    required String referenceDocType,
    required String referenceName,
    required String displayName,
  }) async {
    final TextEditingController titleCtrl = TextEditingController(
      text: 'Follow-up: $displayName',
    );
    final TextEditingController noteCtrl = TextEditingController();
    bool scheduleNextTodo = false;
    int followUpInDays = 1;

    final List<String> presets = <String>[
      '📞 Called client — interested in Drip Irrigation proposal',
      '💬 Sent product catalog & price estimate on WhatsApp',
      '📍 Site survey & water source check scheduled',
      '📄 Sent formal Quotation — awaiting approval',
      '🤝 Price negotiation completed — ready to close',
    ];

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
                    Text(
                      'Log CRM Note • $displayName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$referenceDocType: $referenceName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1-Tap Maintenance Presets:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets
                          .map(
                            (String p) => ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                p,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  noteCtrl.text = p;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note Title',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Discussion Summary / Next Steps',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Also schedule a Follow-up ToDo & CRM Task',
                      ),
                      value: scheduleNextTodo,
                      onChanged: (bool? v) =>
                          setModalState(() => scheduleNextTodo = v ?? false),
                    ),
                    if (scheduleNextTodo)
                      Wrap(
                        spacing: 8,
                        children: <int>[1, 3, 7].map((int days) {
                          final String label = days == 1
                              ? 'Tomorrow (+1d)'
                              : 'In $days Days';
                          return ChoiceChip(
                            label: Text(label),
                            selected: followUpInDays == days,
                            onSelected: (_) =>
                                setModalState(() => followUpInDays = days),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.note_add_rounded),
                      label: const Text('Save CRM Note'),
                      onPressed: () async {
                        if (noteCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          try {
                            await ErpApiClient.instance.createDoc(
                              'CRM Note',
                              <String, dynamic>{
                                'title': titleCtrl.text.trim(),
                                'content': noteCtrl.text.trim(),
                                'reference_doctype': referenceDocType,
                                'reference_docname': referenceName,
                              },
                            );
                          } catch (_) {
                            await ErpApiClient.instance.createDoc('Comment', <
                              String,
                              dynamic
                            >{
                              'comment_type': 'Comment',
                              'reference_doctype': referenceDocType,
                              'reference_name': referenceName,
                              'content':
                                  '${titleCtrl.text.trim()}: ${noteCtrl.text.trim()}',
                            });
                          }

                          if (scheduleNextTodo) {
                            final String dueStr = DateFormat('yyyy-MM-dd')
                                .format(
                                  DateTime.now().add(
                                    Duration(days: followUpInDays),
                                  ),
                                );
                            await ErpApiClient.instance.createDoc('ToDo', <
                              String,
                              dynamic
                            >{
                              'description':
                                  'Follow up with $displayName: ${noteCtrl.text.trim()}',
                              'priority': 'High',
                              'status': 'Open',
                              'date': dueStr,
                              'reference_type': referenceDocType,
                              'reference_name': referenceName,
                            });
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade700,
                                content: const Text('CRM Note saved!'),
                              ),
                            );
                          }
                          await _loadCrmData();
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

  /// 360° Lead or Deal Maintenance Sheet (Stepper + Edit Fields + Linked Tasks & Notes)
  Future<void> _showCrm360MaintenanceSheet({
    required Map<String, dynamic> record,
    required bool isLead,
  }) async {
    final String doctype = isLead
        ? (_usingFcrm ? 'CRM Lead' : 'Lead')
        : (_usingFcrm ? 'CRM Deal' : 'Opportunity');
    final String docName = (record['name'] ?? '').toString();
    final List<String> stages = isLead
        ? _leadPipelineStages
        : _dealPipelineStages;
    String currentStage =
        (record['status'] ?? (isLead ? 'New' : 'Qualification')).toString();

    final TextEditingController nameCtrl = TextEditingController(
      text:
          (record['lead_name'] ??
                  record['first_name'] ??
                  record['organization'] ??
                  record['customer_name'] ??
                  docName)
              .toString(),
    );
    final TextEditingController orgCtrl = TextEditingController(
      text:
          (record['organization'] ??
                  record['company_name'] ??
                  record['party_name'] ??
                  '')
              .toString(),
    );
    final TextEditingController mobileCtrl = TextEditingController(
      text: (record['mobile_no'] ?? '').toString(),
    );
    final TextEditingController valueCtrl = TextEditingController(
      text: (record['deal_value'] ?? record['opportunity_amount'] ?? 0)
          .toString(),
    );

    final List<Map<String, dynamic>> linkedTodos = _todos
        .where(
          (Map<String, dynamic> t) =>
              (t['reference_name'] ?? '').toString() == docName,
        )
        .toList();
    final List<Map<String, dynamic>> linkedNotes = _notes
        .where(
          (Map<String, dynamic> n) =>
              (n['reference_docname'] ?? n['reference_name'] ?? '')
                  .toString() ==
              docName,
        )
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
              initialChildSize: 0.82,
              maxChildSize: 0.94,
              minChildSize: 0.55,
              builder: (BuildContext context, ScrollController scrollCtrl) {
                return ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${isLead ? 'Lead' : 'Deal'} Maintenance: $docName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            currentStage,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _stageColor(currentStage),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isLead
                              ? 'Mark Junk / Cancelled'
                              : 'Mark Lost / Cancelled',
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.orange,
                          ),
                          onPressed: () async {
                            final String cancelStage = isLead ? 'Junk' : 'Lost';
                            setModalState(() => currentStage = cancelStage);
                            await _updateRecordStatus(
                              doctype: doctype,
                              name: docName,
                              newStatus: cancelStage,
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete ${isLead ? 'Lead' : 'Deal'}',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (BuildContext dCtx) => AlertDialog(
                                title: Text(
                                  'Delete ${isLead ? 'Lead' : 'Deal'}?',
                                ),
                                content: Text(
                                  'Are you sure you want to delete $docName?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Keep'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) {
                              return;
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            try {
                              await ErpApiClient.instance.deleteDoc(
                                doctype,
                                docName,
                              );
                              await _loadCrmData();
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
                    const SizedBox(height: 10),

                    // Step 1: Interactive Pipeline Stage Stepper
                    const Text(
                      'Step 1: 1-Tap Pipeline Stage Progression',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: stages.map((String st) {
                        final bool active = currentStage == st;
                        final Color c = _stageColor(st);
                        return ChoiceChip(
                          label: Text(
                            st,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: active ? c : null,
                            ),
                          ),
                          selected: active,
                          selectedColor: c.withValues(alpha: 0.2),
                          onSelected: (_) async {
                            setModalState(() => currentStage = st);
                            await _updateRecordStatus(
                              doctype: doctype,
                              name: docName,
                              newStatus: st,
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),

                    // Step 2: Quick Follow-up Actions
                    const Text(
                      'Step 2: Quick Follow-up & Activity Actions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (mobileCtrl.text.trim().isNotEmpty) ...<Widget>[
                          FilledButton.tonalIcon(
                            icon: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 16,
                            ),
                            label: const Text('Call'),
                            onPressed: () {
                              launchUrl(
                                Uri.parse('tel:${mobileCtrl.text.trim()}'),
                              );
                            },
                          ),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.chat_rounded, size: 16),
                            label: const Text('WhatsApp'),
                            onPressed: () {
                              final String cleanPhone = mobileCtrl.text
                                  .replaceAll(RegExp(r'\D'), '');
                              launchUrl(
                                Uri.parse('https://wa.me/$cleanPhone'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ],
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.note_add_rounded, size: 16),
                          label: const Text('+ Log Note'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showQuickCrmNoteSheet(
                              referenceDocType: doctype,
                              referenceName: docName,
                              displayName: nameCtrl.text.trim(),
                            );
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_task_rounded, size: 16),
                          label: const Text('+ Schedule ToDo'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCreateTodoSheet(
                              referenceDocType: doctype,
                              referenceName: docName,
                              prefillTitle:
                                  'Follow up with ${nameCtrl.text.trim()}',
                            );
                          },
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('All ERP Fields'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ErpDocSheet.showViewAndEdit(
                              this.context,
                              doctype: doctype,
                              docname: docName,
                              onSaved: _loadCrmData,
                            );
                          },
                        ),
                        if (isLead)
                          FilledButton.icon(
                            icon: const Icon(
                              Icons.rocket_launch_rounded,
                              size: 16,
                            ),
                            label: const Text('Convert → Deal'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _convertLeadToDeal(record);
                            },
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Step 3: Edit Details Inline
                    const Text(
                      'Step 3: Update Contact / Deal Information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: isLead
                            ? 'Contact / Lead Name'
                            : 'Organization / Deal Title',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organization / Company',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isLead)
                      TextField(
                        controller: mobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      )
                    else
                      TextField(
                        controller: valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Deal Value',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Updated Details'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final Map<String, dynamic> payload = isLead
                              ? <String, dynamic>{
                                  'lead_name': nameCtrl.text.trim(),
                                  'first_name': nameCtrl.text.trim(),
                                  'organization': orgCtrl.text.trim(),
                                  'company_name': orgCtrl.text.trim(),
                                  'mobile_no': mobileCtrl.text.trim(),
                                  'status': currentStage,
                                }
                              : <String, dynamic>{
                                  'organization': orgCtrl.text.trim().isNotEmpty
                                      ? orgCtrl.text.trim()
                                      : nameCtrl.text.trim(),
                                  'deal_value':
                                      double.tryParse(valueCtrl.text.trim()) ??
                                      0,
                                  'opportunity_amount':
                                      double.tryParse(valueCtrl.text.trim()) ??
                                      0,
                                  'status': currentStage,
                                };
                          await ErpApiClient.instance.updateDoc(
                            doctype,
                            docName,
                            payload,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade700,
                                content: Text('Updated $docName!'),
                              ),
                            );
                          }
                          await _loadCrmData();
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

                    if (linkedTodos.isNotEmpty ||
                        linkedNotes.isNotEmpty) ...<Widget>[
                      const Divider(height: 24),
                      const Text(
                        'Linked ToDos & Activity History',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...linkedTodos.map(
                        (Map<String, dynamic> t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.task_alt_rounded,
                            color: Colors.teal,
                            size: 18,
                          ),
                          title: Text((t['description'] ?? '').toString()),
                          subtitle: Text(
                            'ToDo • Due: ${t['date'] ?? ''} • ${t['status'] ?? 'Open'}',
                          ),
                        ),
                      ),
                      ...linkedNotes.map(
                        (Map<String, dynamic> n) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.history_edu_rounded,
                            color: Colors.indigo,
                            size: 18,
                          ),
                          title: Text(
                            (n['content'] ?? n['title'] ?? '')
                                .toString()
                                .replaceAll(RegExp(r'<[^>]*>'), ''),
                          ),
                          subtitle: Text('Note • ${n['creation'] ?? ''}'),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateLeadSheet() async {
    final TextEditingController firstNameCtrl = TextEditingController();
    final TextEditingController orgCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    String stage = 'New';

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
                        Expanded(
                          child: Text(
                            _usingFcrm
                                ? 'New CRM Lead (FCRM)'
                                : 'New ERPNext Lead',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('All ERP Fields'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ErpDocSheet.showCreate(
                              this.context,
                              doctype: _usingFcrm ? 'CRM Lead' : 'Lead',
                              initialValues: <String, dynamic>{'status': stage},
                              onCreated: _loadCrmData,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact / Lead Name *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orgCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Organization / Company Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: mobileCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Number',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: stage,
                            decoration: const InputDecoration(
                              labelText: 'Stage',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _leadPipelineStages
                                .map(
                                  (String s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => stage = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Save Lead'),
                      onPressed: () async {
                        if (firstNameCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          if (_usingFcrm) {
                            await ErpApiClient.instance.createDoc(
                              'CRM Lead',
                              <String, dynamic>{
                                'first_name': firstNameCtrl.text.trim(),
                                'lead_name': firstNameCtrl.text.trim(),
                                'organization': orgCtrl.text.trim(),
                                'mobile_no': mobileCtrl.text.trim(),
                                'email': emailCtrl.text.trim(),
                                'status': stage,
                              },
                            );
                          } else {
                            await ErpApiClient.instance.createDoc(
                              'Lead',
                              <String, dynamic>{
                                'first_name': firstNameCtrl.text.trim(),
                                'lead_name': firstNameCtrl.text.trim(),
                                'company_name': orgCtrl.text.trim(),
                                'mobile_no': mobileCtrl.text.trim(),
                                'email_id': emailCtrl.text.trim(),
                                'status': stage,
                              },
                            );
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Lead created!')),
                            );
                          }
                          await _loadCrmData();
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

  Future<void> _showCreateDealSheet() async {
    final TextEditingController orgCtrl = TextEditingController();
    final TextEditingController valueCtrl = TextEditingController();
    String stage = 'Qualification';

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _usingFcrm
                              ? 'New CRM Deal (FCRM)'
                              : 'New ERPNext Opportunity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('All ERP Fields'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ErpDocSheet.showCreate(
                            this.context,
                            doctype: _usingFcrm ? 'CRM Deal' : 'Opportunity',
                            initialValues: <String, dynamic>{
                              'status': _usingFcrm ? stage : 'Open',
                            },
                            onCreated: _loadCrmData,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization / Customer Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: stage,
                          decoration: const InputDecoration(
                            labelText: 'Deal Stage',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _dealPipelineStages
                              .map(
                                (String s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) {
                            if (v != null) {
                              setModalState(() => stage = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: valueCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Deal Value',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.handshake_rounded),
                    label: const Text('Save Deal'),
                    onPressed: () async {
                      if (orgCtrl.text.trim().isEmpty) {
                        return;
                      }
                      final double val =
                          double.tryParse(valueCtrl.text.trim()) ?? 0;
                      Navigator.pop(ctx);
                      try {
                        if (_usingFcrm) {
                          await ErpApiClient.instance.createDoc(
                            'CRM Deal',
                            <String, dynamic>{
                              'organization': orgCtrl.text.trim(),
                              'status': stage,
                              'deal_value': val,
                            },
                          );
                        } else {
                          await ErpApiClient.instance.createDoc(
                            'Opportunity',
                            <String, dynamic>{
                              'opportunity_from': 'Customer',
                              'party_name': orgCtrl.text.trim(),
                              'customer_name': orgCtrl.text.trim(),
                              'status': 'Open',
                              'opportunity_amount': val,
                            },
                          );
                        }
                        await _loadCrmData();
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

  Future<void> _showCreateTodoSheet({
    String? referenceDocType,
    String? referenceName,
    String? prefillTitle,
  }) async {
    final TextEditingController titleCtrl = TextEditingController(
      text: prefillTitle ?? '',
    );
    String priority = 'High';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Schedule Follow-up ToDo & CRM Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('All ERP Fields'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ErpDocSheet.showCreate(
                            this.context,
                            doctype: _usingFcrm ? 'CRM Task' : 'ToDo',
                            initialValues: <String, dynamic>{
                              'priority': priority,
                              'reference_doctype': ?referenceDocType,
                              'reference_docname': ?referenceName,
                              'reference_type': ?referenceDocType,
                              'reference_name': ?referenceName,
                            },
                            onCreated: _loadCrmData,
                          );
                        },
                      ),
                    ],
                  ),
                  if (referenceName != null)
                    Text(
                      'Linked to $referenceDocType: $referenceName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Task Description / Follow-up Action',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      ActionChip(
                        label: const Text('Today'),
                        onPressed: () =>
                            setModalState(() => dueDate = DateTime.now()),
                      ),
                      ActionChip(
                        label: const Text('Tomorrow'),
                        onPressed: () => setModalState(
                          () => dueDate = DateTime.now().add(
                            const Duration(days: 1),
                          ),
                        ),
                      ),
                      ActionChip(
                        label: const Text('In 3 Days'),
                        onPressed: () => setModalState(
                          () => dueDate = DateTime.now().add(
                            const Duration(days: 3),
                          ),
                        ),
                      ),
                      ActionChip(
                        label: const Text('Next Week'),
                        onPressed: () => setModalState(
                          () => dueDate = DateTime.now().add(
                            const Duration(days: 7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          items: const <String>['High', 'Medium', 'Low']
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
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(dueDate)),
                          onPressed: () async {
                            final DateTime? p = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (p != null) {
                              setModalState(() => dueDate = p);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Create Follow-up ToDo'),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        return;
                      }
                      final String dueStr = DateFormat('yyyy-MM-dd')
                          .format(dueDate);
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'ToDo',
                          <String, dynamic>{
                            'description': titleCtrl.text.trim(),
                            'priority': priority,
                            'status': 'Open',
                            'date': dueStr,
                            'reference_type': ?referenceDocType,
                            'reference_name': ?referenceName,
                          },
                        );
                        if (_usingFcrm) {
                          try {
                            await ErpApiClient.instance.createDoc(
                              'CRM Task',
                              <String, dynamic>{
                                'title': titleCtrl.text.trim(),
                                'priority': priority,
                                'status': 'Todo',
                                'due_date': dueStr,
                                'reference_doctype': ?referenceDocType,
                                'reference_docname': ?referenceName,
                              },
                            );
                          } catch (_) {}
                        }
                        await _loadCrmData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _usingFcrm ? 'Frappe CRM Pipeline & Maintenance' : 'CRM & Tasks',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh CRM',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCrmData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(
              icon: const Icon(Icons.leaderboard_rounded),
              text: 'Leads (${_leads.length})',
            ),
            Tab(
              icon: const Icon(Icons.handshake_rounded),
              text: 'Deals (${_deals.length})',
            ),
            Tab(icon: const Icon(Icons.task_alt_rounded), text: 'Tasks & ToDo'),
            Tab(icon: const Icon(Icons.note_alt_rounded), text: 'CRM Notes'),
          ],
        ),
      ),
      body: _loading && _leads.isEmpty && _todos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildLeadsTab(),
                _buildDealsTab(),
                _buildTasksTab(),
                _buildNotesTab(),
              ],
            ),
    );
  }

  Widget _buildLeadsTab() {
    final List<Map<String, dynamic>> filteredLeads = _leads.where((
      Map<String, dynamic> l,
    ) {
      final String status = (l['status'] ?? 'New').toString();
      if (_selectedLeadStage != 'All' && status != _selectedLeadStage) {
        return false;
      }
      return ErpSearchBar.matchesQuery(l, _leadQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeadSheet,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Lead'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Lead by name, organization, mobile, or email...',
            query: _leadQuery,
            onQueryChanged: (String v) => setState(() => _leadQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: _usingFcrm ? 'CRM Lead' : 'Lead',
              initialQuery: _leadQuery,
              onSaved: _loadCrmData,
            ),
            filters: <String>['All', ..._leadPipelineStages],
            selectedFilter: _selectedLeadStage,
            onFilterChanged: (String f) =>
                setState(() => _selectedLeadStage = f),
            resultCount: filteredLeads.length,
            totalCount: _leads.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCrmData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  if (filteredLeads.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No leads match this filter.'),
                        ),
                      ),
                    )
                  else
                    ...filteredLeads.map((Map<String, dynamic> l) {
                      final String docName = (l['name'] ?? '').toString();
                      final String title =
                          (l['lead_name'] ??
                                  l['first_name'] ??
                                  l['organization'] ??
                                  docName)
                              .toString();
                      final String org =
                          (l['organization'] ?? l['company_name'] ?? '')
                              .toString();
                      final String mobile = (l['mobile_no'] ?? '').toString();
                      final String status = (l['status'] ?? 'New').toString();
                      final String nextStage = _nextLeadStage(status);
                      final Color stColor = _stageColor(status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: stColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showCrm360MaintenanceSheet(
                            record: l,
                            isLead: true,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: stColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      child: Icon(
                                        Icons.person_search_rounded,
                                        color: stColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            '${org.isNotEmpty ? '$org • ' : ''}$docName${mobile.isNotEmpty ? ' • $mobile' : ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: stColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                // Guided 1-Tap Maintenance Steps Bar
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: <Widget>[
                                      if (mobile.isNotEmpty) ...<Widget>[
                                        _buildMaintenanceActionPill(
                                          icon: Icons.phone_in_talk_rounded,
                                          label: '1. Call',
                                          color: Colors.green.shade700,
                                          onTap: () => launchUrl(
                                            Uri.parse('tel:$mobile'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _buildMaintenanceActionPill(
                                          icon: Icons.chat_rounded,
                                          label: 'WhatsApp',
                                          color: Colors.teal.shade700,
                                          onTap: () {
                                            final String clean = mobile
                                                .replaceAll(RegExp(r'\D'), '');
                                            launchUrl(
                                              Uri.parse('https://wa.me/$clean'),
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (status != 'Converted') ...<Widget>[
                                        _buildMaintenanceActionPill(
                                          icon: Icons.fast_forward_rounded,
                                          label: '2. Move → $nextStage',
                                          color: _stageColor(nextStage),
                                          onTap: () => _updateRecordStatus(
                                            doctype: _usingFcrm
                                                ? 'CRM Lead'
                                                : 'Lead',
                                            name: docName,
                                            newStatus: nextStage,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      _buildMaintenanceActionPill(
                                        icon: Icons.note_add_rounded,
                                        label: '3. + Note',
                                        color: Colors.indigo,
                                        onTap: () => _showQuickCrmNoteSheet(
                                          referenceDocType: _usingFcrm
                                              ? 'CRM Lead'
                                              : 'Lead',
                                          referenceName: docName,
                                          displayName: title,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildMaintenanceActionPill(
                                        icon: Icons.add_task_rounded,
                                        label: '4. + ToDo',
                                        color: Colors.deepOrange,
                                        onTap: () => _showCreateTodoSheet(
                                          referenceDocType: _usingFcrm
                                              ? 'CRM Lead'
                                              : 'Lead',
                                          referenceName: docName,
                                          prefillTitle: 'Follow up with $title',
                                        ),
                                      ),
                                      if (status != 'Converted') ...<Widget>[
                                        const SizedBox(width: 6),
                                        _buildMaintenanceActionPill(
                                          icon: Icons.rocket_launch_rounded,
                                          label: '5. Convert → Deal',
                                          color: Colors.purple.shade700,
                                          onTap: () => _convertLeadToDeal(l),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      _buildMaintenanceActionPill(
                                        icon: Icons.edit_note_rounded,
                                        label: 'Edit All Fields',
                                        color: Colors.blueGrey.shade700,
                                        onTap: () =>
                                            ErpDocSheet.showViewAndEdit(
                                              context,
                                              doctype: _usingFcrm
                                                  ? 'CRM Lead'
                                                  : 'Lead',
                                              docname: docName,
                                              onSaved: _loadCrmData,
                                            ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildDealsTab() {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    final List<Map<String, dynamic>> filteredDeals = _deals.where((
      Map<String, dynamic> d,
    ) {
      final String status = (d['status'] ?? 'Qualification').toString();
      if (_selectedDealStage != 'All' && status != _selectedDealStage) {
        return false;
      }
      return ErpSearchBar.matchesQuery(d, _dealQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDealSheet,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('New Deal'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search Deal / Opportunity by organization, owner, or ID...',
            query: _dealQuery,
            onQueryChanged: (String v) => setState(() => _dealQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: _usingFcrm ? 'CRM Deal' : 'Opportunity',
              initialQuery: _dealQuery,
              onSaved: _loadCrmData,
            ),
            filters: <String>['All', ..._dealPipelineStages],
            selectedFilter: _selectedDealStage,
            onFilterChanged: (String f) =>
                setState(() => _selectedDealStage = f),
            resultCount: filteredDeals.length,
            totalCount: _deals.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCrmData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  if (filteredDeals.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No Deals / Opportunities match this filter.',
                          ),
                        ),
                      ),
                    )
                  else
                    ...filteredDeals.map((Map<String, dynamic> d) {
                      final String docName = (d['name'] ?? '').toString();
                      final String org =
                          (d['organization'] ??
                                  d['customer_name'] ??
                                  d['party_name'] ??
                                  docName)
                              .toString();
                      final String status = (d['status'] ?? 'Qualification')
                          .toString();
                      final String nextStage = _nextDealStage(status);
                      final Color stColor = _stageColor(status);
                      final double val =
                          ((d['deal_value'] ?? d['opportunity_amount'] ?? 0)
                                  as num?)
                              ?.toDouble() ??
                          0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: stColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showCrm360MaintenanceSheet(
                            record: d,
                            isLead: false,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: stColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      child: Icon(
                                        Icons.monetization_on_rounded,
                                        color: stColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            org,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            '$docName • Value: $sym${NumberFormat('#,##0').format(val)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: stColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: <Widget>[
                                      if (status != 'Won' &&
                                          status != 'Lost') ...<Widget>[
                                        _buildMaintenanceActionPill(
                                          icon: Icons.fast_forward_rounded,
                                          label: '1. Advance → $nextStage',
                                          color: _stageColor(nextStage),
                                          onTap: () => _updateRecordStatus(
                                            doctype: _usingFcrm
                                                ? 'CRM Deal'
                                                : 'Opportunity',
                                            name: docName,
                                            newStatus: nextStage,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      _buildMaintenanceActionPill(
                                        icon: Icons.note_add_rounded,
                                        label: '2. + Note',
                                        color: Colors.indigo,
                                        onTap: () => _showQuickCrmNoteSheet(
                                          referenceDocType: _usingFcrm
                                              ? 'CRM Deal'
                                              : 'Opportunity',
                                          referenceName: docName,
                                          displayName: org,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildMaintenanceActionPill(
                                        icon: Icons.add_task_rounded,
                                        label: '3. + ToDo',
                                        color: Colors.deepOrange,
                                        onTap: () => _showCreateTodoSheet(
                                          referenceDocType: _usingFcrm
                                              ? 'CRM Deal'
                                              : 'Opportunity',
                                          referenceName: docName,
                                          prefillTitle: 'Follow up Deal: $org',
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (status != 'Won') ...<Widget>[
                                        _buildMaintenanceActionPill(
                                          icon: Icons.emoji_events_rounded,
                                          label: 'Mark Won',
                                          color: Colors.green.shade700,
                                          onTap: () => _updateRecordStatus(
                                            doctype: _usingFcrm
                                                ? 'CRM Deal'
                                                : 'Opportunity',
                                            name: docName,
                                            newStatus: 'Won',
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      _buildMaintenanceActionPill(
                                        icon: Icons.edit_note_rounded,
                                        label: 'Edit All Fields',
                                        color: Colors.blueGrey.shade700,
                                        onTap: () =>
                                            ErpDocSheet.showViewAndEdit(
                                              context,
                                              doctype: _usingFcrm
                                                  ? 'CRM Deal'
                                                  : 'Opportunity',
                                              docname: docName,
                                              onSaved: _loadCrmData,
                                            ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildMaintenanceActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    final List<Map<String, dynamic>> filteredTasks = _crmTasks.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _crmTaskStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _crmTaskQuery);
    }).toList();

    final List<Map<String, dynamic>> filteredTodos = _todos.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _crmTaskStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _crmTaskQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTodoSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Follow-up ToDo'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search CRM Tasks & ToDos (title, assignee, due date, lead)...',
            query: _crmTaskQuery,
            onQueryChanged: (String v) => setState(() => _crmTaskQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'ToDo',
              initialQuery: _crmTaskQuery,
              onSaved: _loadCrmData,
            ),
            filters: const <String>['All', 'Open', 'Done', 'Closed', 'High'],
            selectedFilter: _crmTaskStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _crmTaskStatusFilter = f),
            resultCount: filteredTasks.length + filteredTodos.length,
            totalCount: _crmTasks.length + _todos.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCrmData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  if (filteredTasks.isNotEmpty) ...<Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Frappe CRM Follow-up Tasks (${filteredTasks.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_task_rounded, size: 16),
                          label: const Text('+ CRM Task'),
                          onPressed: () => ErpDocSheet.showCreate(
                            context,
                            doctype: 'CRM Task',
                            onCreated: _loadCrmData,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...filteredTasks.map((Map<String, dynamic> t) {
                      final String docName = (t['name'] ?? '').toString();
                      final String status = (t['status'] ?? 'Todo').toString();
                      final bool done =
                          status == 'Done' || status == 'Completed';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => ErpDocSheet.showViewAndEdit(
                            context,
                            doctype: 'CRM Task',
                            docname: docName,
                            onSaved: _loadCrmData,
                          ),
                          leading: Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: done ? Colors.green : Colors.orange,
                          ),
                          title: Text(
                            (t['title'] ?? docName).toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Priority: ${t['priority'] ?? 'Medium'} • Due: ${t['due_date'] ?? 'N/A'} ${t['reference_docname'] != null ? '• ${t['reference_docname']}' : ''}',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final String nextStatus = done ? 'Todo' : 'Done';
                              try {
                                await ErpApiClient.instance.updateDoc(
                                  'CRM Task',
                                  docName,
                                  <String, dynamic>{'status': nextStatus},
                                );
                                await _loadCrmData();
                              } catch (_) {}
                            },
                            child: Text(done ? 'Reopen' : 'Mark Done'),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Desk To-Do List (${filteredTodos.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...filteredTodos.map((Map<String, dynamic> td) {
                    final String docName = (td['name'] ?? '').toString();
                    final String rawDesc = (td['description'] ?? docName)
                        .toString()
                        .replaceAll(RegExp(r'<[^>]*>'), '');
                    final String status = (td['status'] ?? 'Open').toString();
                    final bool closed = status == 'Closed';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => ErpDocSheet.showViewAndEdit(
                          context,
                          doctype: 'ToDo',
                          docname: docName,
                          onSaved: _loadCrmData,
                        ),
                        leading: Icon(
                          closed
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: closed ? Colors.green : null,
                        ),
                        title: Text(
                          rawDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Status: $status • Priority: ${td['priority'] ?? 'Medium'} • Due: ${td['date'] ?? 'N/A'}',
                        ),
                        trailing: IconButton(
                          tooltip: closed ? 'Reopen ToDo' : 'Close ToDo',
                          icon: Icon(
                            closed
                                ? Icons.replay_rounded
                                : Icons.done_all_rounded,
                          ),
                          onPressed: () async {
                            try {
                              await ErpApiClient.instance.updateDoc(
                                'ToDo',
                                docName,
                                <String, dynamic>{
                                  'status': closed ? 'Open' : 'Closed',
                                },
                              );
                              await _loadCrmData();
                            } catch (_) {}
                          },
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

  Widget _buildNotesTab() {
    final List<Map<String, dynamic>> filteredNotes = _notes.where((
      Map<String, dynamic> row,
    ) {
      if (_crmNoteFilter != 'All') {
        final String refDt = (row['reference_doctype'] ?? '').toString();
        if (!refDt.toLowerCase().contains(_crmNoteFilter.toLowerCase())) {
          return false;
        }
      }
      return ErpSearchBar.matchesQuery(row, _crmNoteQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickCrmNoteSheet(
          referenceDocType: _usingFcrm ? 'CRM Lead' : 'Lead',
          referenceName: _leads.isNotEmpty
              ? (_leads.first['name'] ?? '').toString()
              : '',
          displayName: _leads.isNotEmpty
              ? (_leads.first['lead_name'] ??
                        _leads.first['organization'] ??
                        'CRM Follow-up')
                    .toString()
              : 'General CRM Note',
        ),
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('Log CRM Note'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search CRM Notes (title, content, linked Lead/Deal, author)...',
            query: _crmNoteQuery,
            onQueryChanged: (String v) => setState(() => _crmNoteQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: _usingFcrm ? 'FCRM Note' : 'Note',
              initialQuery: _crmNoteQuery,
              onSaved: _loadCrmData,
            ),
            filters: const <String>[
              'All',
              'Lead',
              'Deal',
              'Opportunity',
              'ToDo',
            ],
            selectedFilter: _crmNoteFilter,
            onFilterChanged: (String f) => setState(() => _crmNoteFilter = f),
            resultCount: filteredNotes.length,
            totalCount: _notes.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCrmData,
              child: filteredNotes.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        Center(
                          child: Text(
                            'No matching CRM Notes found. Tap "+ Note" on any Lead/Deal or "+ Log CRM Note" below.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: filteredNotes.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Map<String, dynamic> n = filteredNotes[i];
                        final String docName = (n['name'] ?? '').toString();
                        final String title =
                            (n['title'] ?? 'CRM Follow-up Note').toString();
                        final String content = (n['content'] ?? '')
                            .toString()
                            .replaceAll(RegExp(r'<[^>]*>'), '');
                        final String ref =
                            '${n['reference_doctype'] ?? ''} ${n['reference_docname'] ?? n['reference_name'] ?? ''}'
                                .trim();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: docName.isEmpty
                                ? null
                                : () => ErpDocSheet.showViewAndEdit(
                                    context,
                                    doctype: _usingFcrm ? 'FCRM Note' : 'Note',
                                    docname: docName,
                                    onSaved: _loadCrmData,
                                  ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.withValues(
                                alpha: 0.12,
                              ),
                              child: const Icon(
                                Icons.note_alt_rounded,
                                color: Colors.indigo,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$content\n${ref.isNotEmpty ? '$ref • ' : ''}${n['creation'] ?? ''}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(
                              Icons.edit_note_rounded,
                              size: 20,
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
}
