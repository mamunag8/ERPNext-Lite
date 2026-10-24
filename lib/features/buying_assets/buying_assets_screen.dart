import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';
import '../../core/widgets/erp_search_bar.dart';

class BuyingAndAssetsScreen extends StatefulWidget {
  const BuyingAndAssetsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<BuyingAndAssetsScreen> createState() => _BuyingAndAssetsScreenState();
}

class _BuyingAndAssetsScreenState extends State<BuyingAndAssetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _purchaseOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _purchaseReceipts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _purchaseInvoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _suppliers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _assets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _assetMovements = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  String _poQuery = '';
  String _poStatusFilter = 'All';
  String _prQuery = '';
  String _prStatusFilter = 'All';
  String _pinvQuery = '';
  String _pinvStatusFilter = 'All';
  String _supplierQuery = '';
  String _supplierFilter = 'All';
  String _assetQuery = '';
  String _assetStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
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
      final List<Map<String, dynamic>> pos = await ErpApiClient.instance
          .getList(
            'Purchase Order',
            fields: <String>[
              'name',
              'supplier',
              'supplier_name',
              'transaction_date',
              'grand_total',
              'status',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _purchaseOrders = pos);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> prs = await ErpApiClient.instance
          .getList(
            'Purchase Receipt',
            fields: <String>[
              'name',
              'supplier',
              'supplier_name',
              'posting_date',
              'grand_total',
              'status',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _purchaseReceipts = prs);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> pinvs = await ErpApiClient.instance
          .getList(
            'Purchase Invoice',
            fields: <String>[
              'name',
              'supplier',
              'supplier_name',
              'posting_date',
              'grand_total',
              'outstanding_amount',
              'status',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _purchaseInvoices = pinvs);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> sups = await ErpApiClient.instance
          .getList(
            'Supplier',
            fields: <String>[
              'name',
              'supplier_name',
              'supplier_group',
              'country',
            ],
            limitPageLength: 60,
          );
      final List<Map<String, dynamic>> itemDocs = await ErpApiClient.instance
          .getList(
            'Item',
            fields: <String>['name', 'item_code', 'item_name', 'standard_rate'],
            filters: <String, dynamic>{'disabled': 0},
            limitPageLength: 60,
          );
      if (mounted) {
        setState(() {
          _suppliers = sups;
          _items = itemDocs;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> assetDocs = await ErpApiClient.instance
          .getList(
            'Asset',
            fields: <String>[
              'name',
              'asset_name',
              'item_code',
              'asset_category',
              'location',
              'status',
              'gross_purchase_amount',
            ],
            limitPageLength: 60,
          );
      final List<Map<String, dynamic>> moveDocs = await ErpApiClient.instance
          .getList(
            'Asset Movement',
            fields: <String>[
              'name',
              'purpose',
              'transaction_date',
              'company',
              'docstatus',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() {
          _assets = assetDocs;
          _assetMovements = moveDocs;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buying, Procurement & Assets'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.shopping_cart_rounded), text: 'Purchase Ord.'),
            Tab(icon: Icon(Icons.move_to_inbox_rounded), text: 'Receipts'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Pur. Invoices'),
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Suppliers'),
            Tab(
              icon: Icon(Icons.precision_manufacturing_rounded),
              text: 'Assets & Move',
            ),
          ],
        ),
      ),
      body: _loading && _purchaseOrders.isEmpty && _assets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildPurchaseOrdersTab(sym),
                _buildPurchaseReceiptsTab(sym),
                _buildPurchaseInvoicesTab(sym),
                _buildSuppliersTab(),
                _buildAssetsTab(sym),
              ],
            ),
    );
  }

  Widget _buildPurchaseOrdersTab(String sym) {
    final List<Map<String, dynamic>> filteredPos = _purchaseOrders.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _poStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _poQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePurchaseVoucherSheet('Purchase Order'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('New Purchase Order'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Purchase Orders (ID, supplier, date, status)...',
            query: _poQuery,
            onQueryChanged: (String v) => setState(() => _poQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Purchase Order',
              initialQuery: _poQuery,
              onSaved: _loadData,
            ),
            filters: const <String>[
              'All',
              'To Receive and Bill',
              'To Bill',
              'Completed',
              'Draft',
              'Cancelled',
            ],
            selectedFilter: _poStatusFilter,
            onFilterChanged: (String f) => setState(() => _poStatusFilter = f),
            resultCount: filteredPos.length,
            totalCount: _purchaseOrders.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: filteredPos.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> po = filteredPos[i];
                  final String docName = (po['name'] ?? '').toString();
                  final double gt =
                      (po['grand_total'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Purchase Order',
                        docname: docName,
                        onSaved: _loadData,
                      ),
                      title: Text(
                        '${po['supplier_name'] ?? po['supplier'] ?? docName} • $sym${NumberFormat('#,##0').format(gt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$docName • ${po['transaction_date'] ?? ''} • ${po['status'] ?? ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Download Purchase Order PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            ErpApiClient.instance.downloadAndOpenPdf(
                              doctype: 'Purchase Order',
                              docname: docName,
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

  Widget _buildPurchaseReceiptsTab(String sym) {
    final List<Map<String, dynamic>> filteredPrs = _purchaseReceipts.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _prStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _prQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePurchaseVoucherSheet('Purchase Receipt'),
        icon: const Icon(Icons.add_box_rounded),
        label: const Text('New Receipt'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search Purchase Receipts (ID, supplier, date, status)...',
            query: _prQuery,
            onQueryChanged: (String v) => setState(() => _prQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Purchase Receipt',
              initialQuery: _prQuery,
              onSaved: _loadData,
            ),
            filters: const <String>[
              'All',
              'To Bill',
              'Completed',
              'Draft',
              'Cancelled',
            ],
            selectedFilter: _prStatusFilter,
            onFilterChanged: (String f) => setState(() => _prStatusFilter = f),
            resultCount: filteredPrs.length,
            totalCount: _purchaseReceipts.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: filteredPrs.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> pr = filteredPrs[i];
                  final String docName = (pr['name'] ?? '').toString();
                  final double gt =
                      (pr['grand_total'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Purchase Receipt',
                        docname: docName,
                        onSaved: _loadData,
                      ),
                      title: Text(
                        '${pr['supplier_name'] ?? pr['supplier'] ?? docName} • $sym${NumberFormat('#,##0').format(gt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$docName • ${pr['posting_date'] ?? ''} • ${pr['status'] ?? ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Download Purchase Receipt PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            ErpApiClient.instance.downloadAndOpenPdf(
                              doctype: 'Purchase Receipt',
                              docname: docName,
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

  Widget _buildPurchaseInvoicesTab(String sym) {
    final List<Map<String, dynamic>> filteredPinvs = _purchaseInvoices.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _pinvStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _pinvQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePurchaseVoucherSheet('Purchase Invoice'),
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('New Pur. Invoice'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search Purchase Invoices (ID, supplier, date, status)...',
            query: _pinvQuery,
            onQueryChanged: (String v) => setState(() => _pinvQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Purchase Invoice',
              initialQuery: _pinvQuery,
              onSaved: _loadData,
            ),
            filters: const <String>[
              'All',
              'Unpaid',
              'Overdue',
              'Paid',
              'Draft',
              'Cancelled',
            ],
            selectedFilter: _pinvStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _pinvStatusFilter = f),
            resultCount: filteredPinvs.length,
            totalCount: _purchaseInvoices.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: filteredPinvs.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> pinv = filteredPinvs[i];
                  final String docName = (pinv['name'] ?? '').toString();
                  final double gt =
                      (pinv['grand_total'] as num?)?.toDouble() ?? 0;
                  final double out =
                      (pinv['outstanding_amount'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Purchase Invoice',
                        docname: docName,
                        onSaved: _loadData,
                      ),
                      title: Text(
                        '${pinv['supplier_name'] ?? pinv['supplier'] ?? docName} • $sym${NumberFormat('#,##0').format(gt)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$docName • ${pinv['posting_date'] ?? ''} • Due: $sym${NumberFormat('#,##0').format(out)} (${pinv['status'] ?? ''})',
                      ),
                      trailing: IconButton(
                        tooltip: 'Download Purchase Invoice PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            ErpApiClient.instance.downloadAndOpenPdf(
                              doctype: 'Purchase Invoice',
                              docname: docName,
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

  Widget _buildSuppliersTab() {
    final List<Map<String, dynamic>> filteredSuppliers = _suppliers.where((
      Map<String, dynamic> row,
    ) {
      if (_supplierFilter != 'All') {
        final String grp = (row['supplier_group'] ?? '').toString();
        final String country = (row['country'] ?? '').toString();
        if (!grp.toLowerCase().contains(_supplierFilter.toLowerCase()) &&
            !country.toLowerCase().contains(_supplierFilter.toLowerCase())) {
          return false;
        }
      }
      return ErpSearchBar.matchesQuery(row, _supplierQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSupplierSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Supplier'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Suppliers (name, ID, group, country)...',
            query: _supplierQuery,
            onQueryChanged: (String v) => setState(() => _supplierQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Supplier',
              initialQuery: _supplierQuery,
              onSaved: _loadData,
            ),
            filters: const <String>[
              'All',
              'All Supplier Groups',
              'Raw Material',
              'Services',
              'Bangladesh',
            ],
            selectedFilter: _supplierFilter,
            onFilterChanged: (String f) => setState(() => _supplierFilter = f),
            resultCount: filteredSuppliers.length,
            totalCount: _suppliers.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: filteredSuppliers.length,
                itemBuilder: (BuildContext context, int i) {
                  final Map<String, dynamic> s = filteredSuppliers[i];
                  final String docName = (s['name'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => ErpDocSheet.showViewAndEdit(
                        context,
                        doctype: 'Supplier',
                        docname: docName,
                        onSaved: _loadData,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.storefront_rounded),
                      ),
                      title: Text(
                        '${s['supplier_name'] ?? docName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Group: ${s['supplier_group'] ?? 'All Supplier Groups'} • ${s['country'] ?? 'Bangladesh'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
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

  Widget _buildAssetsTab(String sym) {
    final List<Map<String, dynamic>> filteredAssets = _assets.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _assetStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _assetQuery);
    }).toList();

    final List<Map<String, dynamic>> filteredMovements = _assetMovements.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _assetStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _assetQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAssetMovementSheet,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('New Asset Movement'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText:
                'Search Assets & Movements (ID, name, category, location)...',
            query: _assetQuery,
            onQueryChanged: (String v) => setState(() => _assetQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Asset',
              initialQuery: _assetQuery,
              onSaved: _loadData,
            ),
            filters: const <String>[
              'All',
              'Submitted',
              'Partially Depreciated',
              'Draft',
              'Cancelled',
            ],
            selectedFilter: _assetStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _assetStatusFilter = f),
            resultCount: filteredAssets.length + filteredMovements.length,
            totalCount: _assets.length + _assetMovements.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Company Assets Register (${filteredAssets.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ErpDocSheet.showCreate(
                          context,
                          doctype: 'Asset',
                          onCreated: _loadData,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('+ New Asset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...filteredAssets.map((Map<String, dynamic> a) {
                    final String assetName = (a['name'] ?? '').toString();
                    final double val =
                        (a['gross_purchase_amount'] as num?)?.toDouble() ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => ErpDocSheet.showViewAndEdit(
                          context,
                          doctype: 'Asset',
                          docname: assetName,
                          onSaved: _loadData,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.precision_manufacturing_rounded),
                        ),
                        title: Text(
                          '${a['asset_name'] ?? assetName} ($assetName)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Category: ${a['asset_category'] ?? 'General'} • Location: ${a['location'] ?? 'N/A'}\nValue: $sym${NumberFormat('#,##0').format(val)} • Status: ${a['status'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    'Recent Asset Movements (${filteredMovements.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...filteredMovements.map((Map<String, dynamic> m) {
                    final String moveName = (m['name'] ?? '').toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => ErpDocSheet.showViewAndEdit(
                          context,
                          doctype: 'Asset Movement',
                          docname: moveName,
                          onSaved: _loadData,
                        ),
                        leading: const Icon(
                          Icons.swap_horizontal_circle_outlined,
                        ),
                        title: Text(
                          '$moveName • ${m['purpose'] ?? 'Transfer'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Date: ${m['transaction_date'] ?? ''}'),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
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

  Future<void> _showCreatePurchaseVoucherSheet(String doctype) async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController supplierCtrl = TextEditingController(
      text: _suppliers.isNotEmpty
          ? (_suppliers.first['name'] ?? '').toString()
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'New $doctype',
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
                              doctype: doctype,
                              initialValues: <String, dynamic>{
                                if (session != null) 'company': session.company,
                                'supplier': supplierCtrl.text.trim(),
                              },
                              onCreated: _loadData,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_suppliers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: supplierCtrl.text,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _suppliers
                            .map(
                              (Map<String, dynamic> s) =>
                                  DropdownMenuItem<String>(
                                    value: (s['name'] ?? '').toString(),
                                    child: Text(
                                      '${s['supplier_name'] ?? s['name']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => supplierCtrl.text = v);
                          }
                        },
                      )
                    else
                      TextField(
                        controller: supplierCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
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
                      label: Text('Create $doctype'),
                      onPressed: () async {
                        final double qty =
                            double.tryParse(qtyCtrl.text.trim()) ?? 1;
                        final double rate =
                            double.tryParse(rateCtrl.text.trim()) ?? 0;
                        final String today = DateFormat('yyyy-MM-dd')
                            .format(DateTime.now());
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            doctype,
                            <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'supplier': supplierCtrl.text.trim(),
                              if (doctype ==
                                  'Purchase Order') ...<String, dynamic>{
                                'transaction_date': today,
                                'schedule_date': today,
                              } else
                                'posting_date': today,
                              'items': <Map<String, dynamic>>[
                                <String, dynamic>{
                                  'item_code': selectedItemCode,
                                  'qty': qty,
                                  'rate': rate,
                                  if (doctype == 'Purchase Order')
                                    'schedule_date': today,
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

  Future<void> _showCreateSupplierSheet() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController groupCtrl = TextEditingController(
      text: 'All Supplier Groups',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'New Supplier',
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
                        context,
                        doctype: 'Supplier',
                        initialValues: <String, dynamic>{
                          'supplier_group': groupCtrl.text.trim(),
                        },
                        onCreated: _loadData,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: groupCtrl,
                decoration: const InputDecoration(
                  labelText: 'Supplier Group',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Supplier'),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ErpApiClient.instance.createDoc(
                      'Supplier',
                      <String, dynamic>{
                        'supplier_name': nameCtrl.text.trim(),
                        'supplier_group': groupCtrl.text.trim(),
                      },
                    );
                    await _loadData();
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
        );
      },
    );
  }

  Future<void> _showCreateAssetMovementSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String purpose = 'Issue';
    String selectedAsset = _assets.isNotEmpty
        ? (_assets.first['name'] ?? '').toString()
        : '';
    final TextEditingController targetLocationCtrl = TextEditingController();

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
                          'New Asset Movement',
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
                            doctype: 'Asset Movement',
                            initialValues: <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'purpose': purpose,
                            },
                            onCreated: _loadData,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: purpose,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'Issue',
                        child: Text('Issue (To Employee)'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Transfer',
                        child: Text('Transfer (Between Locations)'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Receipt',
                        child: Text('Receipt (Return to Location)'),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => purpose = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_assets.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedAsset,
                      decoration: const InputDecoration(
                        labelText: 'Asset',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _assets
                          .map(
                            (
                              Map<String, dynamic> a,
                            ) => DropdownMenuItem<String>(
                              value: (a['name'] ?? '').toString(),
                              child: Text(
                                '${a['asset_name'] ?? a['name']} (${a['name']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() => selectedAsset = v);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetLocationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target Location / Employee ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Asset Movement'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'Asset Movement',
                          <String, dynamic>{
                            if (session != null) 'company': session.company,
                            'purpose': purpose,
                            'transaction_date': DateFormat(
                              'yyyy-MM-dd HH:mm:ss',
                            ).format(DateTime.now()),
                            'assets': <Map<String, dynamic>>[
                              <String, dynamic>{
                                'asset': selectedAsset,
                                if (purpose == 'Issue' &&
                                    session != null &&
                                    session.employeeId.isNotEmpty)
                                  'to_employee': session.employeeId
                                else if (targetLocationCtrl.text.isNotEmpty)
                                  'target_location': targetLocationCtrl.text
                                      .trim(),
                              },
                            ],
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
}
