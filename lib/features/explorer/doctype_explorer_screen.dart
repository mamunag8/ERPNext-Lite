import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class DocTypeExplorerScreen extends StatefulWidget {
  const DocTypeExplorerScreen({super.key, this.initialDocType = 'Customer'});

  final String initialDocType;

  @override
  State<DocTypeExplorerScreen> createState() => _DocTypeExplorerScreenState();
}

class _DocTypeExplorerScreenState extends State<DocTypeExplorerScreen> {
  static const List<String> _popularDocTypes = <String>[
    'Customer',
    'Item',
    'Item Price',
    'Employee',
    'Additional Salary',
    'Payroll Entry',
    'Salary Structure Assignment',
    'Leave Policy Assignment',
    'Stock Reconciliation',
    'Warehouse',
    'Cost Center',
    'Branch',
    'Contact',
    'Address',
    'Product Bundle',
    'Sales Invoice',
    'Sales Order',
    'Quotation',
    'Payment Entry',
    'Journal Entry',
    'Delivery Note',
    'Purchase Order',
    'Purchase Receipt',
    'Purchase Invoice',
    'Supplier',
    'Asset',
    'Asset Movement',
    'Project',
    'Task',
    'Material Request',
    'Stock Entry',
    'Employee Advance',
    'Expense Claim',
    'Leave Application',
    'Attendance',
    'Employee Checkin',
    'CRM Lead',
    'CRM Deal',
    'CRM Task',
    'ToDo',
  ];

  late String _selectedDocType;
  late TextEditingController _customDocTypeCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _selectedDocType = widget.initialDocType;
    _customDocTypeCtrl = TextEditingController(text: _selectedDocType);
    _loadRecords();
  }

  @override
  void dispose() {
    _customDocTypeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final String dt = _customDocTypeCtrl.text.trim();
    if (dt.isEmpty) {
      return;
    }
    setState(() {
      _selectedDocType = dt;
      _loading = true;
    });

    try {
      final List<List<dynamic>>? filters = _searchCtrl.text.trim().isNotEmpty
          ? <List<dynamic>>[
              <dynamic>['name', 'like', '%${_searchCtrl.text.trim()}%'],
            ]
          : null;

      final List<Map<String, dynamic>> rows = await ErpApiClient.instance
          .getList(
            dt,
            fields: const <String>['name', 'modified', 'owner', 'docstatus'],
            listFilters: filters,
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() => _records = rows);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _inspectRecord(String docName) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Map<String, dynamic> doc = await ErpApiClient.instance.getDoc(
        _selectedDocType,
        docName,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext ctx) {
          final List<MapEntry<String, dynamic>> entries = doc.entries
              .where(
                (MapEntry<String, dynamic> e) =>
                    e.value != null &&
                    e.value.toString().isNotEmpty &&
                    !e.key.startsWith('_'),
              )
              .toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            maxChildSize: 0.94,
            minChildSize: 0.45,
            builder: (BuildContext context, ScrollController scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
                                docName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _selectedDocType,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              ErpApiClient.instance.downloadAndOpenPdf(
                                doctype: _selectedDocType,
                                docname: docName,
                              ),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                          ),
                          label: const Text('PDF'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int i) {
                          final MapEntry<String, dynamic> entry = entries[i];
                          final String valStr =
                              entry.value is List || entry.value is Map
                              ? const JsonEncoder.withIndent('  ')
                                    .convert(entry.value)
                              : entry.value.toString();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  valStr,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
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
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _showCreateGenericDocSheet() async {
    final TextEditingController field1KeyCtrl = TextEditingController(
      text: _selectedDocType == 'Customer'
          ? 'customer_name'
          : _selectedDocType == 'Item'
          ? 'item_code'
          : 'title',
    );
    final TextEditingController field1ValCtrl = TextEditingController();
    final TextEditingController field2KeyCtrl = TextEditingController(
      text: _selectedDocType == 'Item' ? 'item_group' : 'description',
    );
    final TextEditingController field2ValCtrl = TextEditingController(
      text: _selectedDocType == 'Item' ? 'Products' : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'New $_selectedDocType Document',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: field1KeyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Field 1 Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: field1ValCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Value *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: field2KeyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Field 2 Name (Opt)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: field2ValCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Value',
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
                  label: Text('Create $_selectedDocType'),
                  onPressed: () async {
                    if (field1KeyCtrl.text.trim().isEmpty ||
                        field1ValCtrl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      final Map<String, dynamic> payload = <String, dynamic>{
                        field1KeyCtrl.text.trim(): field1ValCtrl.text.trim(),
                        if (field2KeyCtrl.text.trim().isNotEmpty &&
                            field2ValCtrl.text.trim().isNotEmpty)
                          field2KeyCtrl.text.trim(): field2ValCtrl.text.trim(),
                      };
                      await ErpApiClient.instance.createDoc(
                        _selectedDocType,
                        payload,
                      );
                      await _loadRecords();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Universal DocType Explorer')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGenericDocSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text('New $_selectedDocType'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _customDocTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'DocType Name (Any ERPNext DocType)',
                          prefixIcon: Icon(Icons.table_chart_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _loadRecords(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loadRecords,
                      child: const Text('Load'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularDocTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final String dt = _popularDocTypes[i];
                      final bool selected = dt == _selectedDocType;
                      return ChoiceChip(
                        label: Text(dt, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          _customDocTypeCtrl.text = dt;
                          _loadRecords();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Filter $_selectedDocType by ID / Name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loadRecords,
                    ),
                  ),
                  onSubmitted: (_) => _loadRecords(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    child: _records.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: <Widget>[
                              Center(
                                child: Text(
                                  'No records found for "$_selectedDocType".',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _records.length,
                            itemBuilder: (BuildContext context, int i) {
                              final Map<String, dynamic> row = _records[i];
                              final String docName = (row['name'] ?? '')
                                  .toString();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.description_outlined),
                                  ),
                                  title: Text(
                                    docName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Modified: ${row['modified'] ?? 'N/A'} • Owner: ${row['owner'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => _inspectRecord(docName),
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
