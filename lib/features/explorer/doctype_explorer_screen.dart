import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';
import '../../core/widgets/erp_search_bar.dart';

class DocTypeExplorerScreen extends StatefulWidget {
  const DocTypeExplorerScreen({super.key, this.initialDocType = 'Customer'});

  final String initialDocType;

  @override
  State<DocTypeExplorerScreen> createState() => _DocTypeExplorerScreenState();
}

class _DocTypeExplorerScreenState extends State<DocTypeExplorerScreen> {
  static const List<String> _popularDocTypes = <String>[
    'Customer',
    'Supplier',
    'Item',
    'Item Price',
    'Project',
    'Task',
    'Timesheet',
    'Sales Invoice',
    'Sales Order',
    'Delivery Note',
    'Quotation',
    'Purchase Order',
    'Purchase Receipt',
    'Purchase Invoice',
    'Material Request',
    'Stock Entry',
    'Payment Entry',
    'Journal Entry',
    'Employee',
    'Attendance',
    'Employee Checkin',
    'Shift Request',
    'Leave Application',
    'Leave Allocation',
    'Leave Policy Assignment',
    'Expense Claim',
    'Employee Advance',
    'Salary Slip',
    'Payroll Entry',
    'Salary Structure',
    'Salary Structure Assignment',
    'Additional Salary',
    'Asset',
    'Asset Movement',
    'CRM Lead',
    'Lead',
    'CRM Deal',
    'Opportunity',
    'CRM Task',
    'ToDo',
    'FCRM Note',
    'Note',
    'Stock Reconciliation',
    'Warehouse',
    'Cost Center',
    'Branch',
    'Contact',
    'Address',
    'Product Bundle',
  ];

  late String _selectedDocType;
  late TextEditingController _customDocTypeCtrl;
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _loading = false;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];
  Map<String, int> _permissions = <String, int>{
    'read': 1,
    'write': 1,
    'create': 1,
    'submit': 1,
    'cancel': 1,
    'delete': 1,
  };

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
      final List<dynamic> res = await Future.wait<dynamic>(<Future<dynamic>>[
        ErpApiClient.instance.getList(
          dt,
          fields: const <String>[
            'name',
            'modified',
            'owner',
            'docstatus',
            'status',
          ],
          limitPageLength: 80,
        ),
        ErpApiClient.instance.getDocTypePermissions(dt),
      ]);
      if (mounted) {
        setState(() {
          _records = res[0] as List<Map<String, dynamic>>;
          _permissions = res[1] as Map<String, int>;
        });
      }
    } catch (e) {
      try {
        final List<Map<String, dynamic>> rows = await ErpApiClient.instance
            .getList(
              dt,
              fields: const <String>['name', 'modified', 'owner', 'docstatus'],
              limitPageLength: 80,
            );
        final Map<String, int> perms = await ErpApiClient.instance
            .getDocTypePermissions(dt);
        if (mounted) {
          setState(() {
            _records = rows;
            _permissions = perms;
          });
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErpApiClient.formatErrorMessage(e))),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _serverSearchRecords() async {
    final String q = _searchQuery.trim();
    if (q.isEmpty) {
      await _loadRecords();
      return;
    }
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> rows = await ErpApiClient.instance
          .searchDocTypeRecords(_selectedDocType, q);
      if (mounted && rows.isNotEmpty) {
        setState(() => _records = rows);
      }
    } catch (_) {
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
    final String dtFilter = _customDocTypeCtrl.text.trim().toLowerCase();
    final List<String> matchingDocTypes =
        dtFilter.isEmpty ||
            _popularDocTypes.any((String d) => d.toLowerCase() == dtFilter)
        ? _popularDocTypes
        : _popularDocTypes
              .where((String d) => d.toLowerCase().contains(dtFilter))
              .toList();

    final List<Map<String, dynamic>> filteredRecords = _records.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _statusFilter) &&
          ErpSearchBar.matchesQuery(row, _searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal DocType Explorer'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh $_selectedDocType',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRecords,
          ),
        ],
      ),
      floatingActionButton: (_permissions['create'] ?? 1) == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateGenericDocSheet,
              icon: const Icon(Icons.add_rounded),
              label: Text('New $_selectedDocType'),
            )
          : null,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _customDocTypeCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Search or Type Any ERPNext DocType Name',
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
                    itemCount: matchingDocTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final String dt = matchingDocTypes[i];
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
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Your ERP Access ($_selectedDocType): ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final String permKey in <String>[
                        'read',
                        'write',
                        'create',
                        'submit',
                        'cancel',
                        'delete',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (_permissions[permKey] ?? 0) == 1
                                  ? Colors.green.withValues(alpha: 0.14)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(_permissions[permKey] ?? 0) == 1 ? '✓' : '✗'} ${permKey.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (_permissions[permKey] ?? 0) == 1
                                    ? Colors.green.shade800
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ErpSearchBar(
            hintText:
                'Search $_selectedDocType records (ID, owner, modified date)...',
            query: _searchQuery,
            onQueryChanged: (String v) => setState(() => _searchQuery = v),
            onServerSearch: _serverSearchRecords,
            filters: const <String>['All', 'Submitted', 'Draft', 'Cancelled'],
            selectedFilter: _statusFilter,
            onFilterChanged: (String f) => setState(() => _statusFilter = f),
            resultCount: filteredRecords.length,
            totalCount: _records.length,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadRecords,
                    child: filteredRecords.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: <Widget>[
                              Center(
                                child: Text(
                                  'No matching records found for "$_selectedDocType".',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: filteredRecords.length,
                            itemBuilder: (BuildContext context, int i) {
                              final Map<String, dynamic> row =
                                  filteredRecords[i];
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
