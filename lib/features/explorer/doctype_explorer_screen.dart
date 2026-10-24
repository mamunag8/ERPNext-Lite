import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';

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
    await ErpDocSheet.showViewAndEdit(
      context,
      doctype: _selectedDocType,
      docname: docName,
      onSaved: _loadRecords,
    );
  }

  Future<void> _showCreateGenericDocSheet() async {
    await ErpDocSheet.showCreate(
      context,
      doctype: _selectedDocType,
      onCreated: _loadRecords,
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
