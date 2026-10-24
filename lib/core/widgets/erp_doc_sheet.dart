import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_session.dart';
import '../network/api_client.dart';

class ErpDocSheet {
  ErpDocSheet._();

  static const Set<String> _systemReadOnlyKeys = <String>{
    'name',
    'doctype',
    'owner',
    'creation',
    'modified',
    'modified_by',
    'idx',
    'docstatus',
    'lft',
    'rgt',
    'old_parent',
  };

  static String _stripHtml(String input) {
    if (!input.contains('<')) {
      return input;
    }
    return input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  static String _humanizeFieldName(String key) {
    return key
        .split('_')
        .where((String w) => w.isNotEmpty)
        .map((String w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String? _childRowKeyLinkDocType(String key) {
    switch (key) {
      case 'item_code':
        return 'Item';
      case 'warehouse':
      case 's_warehouse':
      case 't_warehouse':
        return 'Warehouse';
      case 'cost_center':
        return 'Cost Center';
      case 'account':
        return 'Account';
      case 'expense_type':
        return 'Expense Claim Type';
      case 'activity_type':
        return 'Activity Type';
      case 'project':
        return 'Project';
      case 'task':
        return 'Task';
      case 'asset':
        return 'Asset';
      case 'to_employee':
      case 'from_employee':
        return 'Employee';
      case 'salary_component':
        return 'Salary Component';
      default:
        return null;
    }
  }

  static Map<String, dynamic> _defaultChildRowTemplate(String tableField) {
    final UserSession? s = ErpApiClient.instance.session;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String defaultCc = (s != null && s.costCenter.isNotEmpty)
        ? s.costCenter
        : '101 - Head Office CC - DIBL';
    switch (tableField) {
      case 'items':
        return <String, dynamic>{
          'item_code': '',
          'qty': 1,
          'rate': 0.0,
          'warehouse': '',
          'cost_center': defaultCc,
        };
      case 'accounts':
        return <String, dynamic>{
          'account': '',
          'debit_in_account_currency': 0.0,
          'credit_in_account_currency': 0.0,
          'cost_center': defaultCc,
        };
      case 'expenses':
        return <String, dynamic>{
          'expense_date': today,
          'expense_type': '',
          'description': '',
          'amount': 0.0,
          'sanctioned_amount': 0.0,
        };
      case 'time_logs':
        return <String, dynamic>{
          'activity_type': 'Execution',
          'hours': 1.0,
          'project': '',
          'task': '',
          'description': '',
        };
      case 'assets':
        return <String, dynamic>{
          'asset': '',
          'source_location': '',
          'target_location': '',
          'to_employee': '',
        };
      case 'earnings':
      case 'deductions':
        return <String, dynamic>{'salary_component': '', 'amount': 0.0};
      default:
        return <String, dynamic>{'description': '', 'qty': 1, 'amount': 0.0};
    }
  }

  /// Opens a full interactive ERPNext Document Viewer & Editor bottom sheet
  /// respecting the user's real ERPNext access (`write`, `submit`, `cancel`, `delete`).
  static Future<bool> showViewAndEdit(
    BuildContext context, {
    required String doctype,
    required String docname,
    VoidCallback? onSaved,
  }) async {
    if (docname.trim().isEmpty) {
      return false;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> doc = <String, dynamic>{};
    Map<String, dynamic> permissions = <String, dynamic>{
      'read': 1,
      'write': 1,
      'create': 1,
      'submit': 1,
      'cancel': 1,
      'delete': 1,
    };
    List<Map<String, dynamic>> metaFields = <Map<String, dynamic>>[];

    try {
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          ErpApiClient.instance.getDocWithPermissions(doctype, docname),
          ErpApiClient.instance.getDocTypeFields(doctype),
        ],
      );
      final Map<String, dynamic> docWrap = results[0] as Map<String, dynamic>;
      doc = Map<String, dynamic>.from(
        (docWrap['doc'] as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{},
      );
      if (docWrap['permissions'] is Map) {
        permissions = Map<String, dynamic>.from(
          docWrap['permissions'] as Map<dynamic, dynamic>,
        );
      }
      metaFields = results[1] as List<Map<String, dynamic>>;
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
      return false;
    }

    if (!context.mounted) {
      return false;
    }
    Navigator.pop(context);

    bool savedAny = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return _ErpDocEditModal(
          doctype: doctype,
          docname: docname,
          initialDoc: doc,
          permissions: permissions,
          metaFields: metaFields,
          onSaved: () {
            savedAny = true;
            onSaved?.call();
          },
        );
      },
    );
    return savedAny;
  }

  /// Opens a dynamic ERPNext Document Creation sheet driven by the server's
  /// live DocType schema (including Custom Fields & Property Setters).
  static Future<Map<String, dynamic>?> showCreate(
    BuildContext context, {
    required String doctype,
    Map<String, dynamic>? initialValues,
    VoidCallback? onCreated,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> metaFields = <Map<String, dynamic>>[];
    Map<String, dynamic> permissions = <String, dynamic>{
      'read': 1,
      'write': 1,
      'create': 1,
      'submit': 0,
      'cancel': 0,
      'delete': 0,
    };
    try {
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        ErpApiClient.instance.getDocTypeFields(doctype),
        ErpApiClient.instance.getDocTypePermissions(doctype),
      ]);
      metaFields = res[0] as List<Map<String, dynamic>>;
      permissions = res[1] as Map<String, dynamic>;
    } catch (_) {}

    if (!context.mounted) {
      return null;
    }
    Navigator.pop(context);

    Map<String, dynamic>? createdDoc;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return _ErpDocCreateModal(
          doctype: doctype,
          metaFields: metaFields,
          permissions: permissions,
          initialValues: initialValues ?? <String, dynamic>{},
          onCreated: (Map<String, dynamic> doc) {
            createdDoc = doc;
            onCreated?.call();
          },
        );
      },
    );
    return createdDoc;
  }

  /// Helper dialog to search & pick a record from any linked ERPNext DocType.
  static Future<String?> pickLinkValue(
    BuildContext context, {
    required String linkDocType,
    String? currentValue,
  }) async {
    final TextEditingController searchCtrl = TextEditingController();
    List<String> options = await ErpApiClient.instance.searchLinkOptions(
      linkDocType,
    );
    if (!context.mounted) {
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        bool searching = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (BuildContext context, ScrollController scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Select $linkDocType',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search $linkDocType...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: searching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            onPressed: () async {
                              setModalState(() => searching = true);
                              final List<String> next = await ErpApiClient
                                  .instance
                                  .searchLinkOptions(
                                    linkDocType,
                                    query: searchCtrl.text.trim(),
                                  );
                              setModalState(() {
                                options = next;
                                searching = false;
                              });
                            },
                          ),
                        ),
                        onChanged: (String val) async {
                          final List<String> next = await ErpApiClient.instance
                              .searchLinkOptions(linkDocType, query: val);
                          setModalState(() => options = next);
                        },
                      ),
                      const SizedBox(height: 8),
                      if (searchCtrl.text.trim().isNotEmpty &&
                          !options.contains(searchCtrl.text.trim()))
                        ListTile(
                          leading: const Icon(
                            Icons.edit_note_rounded,
                            color: Colors.teal,
                          ),
                          title: Text('Use "${searchCtrl.text.trim()}"'),
                          onTap: () =>
                              Navigator.pop(ctx, searchCtrl.text.trim()),
                        ),
                      Expanded(
                        child: options.isEmpty
                            ? const Center(
                                child: Text('No matching records found.'),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                itemCount: options.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int i) {
                                  final String opt = options[i];
                                  final bool isSelected = opt == currentValue;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      opt,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.teal,
                                          )
                                        : null,
                                    onTap: () => Navigator.pop(ctx, opt),
                                  );
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
}

