import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

class QuickTodoScreen extends StatefulWidget {
  const QuickTodoScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<QuickTodoScreen> createState() => _QuickTodoScreenState();
}

class _QuickTodoScreenState extends State<QuickTodoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _quickInputCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _addingQuick = false;
  String _quickPriority = 'Medium';
  DateTime _quickDueDate = DateTime.now();
  String _statusFilter = 'Open'; // 'All', 'Open', 'Due Today', 'High', 'Closed'

  List<Map<String, dynamic>> _todos = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _crmTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _activityNotes = <Map<String, dynamic>>[];

  static const List<String> _referenceDocTypes = <String>[
    'None',
    'CRM Lead',
    'CRM Deal',
    'Project',
    'Task',
    'Customer',
    'Sales Order',
    'Sales Invoice',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadTodosAndActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickInputCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTodosAndActivity() async {
    setState(() => _loading = true);

    try {
      final List<Map<String, dynamic>> todoRows = await ErpApiClient.instance
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
              'modified',
            ],
            orderBy: 'modified desc',
            limitPageLength: 80,
          );
      if (mounted) {
        setState(() => _todos = todoRows);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> taskRows = await ErpApiClient.instance
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
            limitPageLength: 50,
          );
      if (mounted) {
        setState(() => _crmTasks = taskRows);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> notes = await ErpApiClient.instance
          .getList(
            'Comment',
            fields: <String>[
              'name',
              'content',
              'reference_doctype',
              'reference_name',
              'owner',
              'creation',
            ],
            orderBy: 'creation desc',
            limitPageLength: 40,
          );
      if (mounted && notes.isNotEmpty) {
        setState(() => _activityNotes = notes);
      }
    } catch (_) {
      try {
        final List<Map<String, dynamic>> crmNotes = await ErpApiClient.instance
            .getList(
              'CRM Note',
              fields: <String>[
                'name',
                'title',
                'content',
                'reference_doctype',
                'reference_docname',
                'owner',
                'creation',
              ],
              limitPageLength: 40,
            );
        if (mounted) {
          setState(() => _activityNotes = crmNotes);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitInlineQuickTodo() async {
    final String text = _quickInputCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a task description first.')),
      );
      return;
    }

    setState(() => _addingQuick = true);
    final UserSession? session = ErpApiClient.instance.session;
    final String dueStr = DateFormat('yyyy-MM-dd').format(_quickDueDate);

    try {
      await ErpApiClient.instance.createDoc('ToDo', <String, dynamic>{
        'description': text,
        'priority': _quickPriority,
        'status': 'Open',
        'date': dueStr,
        if (session != null && session.email.isNotEmpty)
          'allocated_to': session.email,
      });
      _quickInputCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('ToDo added for $dueStr ($_quickPriority)!'),
          ),
        );
      }
      await _loadTodosAndActivity();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(ErpApiClient.formatErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingQuick = false);
      }
    }
  }

  Future<void> _toggleTodoStatus(Map<String, dynamic> td) async {
    final String name = (td['name'] ?? '').toString();
    final String currentStatus = (td['status'] ?? 'Open').toString();
    final bool isClosed =
        currentStatus == 'Closed' || currentStatus == 'Cancelled';
    final String nextStatus = isClosed ? 'Open' : 'Closed';

    try {
      await ErpApiClient.instance.updateDoc('ToDo', name, <String, dynamic>{
        'status': nextStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('ToDo $name marked $nextStatus!'),
          ),
        );
      }
      await _loadTodosAndActivity();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showLogActivitySheet({
    String referenceDocType = 'ToDo',
    String referenceName = '',
    String taskTitle = '',
  }) async {
    final TextEditingController noteCtrl = TextEditingController();
    bool markClosedToo = false;
    bool saving = false;

    final List<String> quickTemplates = <String>[
      '✅ Task completed & verified',
      '📞 Called client — follow up tomorrow',
      '💬 Sent details on WhatsApp',
      '📍 Site visit / inspection done',
      '⏳ Waiting for client / manager approval',
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
                    const Text(
                      'Track Activity / Log Progress Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (taskTitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        taskTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '1-Tap Quick Activity Templates:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickTemplates
                          .map(
                            (String tpl) => ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                tpl,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  noteCtrl.text = tpl;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Activity Note / Follow-up Details',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (referenceDocType == 'ToDo' &&
                        referenceName.isNotEmpty) ...<Widget>[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Also mark this ToDo as Completed'),
                        value: markClosedToo,
                        onChanged: (bool? v) =>
                            setModalState(() => markClosedToo = v ?? false),
                      ),
                    ],
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
                          : const Icon(Icons.history_edu_rounded),
                      label: Text(
                        saving ? 'Saving Activity...' : 'Save Activity Log',
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (noteCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                try {
                                  await ErpApiClient.instance.createDoc(
                                    'Comment',
                                    <String, dynamic>{
                                      'comment_type': 'Comment',
                                      'reference_doctype': referenceDocType,
                                      'reference_name': referenceName.isNotEmpty
                                          ? referenceName
                                          : 'ToDo',
                                      'content': noteCtrl.text.trim(),
                                    },
                                  );
                                } catch (_) {
                                  await ErpApiClient.instance.createDoc(
                                    'CRM Note',
                                    <String, dynamic>{
                                      'title': taskTitle.isNotEmpty
                                          ? taskTitle
                                          : 'Activity Log',
                                      'content': noteCtrl.text.trim(),
                                      'reference_doctype': referenceDocType,
                                      'reference_docname': referenceName,
                                    },
                                  );
                                }

                                if (markClosedToo &&
                                    referenceDocType == 'ToDo' &&
                                    referenceName.isNotEmpty) {
                                  await ErpApiClient.instance.updateDoc(
                                    'ToDo',
                                    referenceName,
                                    <String, dynamic>{'status': 'Closed'},
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
                                      content: const Text('Activity logged!'),
                                    ),
                                  );
                                }
                                await _loadTodosAndActivity();
                              } catch (e) {
                                setModalState(() => saving = false);
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

  Future<void> _showDetailedCreateTodoSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController descCtrl = TextEditingController();
    final TextEditingController assigneeCtrl = TextEditingController(
      text: session?.email ?? '',
    );
    final TextEditingController refNameCtrl = TextEditingController();
    String priority = 'Medium';
    String refType = 'None';
    DateTime dueDate = DateTime.now();
    bool alsoCreateCrmTask = false;
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
                      'New Detailed ToDo & Activity Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Task Description / Action Item *',
                        border: OutlineInputBorder(),
                      ),
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
                            label: Text(
                              'Due: ${DateFormat('yyyy-MM-dd').format(dueDate)}',
                            ),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: assigneeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assign To (User Email)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: refType,
                            decoration: const InputDecoration(
                              labelText: 'Link DocType (Optional)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _referenceDocTypes
                                .map(
                                  (String r) => DropdownMenuItem<String>(
                                    value: r,
                                    child: Text(
                                      r,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setModalState(() => refType = v);
                              }
                            },
                          ),
                        ),
                        if (refType != 'None') ...<Widget>[
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: refNameCtrl,
                              decoration: InputDecoration(
                                labelText: '$refType ID',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Also sync to Frappe CRM Tasks'),
                      value: alsoCreateCrmTask,
                      onChanged: (bool? v) =>
                          setModalState(() => alsoCreateCrmTask = v ?? false),
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
                          : const Icon(Icons.add_task_rounded),
                      label: Text(saving ? 'Saving...' : 'Create ToDo Task'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (descCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setModalState(() => saving = true);
                              final String dueStr = DateFormat('yyyy-MM-dd')
                                  .format(dueDate);
                              try {
                                await ErpApiClient.instance.createDoc(
                                  'ToDo',
                                  <String, dynamic>{
                                    'description': descCtrl.text.trim(),
                                    'priority': priority,
                                    'status': 'Open',
                                    'date': dueStr,
                                    if (assigneeCtrl.text.trim().isNotEmpty)
                                      'allocated_to': assigneeCtrl.text.trim(),
                                    if (refType != 'None' &&
                                        refNameCtrl.text
                                            .trim()
                                            .isNotEmpty) ...<String, dynamic>{
                                      'reference_type': refType,
                                      'reference_name': refNameCtrl.text.trim(),
                                    },
                                  },
                                );
                                if (alsoCreateCrmTask) {
                                  try {
                                    await ErpApiClient.instance.createDoc(
                                      'CRM Task',
                                      <String, dynamic>{
                                        'title': descCtrl.text.trim(),
                                        'priority': priority,
                                        'status': 'Todo',
                                        'due_date': dueStr,
                                        if (refType != 'None' &&
                                            refNameCtrl.text
                                                .trim()
                                                .isNotEmpty) ...<
                                          String,
                                          dynamic
                                        >{
                                          'reference_doctype': refType,
                                          'reference_docname': refNameCtrl.text
                                              .trim(),
                                        },
                                      },
                                    );
                                  } catch (_) {}
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                await _loadTodosAndActivity();
                              } catch (e) {
                                setModalState(() => saving = false);
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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.blue;
      case 'Medium':
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final int openCount = _todos
        .where((Map<String, dynamic> t) => (t['status'] ?? 'Open') == 'Open')
        .length;
    final int highCount = _todos
        .where(
          (Map<String, dynamic> t) =>
              (t['status'] ?? 'Open') == 'Open' && t['priority'] == 'High',
        )
        .length;
    final int dueTodayCount = _todos
        .where(
          (Map<String, dynamic> t) =>
              (t['status'] ?? 'Open') == 'Open' &&
              (t['date'] ?? '').toString() == todayStr,
        )
        .length;
    final int closedCount = _todos
        .where((Map<String, dynamic> t) => t['status'] == 'Closed')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick ToDo & Activity Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Log Activity Note',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () => _showLogActivitySheet(),
          ),
          IconButton(
            tooltip: 'Refresh ToDos',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTodosAndActivity,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
              icon: const Icon(Icons.check_circle_outline_rounded),
              text: 'ToDo Dock ($openCount Open)',
            ),
            Tab(
              icon: const Icon(Icons.timeline_rounded),
              text: 'Activity Log (${_activityNotes.length})',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDetailedCreateTodoSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Detailed ToDo'),
      ),
      body: _loading && _todos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildTodoDockTab(
                  colors: colors,
                  todayStr: todayStr,
                  openCount: openCount,
                  highCount: highCount,
                  dueTodayCount: dueTodayCount,
                  closedCount: closedCount,
                ),
                _buildActivityTimelineTab(colors),
              ],
            ),
    );
  }

  Widget _buildTodoDockTab({
    required ColorScheme colors,
    required String todayStr,
    required int openCount,
    required int highCount,
    required int dueTodayCount,
    required int closedCount,
  }) {
    final String query = _searchCtrl.text.trim().toLowerCase();
    final List<Map<String, dynamic>> filteredTodos = _todos.where((
      Map<String, dynamic> td,
    ) {
      final String status = (td['status'] ?? 'Open').toString();
      final String priority = (td['priority'] ?? 'Medium').toString();
      final String date = (td['date'] ?? '').toString();
      final String desc = (td['description'] ?? '').toString().toLowerCase();
      final String ref =
          '${td['reference_type'] ?? ''} ${td['reference_name'] ?? ''}'
              .toLowerCase();

      if (_statusFilter == 'Open' && status != 'Open') {
        return false;
      }
      if (_statusFilter == 'Closed' && status != 'Closed') {
        return false;
      }
      if (_statusFilter == 'High' && (status != 'Open' || priority != 'High')) {
        return false;
      }
      if (_statusFilter == 'Due Today' &&
          (status != 'Open' ||
              (date.isNotEmpty && date.compareTo(todayStr) > 0))) {
        return false;
      }
      if (query.isNotEmpty && !desc.contains(query) && !ref.contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadTodosAndActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: <Widget>[
          // 1-Tap Instant Quick-Add ToDo Card
          Card(
            elevation: 0,
            color: colors.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.bolt_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'Quick Add To-Do',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final DateTime? p = await showDatePicker(
                            context: context,
                            initialDate: _quickDueDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) {
                            setState(() => _quickDueDate = p);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.calendar_today, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM dd').format(_quickDueDate),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _quickInputCtrl,
                          onSubmitted: (_) => _submitInlineQuickTodo(),
                          decoration: InputDecoration(
                            hintText: 'What needs to be done? (e.g. Call client, Check stock)...',
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
                      FilledButton(
                        onPressed: _addingQuick ? null : _submitInlineQuickTodo,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _addingQuick
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Priority:',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      ...const <String>['High', 'Medium', 'Low'].map((
                        String p,
                      ) {
                        final bool selected = _quickPriority == p;
                        final Color c = _priorityColor(p);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              p,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: selected,
                            visualDensity: VisualDensity.compact,
                            selectedColor: c.withValues(alpha: 0.2),
                            onSelected: (_) {
                              setState(() => _quickPriority = p);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip('Open', 'Open ($openCount)', Colors.teal),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'High',
                  'High Priority ($highCount)',
                  Colors.red,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Due Today',
                  'Due / Overdue ($dueTodayCount)',
                  Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'Closed',
                  'Completed ($closedCount)',
                  Colors.green,
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'All',
                  'All (${_todos.length})',
                  colors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Box
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search ToDos or linked Lead/Deal/Project...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (filteredTodos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No matching ToDo tasks. Use the Quick Add bar above to add one in 1 tap!',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ...filteredTodos.map((Map<String, dynamic> td) {
              final String name = (td['name'] ?? '').toString();
              final String rawDesc = (td['description'] ?? name)
                  .toString()
                  .replaceAll(RegExp(r'<[^>]*>'), '');
              final String status = (td['status'] ?? 'Open').toString();
              final bool isClosed = status == 'Closed';
              final String priority = (td['priority'] ?? 'Medium').toString();
              final Color pColor = _priorityColor(priority);
              final String dueDate = (td['date'] ?? '').toString();
              final String refType = (td['reference_type'] ?? '').toString();
              final String refName = (td['reference_name'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isClosed
                        ? Colors.grey.withValues(alpha: 0.2)
                        : pColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Checkbox(
                            value: isClosed,
                            activeColor: Colors.green,
                            onChanged: (_) => _toggleTodoStatus(td),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    rawDesc,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: isClosed
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isClosed ? Colors.grey : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          priority,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: pColor,
                                          ),
                                        ),
                                      ),
                                      if (dueDate.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Due: $dueDate',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      if (refType.isNotEmpty &&
                                          refName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '$refType: $refName',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(
                              Icons.history_edu_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Log Activity',
                              style: TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _showLogActivitySheet(
                              referenceDocType: 'ToDo',
                              referenceName: name,
                              taskTitle: rawDesc,
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: Icon(
                              isClosed
                                  ? Icons.replay_rounded
                                  : Icons.check_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isClosed ? 'Reopen' : 'Done',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _toggleTodoStatus(td),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          if (_crmTasks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Text(
              'Synced Frappe CRM Tasks',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._crmTasks.map((Map<String, dynamic> t) {
              final String status = (t['status'] ?? 'Todo').toString();
              final bool done = status == 'Done' || status == 'Completed';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: done ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    (t['title'] ?? t['name'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Priority: ${t['priority'] ?? 'Medium'} • Due: ${t['due_date'] ?? 'N/A'}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final String nextStatus = done ? 'Todo' : 'Done';
                      try {
                        await ErpApiClient.instance.updateDoc(
                          'CRM Task',
                          (t['name'] ?? '').toString(),
                          <String, dynamic>{'status': nextStatus},
                        );
                        await _loadTodosAndActivity();
                      } catch (_) {}
                    },
                    child: Text(done ? 'Reopen' : 'Mark Done'),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color color) {
    final bool selected = _statusFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? color : null,
        ),
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.16),
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }

  Widget _buildActivityTimelineTab(ColorScheme colors) {
    return RefreshIndicator(
      onRefresh: _loadTodosAndActivity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: <Widget>[
          Card(
            color: colors.secondaryContainer.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primary,
                child: const Icon(
                  Icons.add_comment_rounded,
                  color: Colors.white,
                ),
              ),
              title: const Text(
                'Log Daily Activity / Follow-up Note',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Record client calls, site visits, or task progress in 1 tap',
                style: TextStyle(fontSize: 12),
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _showLogActivitySheet(),
                child: const Text('Log Note'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recent Activity & Progress Notes',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_activityNotes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No activity logs yet. Tap "Log Note" above or "Log Activity" on any ToDo task.',
                ),
              ),
            )
          else
            ..._activityNotes.map((Map<String, dynamic> n) {
              final String rawContent = (n['content'] ?? n['title'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'<[^>]*>'), '');
              final String refDocType = (n['reference_doctype'] ?? 'Activity')
                  .toString();
              final String refName =
                  (n['reference_name'] ?? n['reference_docname'] ?? '')
                      .toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.14),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(
                    rawContent,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$refDocType ${refName.isNotEmpty ? '• $refName' : ''}\nBy ${n['owner'] ?? 'User'} • ${n['creation'] ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}