class _ErpDocEditModal extends StatefulWidget {
  const _ErpDocEditModal({
    required this.doctype,
    required this.docname,
    required this.initialDoc,
    required this.permissions,
    required this.metaFields,
    required this.onSaved,
  });

  final String doctype;
  final String docname;
  final Map<String, dynamic> initialDoc;
  final Map<String, dynamic> permissions;
  final List<Map<String, dynamic>> metaFields;
  final VoidCallback onSaved;

  @override
  State<_ErpDocEditModal> createState() => _ErpDocEditModalState();
}

class _ErpDocEditModalState extends State<_ErpDocEditModal> {
  late Map<String, dynamic> _doc;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, dynamic> _changedValues = <String, dynamic>{};
  bool _saving = false;
  bool _showAllFields = false;

  bool get _canWrite {
    final int writePerm = (widget.permissions['write'] as num?)?.toInt() ?? 1;
    final int docstatus = (_doc['docstatus'] as num?)?.toInt() ?? 0;
    return writePerm == 1 && docstatus != 2;
  }

  bool get _canSubmit {
    final int submitPerm = (widget.permissions['submit'] as num?)?.toInt() ?? 0;
    final int docstatus = (_doc['docstatus'] as num?)?.toInt() ?? 0;
    return submitPerm == 1 && docstatus == 0;
  }

  bool get _canCancel {
    final int cancelPerm = (widget.permissions['cancel'] as num?)?.toInt() ?? 0;
    final int docstatus = (_doc['docstatus'] as num?)?.toInt() ?? 0;
    return cancelPerm == 1 && docstatus == 1;
  }

  bool get _canDelete {
    final int delPerm = (widget.permissions['delete'] as num?)?.toInt() ?? 0;
    final int docstatus = (_doc['docstatus'] as num?)?.toInt() ?? 0;
    return delPerm == 1 && docstatus == 0;
  }

  bool get _canCreate {
    final int createPerm = (widget.permissions['create'] as num?)?.toInt() ?? 1;
    return createPerm == 1;
  }

  @override
  void initState() {
    super.initState();
    _doc = Map<String, dynamic>.from(widget.initialDoc);
    _initControllers();
  }

  void _initControllers() {
    for (final MapEntry<String, dynamic> entry in _doc.entries) {
      if (entry.value is! List && entry.value is! Map) {
        final String raw = (entry.value ?? '').toString();
        _controllers[entry.key] = TextEditingController(
          text: ErpDocSheet._stripHtml(raw),
        );
      }
    }
    for (final Map<String, dynamic> mf in widget.metaFields) {
      final String fn = (mf['fieldname'] ?? '').toString();
      if (fn.isNotEmpty && !_controllers.containsKey(fn)) {
        final String raw = (_doc[fn] ?? mf['default'] ?? '').toString();
        _controllers[fn] = TextEditingController(
          text: ErpDocSheet._stripHtml(raw),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _resolveTitle() {
    for (final String k in const <String>[
      'project_name',
      'subject',
      'title',
      'customer_name',
      'supplier_name',
      'employee_name',
      'item_name',
      'asset_name',
      'lead_name',
      'organization',
      'party_name',
      'description',
    ]) {
      final String val = (_doc[k] ?? '').toString().trim();
      if (val.isNotEmpty) {
        return ErpDocSheet._stripHtml(val);
      }
    }
    return widget.docname;
  }

  List<Map<String, dynamic>> _buildEffectiveFields() {
    final Map<String, Map<String, dynamic>> byName =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> mf in widget.metaFields) {
      final String fn = (mf['fieldname'] ?? '').toString();
      if (fn.isNotEmpty && !ErpDocSheet._systemReadOnlyKeys.contains(fn)) {
        byName[fn] = Map<String, dynamic>.from(mf);
      }
    }
    for (final MapEntry<String, dynamic> e in _doc.entries) {
      final String fn = e.key;
      if (fn.startsWith('_') ||
          ErpDocSheet._systemReadOnlyKeys.contains(fn) ||
          byName.containsKey(fn)) {
        continue;
      }
      if (e.value is List) {
        byName[fn] = <String, dynamic>{
          'fieldname': fn,
          'label': ErpDocSheet._humanizeFieldName(fn),
          'fieldtype': 'Table',
          'read_only': 0,
        };
      } else if (e.value is! Map) {
        String inferredType = 'Data';
        if (fn.endsWith('_date') || fn == 'date') {
          inferredType = 'Date';
        } else if (fn == 'status' && widget.doctype == 'Project') {
          inferredType = 'Select';
        } else if (fn == 'priority') {
          inferredType = 'Select';
        } else if (e.value is num) {
          inferredType = 'Float';
        }
        byName[fn] = <String, dynamic>{
          'fieldname': fn,
          'label': ErpDocSheet._humanizeFieldName(fn),
          'fieldtype': inferredType,
          'read_only': 0,
        };
      }
    }

    final List<Map<String, dynamic>> all = byName.values.toList();
    if (_showAllFields) {
      return all;
    }

    return all.where((Map<String, dynamic> f) {
      final String fn = (f['fieldname'] ?? '').toString();
      final int reqd = (f['reqd'] as num?)?.toInt() ?? 0;
      final int readOnly = (f['read_only'] as num?)?.toInt() ?? 0;
      final dynamic currentVal = _doc[fn];
      final bool hasVal =
          currentVal != null &&
          currentVal.toString().trim().isNotEmpty &&
          currentVal.toString() != '0' &&
          currentVal.toString() != '0.0';
      return reqd == 1 || readOnly == 0 || hasVal;
    }).toList();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> payload = <String, dynamic>{..._changedValues};
      if (payload.isEmpty) {
        for (final MapEntry<String, TextEditingController> entry
            in _controllers.entries) {
          final String key = entry.key;
          if (ErpDocSheet._systemReadOnlyKeys.contains(key)) {
            continue;
          }
          final String newText = entry.value.text.trim();
          final String oldText = ErpDocSheet._stripHtml(
            (_doc[key] ?? '').toString(),
          ).trim();
          if (newText != oldText) {
            payload[key] = newText;
          }
        }
      }

      if (payload.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
        }
        return;
      }

      final Map<String, dynamic> updated = await ErpApiClient.instance
          .updateDoc(widget.doctype, widget.docname, payload);
      setState(() {
        _doc = <String, dynamic>{..._doc, ...updated};
        _changedValues.clear();
      });
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('${widget.doctype} ${widget.docname} updated!'),
          ),
        );
      }
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
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _changeDocStatus(int targetStatus) async {
    setState(() => _saving = true);
    try {
      await ErpApiClient.instance.updateDoc(
        widget.doctype,
        widget.docname,
        <String, dynamic>{'docstatus': targetStatus},
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              targetStatus == 1
                  ? '${widget.doctype} ${widget.docname} Submitted!'
                  : '${widget.doctype} ${widget.docname} Cancelled.',
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
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteDocument() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) => AlertDialog(
        title: Text('Delete ${widget.doctype}?'),
        content: Text(
          'Are you sure you want to delete ${widget.docname}? This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ErpApiClient.instance.deleteDoc(widget.doctype, widget.docname);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.doctype} ${widget.docname} deleted.'),
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
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildFieldInput(Map<String, dynamic> field) {
    final String fn = (field['fieldname'] ?? '').toString();
    final String label = (field['label'] ?? ErpDocSheet._humanizeFieldName(fn))
        .toString();
    final String ft = (field['fieldtype'] ?? 'Data').toString();
    final int reqd = (field['reqd'] as num?)?.toInt() ?? 0;
    final int fieldReadOnly = (field['read_only'] as num?)?.toInt() ?? 0;
    final int docstatus = (_doc['docstatus'] as num?)?.toInt() ?? 0;
    final bool isEditable =
        _canWrite &&
        fieldReadOnly == 0 &&
        (docstatus == 0 ||
            !field.containsKey('allow_on_submit') ||
            field['allow_on_submit'] == 1);

    if (ft == 'Table') {
      final List<dynamic> rows = (_doc[fn] as List<dynamic>?) ?? <dynamic>[];
      return _buildChildTableWidget(fn, label, rows, isEditable);
    }

    final TextEditingController ctrl = _controllers.putIfAbsent(
      fn,
      () => TextEditingController(
        text: ErpDocSheet._stripHtml((_doc[fn] ?? '').toString()),
      ),
    );

    final String labelWithReq = reqd == 1 ? '$label *' : label;

    if (ft == 'Check') {
      final bool checked =
          (_changedValues[fn] ?? _doc[fn]) == 1 ||
          (_changedValues[fn] ?? _doc[fn]) == true ||
          (_changedValues[fn] ?? _doc[fn]) == '1';
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(labelWithReq, style: const TextStyle(fontSize: 13)),
        value: checked,
        onChanged: isEditable
            ? (bool v) {
                setState(() {
                  _changedValues[fn] = v ? 1 : 0;
                  _doc[fn] = v ? 1 : 0;
                });
              }
            : null,
      );
    }

    if (ft == 'Select') {
      final String rawOpts = (field['options'] ?? '').toString();
      final List<String> opts = rawOpts
          .split('\n')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      final String currentVal = ctrl.text.trim();
      if (currentVal.isNotEmpty && !opts.contains(currentVal)) {
        opts.insert(0, currentVal);
      }
      if (opts.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: opts.contains(currentVal) ? currentVal : opts.first,
            decoration: InputDecoration(
              labelText: labelWithReq,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: opts
                .map(
                  (String o) => DropdownMenuItem<String>(
                    value: o,
                    child: Text(o, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: isEditable
                ? (String? v) {
                    if (v != null) {
                      setState(() {
                        ctrl.text = v;
                        _changedValues[fn] = v;
                        _doc[fn] = v;
                      });
                    }
                  }
                : null,
          ),
        );
      }
    }

    if (ft == 'Link') {
      final String targetDocType = (field['options'] ?? '').toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          readOnly: !isEditable,
          onChanged: (String v) => _changedValues[fn] = v.trim(),
          decoration: InputDecoration(
            labelText:
                '$labelWithReq ${targetDocType.isNotEmpty ? '($targetDocType)' : ''}',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: isEditable && targetDocType.isNotEmpty
                ? IconButton(
                    tooltip: 'Select $targetDocType',
                    icon: const Icon(Icons.manage_search_rounded),
                    onPressed: () async {
                      final String? picked = await ErpDocSheet.pickLinkValue(
                        context,
                        linkDocType: targetDocType,
                        currentValue: ctrl.text.trim(),
                      );
                      if (picked != null) {
                        setState(() {
                          ctrl.text = picked;
                          _changedValues[fn] = picked;
                          _doc[fn] = picked;
                        });
                      }
                    },
                  )
                : null,
          ),
        ),
      );
    }

    if (ft == 'Date' || ft == 'Datetime') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          readOnly: !isEditable,
          onChanged: (String v) => _changedValues[fn] = v.trim(),
          decoration: InputDecoration(
            labelText: labelWithReq,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: isEditable
                ? IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    onPressed: () async {
                      final DateTime initial =
                          DateTime.tryParse(ctrl.text.trim()) ?? DateTime.now();
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        final String formatted = ft == 'Datetime'
                            ? '${DateFormat('yyyy-MM-dd').format(picked)} 09:00:00'
                            : DateFormat('yyyy-MM-dd').format(picked);
                        setState(() {
                          ctrl.text = formatted;
                          _changedValues[fn] = formatted;
                          _doc[fn] = formatted;
                        });
                      }
                    },
                  )
                : null,
          ),
        ),
      );
    }

    final bool isNumeric =
        ft == 'Currency' || ft == 'Float' || ft == 'Int' || ft == 'Percent';
    final bool isMultiline =
        ft == 'Text' ||
        ft == 'Small Text' ||
        ft == 'Text Editor' ||
        ft == 'Long Text';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        readOnly: !isEditable,
        maxLines: isMultiline ? 3 : 1,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (String v) {
          if (ft == 'Int') {
            _changedValues[fn] = int.tryParse(v.trim()) ?? 0;
          } else if (isNumeric) {
            _changedValues[fn] = double.tryParse(v.trim()) ?? 0.0;
          } else {
            _changedValues[fn] = v.trim();
          }
        },
        decoration: InputDecoration(
          labelText: labelWithReq,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: !isEditable,
        ),
      ),
    );
  }

  Widget _buildChildTableWidget(
    String fieldname,
    String label,
    List<dynamic> rows,
    bool isEditable,
  ) {
    if (rows.isEmpty && !isEditable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '$label (${rows.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isEditable)
                  TextButton.icon(
                    onPressed: () {
                      final Map<String, dynamic> template =
                          rows.isNotEmpty && rows.first is Map
                          ? <String, dynamic>{
                              for (final MapEntry<dynamic, dynamic> e
                                  in (rows.first as Map<dynamic, dynamic>)
                                      .entries)
                                if (!ErpDocSheet._systemReadOnlyKeys.contains(
                                      e.key.toString(),
                                    ) &&
                                    e.key.toString() != 'parent' &&
                                    e.key.toString() != 'parentfield' &&
                                    e.key.toString() != 'parenttype')
                                  e.key.toString(): e.value is num ? 0 : '',
                            }
                          : ErpDocSheet._defaultChildRowTemplate(fieldname);
                      _editChildRowDialog(
                        fieldname,
                        rows.length,
                        template,
                        rows,
                        isNewRow: true,
                      );
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      '+ Add Row',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.asMap().entries.map((MapEntry<int, dynamic> entry) {
              final int idx = entry.key;
              final Map<String, dynamic> r = Map<String, dynamic>.from(
                entry.value as Map<dynamic, dynamic>,
              );
              final String primary =
                  (r['item_name'] ??
                          r['item_code'] ??
                          r['account'] ??
                          r['expense_type'] ??
                          r['salary_component'] ??
                          r['activity_type'] ??
                          r['asset'] ??
                          r['user'] ??
                          r['description'] ??
                          r['name'] ??
                          'Row ${idx + 1}')
                      .toString();
              final String secondary = <String>[
                if (r['qty'] != null) 'Qty: ${r['qty']}',
                if (r['rate'] != null) 'Rate: ${r['rate']}',
                if (r['amount'] != null) 'Amt: ${r['amount']}',
                if (r['hours'] != null) 'Hrs: ${r['hours']}',
                if (r['debit_in_account_currency'] != null &&
                    (r['debit_in_account_currency'] as num? ?? 0) > 0)
                  'Dr: ${r['debit_in_account_currency']}',
                if (r['credit_in_account_currency'] != null &&
                    (r['credit_in_account_currency'] as num? ?? 0) > 0)
                  'Cr: ${r['credit_in_account_currency']}',
                if (r['debit'] != null && (r['debit'] as num? ?? 0) > 0)
                  'Dr: ${r['debit']}',
                if (r['credit'] != null && (r['credit'] as num? ?? 0) > 0)
                  'Cr: ${r['credit']}',
              ].join(' • ');

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(
                    primary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: secondary.isNotEmpty
                      ? Text(secondary, style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: isEditable
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Edit Row',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () =>
                                  _editChildRowDialog(fieldname, idx, r, rows),
                            ),
                            IconButton(
                              tooltip: 'Delete Row',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                final List<Map<String, dynamic>> updatedTable =
                                    rows
                                        .map(
                                          (dynamic e) =>
                                              Map<String, dynamic>.from(
                                                e as Map<dynamic, dynamic>,
                                              ),
                                        )
                                        .toList();
                                if (idx >= 0 && idx < updatedTable.length) {
                                  updatedTable.removeAt(idx);
                                  setState(() {
                                    _doc[fieldname] = updatedTable;
                                    _changedValues[fieldname] = updatedTable;
                                  });
                                }
                              },
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _editChildRowDialog(
    String tableField,
    int rowIndex,
    Map<String, dynamic> rowData,
    List<dynamic> allRows, {
    bool isNewRow = false,
  }) async {
    final List<String> editableRowKeys = rowData.keys
        .where(
          (String k) =>
              !ErpDocSheet._systemReadOnlyKeys.contains(k) &&
              k != 'parent' &&
              k != 'parentfield' &&
              k != 'parenttype' &&
              rowData[k] is! Map &&
              rowData[k] is! List,
        )
        .toList();

    final Map<String, TextEditingController> rowCtrls =
        <String, TextEditingController>{
          for (final String k in editableRowKeys)
            k: TextEditingController(text: (rowData[k] ?? '').toString()),
        };

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) => AlertDialog(
        title: Text(
          isNewRow ? 'Add Row (#${rowIndex + 1})' : 'Edit Row #${rowIndex + 1}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: editableRowKeys.map((String k) {
                final String? linkDt = ErpDocSheet._childRowKeyLinkDocType(k);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: rowCtrls[k],
                    decoration: InputDecoration(
                      labelText: linkDt != null
                          ? '${ErpDocSheet._humanizeFieldName(k)} ($linkDt)'
                          : ErpDocSheet._humanizeFieldName(k),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: linkDt != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.manage_search_rounded,
                                size: 18,
                              ),
                              onPressed: () async {
                                final String? picked =
                                    await ErpDocSheet.pickLinkValue(
                                      context,
                                      linkDocType: linkDt,
                                      currentValue: rowCtrls[k]!.text.trim(),
                                    );
                                if (picked != null) {
                                  rowCtrls[k]!.text = picked;
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(isNewRow ? 'Add Row' : 'Apply'),
          ),
        ],
      ),
    );

    if (updated == true) {
      final Map<String, dynamic> newRow = Map<String, dynamic>.from(rowData);
      for (final String k in editableRowKeys) {
        final String txt = rowCtrls[k]!.text.trim();
        if (rowData[k] is int) {
          newRow[k] = int.tryParse(txt) ?? rowData[k];
        } else if (rowData[k] is num) {
          newRow[k] = double.tryParse(txt) ?? rowData[k];
        } else {
          newRow[k] = txt;
        }
      }
      final List<Map<String, dynamic>> updatedTable = allRows
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
      if (isNewRow || rowIndex >= updatedTable.length) {
        updatedTable.add(newRow);
      } else {
        updatedTable[rowIndex] = newRow;
      }
      setState(() {
        _doc[tableField] = updatedTable;
        _changedValues[tableField] = updatedTable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> fields = _buildEffectiveFields();
    final String statusText =
        (_doc['status'] ??
                (_doc['docstatus'] == 1
                    ? 'Submitted'
                    : _doc['docstatus'] == 2
                    ? 'Cancelled'
                    : 'Draft'))
            .toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _resolveTitle(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              '${widget.doctype} • ${widget.docname}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _canWrite
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _canWrite ? 'Write Access' : 'Read Only',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _canWrite
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                            if (_canCreate)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Create',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            if (_canSubmit)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Submit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_canCreate)
                    IconButton(
                      tooltip: 'New ${widget.doctype}',
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.teal,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ErpDocSheet.showCreate(
                          context,
                          doctype: widget.doctype,
                          onCreated: widget.onSaved,
                        );
                      },
                    ),
                  IconButton(
                    tooltip: 'Download Official PDF',
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => ErpApiClient.instance.downloadAndOpenPdf(
                      doctype: widget.doctype,
                      docname: widget.docname,
                    ),
                  ),
                  if (_canDelete)
                    IconButton(
                      tooltip: 'Delete Record',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: _saving ? null : _deleteDocument,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showAllFields = !_showAllFields);
                    },
                    icon: Icon(
                      _showAllFields
                          ? Icons.visibility_off_outlined
                          : Icons.tune_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _showAllFields
                          ? 'Show Standard Fields'
                          : 'Show All ERP Fields (${_doc.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_canSubmit)
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : () => _changeDocStatus(1),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Submit'),
                    )
                  else if (_canCancel)
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _changeDocStatus(2),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Doc'),
                    ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  itemCount: fields.length,
                  itemBuilder: (BuildContext context, int i) {
                    return _buildFieldInput(fields[i]);
                  },
                ),
              ),
              if (_canWrite)
                SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveChanges,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text('Save ${widget.doctype} Changes'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErpDocCreateModal extends StatefulWidget {
  const _ErpDocCreateModal({
    required this.doctype,
    required this.metaFields,
    required this.permissions,
    required this.initialValues,
    required this.onCreated,
  });

  final String doctype;
  final List<Map<String, dynamic>> metaFields;
  final Map<String, dynamic> permissions;
  final Map<String, dynamic> initialValues;
  final ValueChanged<Map<String, dynamic>> onCreated;

  @override
  State<_ErpDocCreateModal> createState() => _ErpDocCreateModalState();
}

class _ErpDocCreateModalState extends State<_ErpDocCreateModal> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, dynamic> _values = <String, dynamic>{};
  bool _saving = false;
  bool _showOptional = false;

  bool get _canCreate =>
      ((widget.permissions['create'] as num?)?.toInt() ?? 1) == 1;

  @override
  void initState() {
    super.initState();
    final UserSession? s = ErpApiClient.instance.session;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _values.addAll(widget.initialValues);

    for (final Map<String, dynamic> f in widget.metaFields) {
      final String fn = (f['fieldname'] ?? '').toString();
      final String ft = (f['fieldtype'] ?? '').toString();
      if (fn.isEmpty) {
        continue;
      }
      if (ft == 'Table') {
        if (_values[fn] is! List) {
          _values[fn] = <Map<String, dynamic>>[];
        }
        continue;
      }
      dynamic def = _values[fn] ?? f['default'];
      if (def == null || def.toString().isEmpty) {
        if (fn == 'company' && s != null) {
          def = s.company;
        } else if (fn == 'cost_center' && s != null) {
          def = s.costCenter.isNotEmpty
              ? s.costCenter
              : (s.costCenters.isNotEmpty
                    ? s.costCenters.first
                    : '101 - Head Office CC - DIBL');
        } else if (fn == 'department' && s != null) {
          def = s.department.isNotEmpty
              ? s.department
              : (s.departments.isNotEmpty
                    ? s.departments.first
                    : 'HR & Admin Department- DIBL');
        } else if (fn == 'project_template') {
          def = '99-Not Applicable';
        } else if (fn == 'posting_date' ||
            fn == 'transaction_date' ||
            fn == 'expected_start_date') {
          def = today;
        } else if (fn == 'exp_start_date' || fn == 'exp_end_date') {
          def = '$today 09:00:00';
        }
      }
      if (def != null) {
        _values[fn] = def;
      }
      _controllers[fn] = TextEditingController(text: (def ?? '').toString());
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _visibleFields() {
    final List<Map<String, dynamic>> editable = widget.metaFields.where((
      Map<String, dynamic> f,
    ) {
      final String fn = (f['fieldname'] ?? '').toString();
      final int ro = (f['read_only'] as num?)?.toInt() ?? 0;
      return fn.isNotEmpty &&
          fn != 'naming_series' &&
          fn != 'amended_from' &&
          ro == 0;
    }).toList();

    if (editable.isEmpty) {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'fieldname': widget.doctype == 'Customer'
              ? 'customer_name'
              : widget.doctype == 'Supplier'
              ? 'supplier_name'
              : widget.doctype == 'Item'
              ? 'item_code'
              : widget.doctype == 'Project'
              ? 'project_name'
              : widget.doctype == 'Task'
              ? 'subject'
              : 'title',
          'label': '${widget.doctype} Name / Title',
          'fieldtype': 'Data',
          'reqd': 1,
        },
      ];
    }

    if (_showOptional) {
      return editable;
    }

    final List<Map<String, dynamic>> primary = editable.where((
      Map<String, dynamic> f,
    ) {
      final String ft = (f['fieldtype'] ?? '').toString();
      final int reqd = (f['reqd'] as num?)?.toInt() ?? 0;
      final int inStandardFilter =
          (f['in_standard_filter'] as num?)?.toInt() ?? 0;
      final int inListView = (f['in_list_view'] as num?)?.toInt() ?? 0;
      return reqd == 1 ||
          inStandardFilter == 1 ||
          inListView == 1 ||
          ft == 'Table';
    }).toList();

    return primary.isNotEmpty ? primary : editable.take(12).toList();
  }

  Future<void> _editCreateChildRowDialog(
    String tableField,
    int rowIndex,
    Map<String, dynamic> rowData,
    List<dynamic> allRows, {
    bool isNewRow = false,
  }) async {
    final List<String> editableRowKeys = rowData.keys
        .where(
          (String k) =>
              !ErpDocSheet._systemReadOnlyKeys.contains(k) &&
              k != 'parent' &&
              k != 'parentfield' &&
              k != 'parenttype' &&
              rowData[k] is! Map &&
              rowData[k] is! List,
        )
        .toList();

    final Map<String, TextEditingController> rowCtrls =
        <String, TextEditingController>{
          for (final String k in editableRowKeys)
            k: TextEditingController(text: (rowData[k] ?? '').toString()),
        };

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) => AlertDialog(
        title: Text(
          isNewRow ? 'Add Row (#${rowIndex + 1})' : 'Edit Row #${rowIndex + 1}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: editableRowKeys.map((String k) {
                final String? linkDt = ErpDocSheet._childRowKeyLinkDocType(k);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: rowCtrls[k],
                    decoration: InputDecoration(
                      labelText: linkDt != null
                          ? '${ErpDocSheet._humanizeFieldName(k)} ($linkDt)'
                          : ErpDocSheet._humanizeFieldName(k),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: linkDt != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.manage_search_rounded,
                                size: 18,
                              ),
                              onPressed: () async {
                                final String? picked =
                                    await ErpDocSheet.pickLinkValue(
                                      context,
                                      linkDocType: linkDt,
                                      currentValue: rowCtrls[k]!.text.trim(),
                                    );
                                if (picked != null) {
                                  rowCtrls[k]!.text = picked;
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(isNewRow ? 'Add Row' : 'Apply'),
          ),
        ],
      ),
    );

    if (updated == true) {
      final Map<String, dynamic> newRow = Map<String, dynamic>.from(rowData);
      for (final String k in editableRowKeys) {
        final String txt = rowCtrls[k]!.text.trim();
        if (rowData[k] is int) {
          newRow[k] = int.tryParse(txt) ?? rowData[k];
        } else if (rowData[k] is num) {
          newRow[k] = double.tryParse(txt) ?? rowData[k];
        } else {
          newRow[k] = txt;
        }
      }
      final List<Map<String, dynamic>> updatedTable = allRows
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
      if (isNewRow || rowIndex >= updatedTable.length) {
        updatedTable.add(newRow);
      } else {
        updatedTable[rowIndex] = newRow;
      }
      setState(() {
        _values[tableField] = updatedTable;
      });
    }
  }

  Widget _buildCreateChildTableWidget(String fieldname, String label) {
    final List<dynamic> rows =
        (_values[fieldname] as List<dynamic>?) ?? <dynamic>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '$label (${rows.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    final Map<String, dynamic> template =
                        ErpDocSheet._defaultChildRowTemplate(fieldname);
                    _editCreateChildRowDialog(
                      fieldname,
                      rows.length,
                      template,
                      rows,
                      isNewRow: true,
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text(
                    '+ Add Row',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No rows added yet. Tap "+ Add Row" to add items.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ...rows.asMap().entries.map((MapEntry<int, dynamic> entry) {
              final int idx = entry.key;
              final Map<String, dynamic> r = Map<String, dynamic>.from(
                entry.value as Map<dynamic, dynamic>,
              );
              final String primary =
                  (r['item_name'] ??
                          r['item_code'] ??
                          r['account'] ??
                          r['expense_type'] ??
                          r['salary_component'] ??
                          r['activity_type'] ??
                          r['asset'] ??
                          r['description'] ??
                          'Row ${idx + 1}')
                      .toString();
              final String secondary = <String>[
                if (r['qty'] != null) 'Qty: ${r['qty']}',
                if (r['rate'] != null) 'Rate: ${r['rate']}',
                if (r['amount'] != null) 'Amt: ${r['amount']}',
                if (r['hours'] != null) 'Hrs: ${r['hours']}',
              ].join(' • ');

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(
                    primary.isEmpty ? 'Row ${idx + 1}' : primary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: secondary.isNotEmpty
                      ? Text(secondary, style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () =>
                            _editCreateChildRowDialog(fieldname, idx, r, rows),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          final List<Map<String, dynamic>> updated = rows
                              .map(
                                (dynamic e) => Map<String, dynamic>.from(
                                  e as Map<dynamic, dynamic>,
                                ),
                              )
                              .toList();
                          if (idx >= 0 && idx < updated.length) {
                            updated.removeAt(idx);
                            setState(() {
                              _values[fieldname] = updated;
                            });
                          }
                        },
                      ),
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

  Future<void> _submitCreate() async {
    setState(() => _saving = true);
    try {
      final Map<String, dynamic> payload = <String, dynamic>{};
      for (final MapEntry<String, TextEditingController> e
          in _controllers.entries) {
        final String v = e.value.text.trim();
        if (v.isNotEmpty) {
          payload[e.key] = v;
        }
      }
      for (final MapEntry<String, dynamic> e in _values.entries) {
        if (e.value is List) {
          final List<dynamic> listVal = e.value as List<dynamic>;
          if (listVal.isNotEmpty) {
            payload[e.key] = listVal;
          }
        } else if (e.value != null && e.value.toString().trim().isNotEmpty) {
          payload.putIfAbsent(e.key, () => e.value);
        }
      }

      final Map<String, dynamic> created = await ErpApiClient.instance
          .createDoc(widget.doctype, payload);
      widget.onCreated(created);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              '${widget.doctype} ${created['name'] ?? ''} created!',
            ),
          ),
        );
      }
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> fields = _visibleFields();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'New ${widget.doctype}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _canCreate
                                    ? Colors.green.withValues(alpha: 0.14)
                                    : Colors.orange.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _canCreate
                                    ? 'ERP Create Access'
                                    : 'Restricted Create Access',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _canCreate
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showOptional = !_showOptional),
                    icon: Icon(
                      _showOptional
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showOptional ? 'Key Fields Only' : 'All ERP Fields',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  itemCount: fields.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> f = fields[i];
                    final String fn = (f['fieldname'] ?? '').toString();
                    final String label =
                        (f['label'] ?? ErpDocSheet._humanizeFieldName(fn))
                            .toString();
                    final String ft = (f['fieldtype'] ?? 'Data').toString();
                    final int reqd = (f['reqd'] as num?)?.toInt() ?? 0;
                    final String labelWithReq = reqd == 1 ? '$label *' : label;

                    if (ft == 'Table') {
                      return _buildCreateChildTableWidget(fn, labelWithReq);
                    }

                    if (ft == 'Check') {
                      final bool checked =
                          _values[fn] == 1 ||
                          _values[fn] == true ||
                          _values[fn] == '1';
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          labelWithReq,
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: checked,
                        onChanged: (bool v) {
                          setState(() => _values[fn] = v ? 1 : 0);
                        },
                      );
                    }

                    final TextEditingController ctrl = _controllers.putIfAbsent(
                      fn,
                      () => TextEditingController(
                        text: (_values[fn] ?? '').toString(),
                      ),
                    );

                    if (ft == 'Select') {
                      final List<String> opts = (f['options'] ?? '')
                          .toString()
                          .split('\n')
                          .map((String s) => s.trim())
                          .where((String s) => s.isNotEmpty)
                          .toList();
                      if (opts.isNotEmpty) {
                        final String cur = ctrl.text.trim();
                        if (cur.isNotEmpty && !opts.contains(cur)) {
                          opts.insert(0, cur);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: opts.contains(cur) ? cur : opts.first,
                            decoration: InputDecoration(
                              labelText: labelWithReq,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: opts
                                .map(
                                  (String o) => DropdownMenuItem<String>(
                                    value: o,
                                    child: Text(
                                      o,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v != null) {
                                setState(() {
                                  ctrl.text = v;
                                  _values[fn] = v;
                                });
                              }
                            },
                          ),
                        );
                      }
                    }

                    if (ft == 'Link') {
                      final String targetDt = (f['options'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: ctrl,
                          onChanged: (String v) => _values[fn] = v.trim(),
                          decoration: InputDecoration(
                            labelText:
                                '$labelWithReq ${targetDt.isNotEmpty ? '($targetDt)' : ''}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: targetDt.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.manage_search_rounded,
                                    ),
                                    onPressed: () async {
                                      final String? picked =
                                          await ErpDocSheet.pickLinkValue(
                                            context,
                                            linkDocType: targetDt,
                                            currentValue: ctrl.text.trim(),
                                          );
                                      if (picked != null) {
                                        setState(() {
                                          ctrl.text = picked;
                                          _values[fn] = picked;
                                        });
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                      );
                    }

                    if (ft == 'Date' || ft == 'Datetime') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: ctrl,
                          onChanged: (String v) => _values[fn] = v.trim(),
                          decoration: InputDecoration(
                            labelText: labelWithReq,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                              ),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  final String formatted = ft == 'Datetime'
                                      ? '${DateFormat('yyyy-MM-dd').format(picked)} 09:00:00'
                                      : DateFormat('yyyy-MM-dd').format(picked);
                                  setState(() {
                                    ctrl.text = formatted;
                                    _values[fn] = formatted;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }

                    final bool isNumeric =
                        ft == 'Currency' ||
                        ft == 'Float' ||
                        ft == 'Int' ||
                        ft == 'Percent';
                    final bool isMultiline =
                        ft == 'Text' ||
                        ft == 'Small Text' ||
                        ft == 'Text Editor' ||
                        ft == 'Long Text';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: ctrl,
                        maxLines: isMultiline ? 3 : 1,
                        keyboardType: isNumeric
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        onChanged: (String v) => _values[fn] = v.trim(),
                        decoration: InputDecoration(
                          labelText: labelWithReq,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: (_saving || !_canCreate) ? null : _submitCreate,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    _canCreate
                        ? 'Create ${widget.doctype}'
                        : 'No Create Permission for ${widget.doctype}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
