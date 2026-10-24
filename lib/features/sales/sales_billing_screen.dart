import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';

class SalesBillingScreen extends StatefulWidget {
  const SalesBillingScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<SalesBillingScreen> createState() => _SalesBillingScreenState();
}

class _SalesBillingScreenState extends State<SalesBillingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _salesInvoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salesOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _quotations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _payments = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _journalEntries = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _accounts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadSalesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesData() async {
    setState(() => _loading = true);

    try {
      final List<Map<String, dynamic>> invoices = await ErpApiClient.instance
          .getList(
            'Sales Invoice',
            fields: <String>[
              'name',
              'customer',
              'customer_name',
              'posting_date',
              'grand_total',
              'outstanding_amount',
              'status',
              'docstatus',
            ],
            limitPageLength: 50,
          );
      if (mounted) {
        setState(() => _salesInvoices = invoices);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> orders = await ErpApiClient.instance
          .getList(
            'Sales Order',
            fields: <String>[
              'name',
              'customer',
              'customer_name',
              'transaction_date',
              'delivery_date',
              'grand_total',
              'status',
            ],
            limitPageLength: 50,
          );
      if (mounted) {
        setState(() => _salesOrders = orders);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> quotes = await ErpApiClient.instance
          .getList(
            'Quotation',
            fields: <String>[
              'name',
              'party_name',
              'customer_name',
              'transaction_date',
              'grand_total',
              'status',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _quotations = quotes);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> pays = await ErpApiClient.instance
          .getList(
            'Payment Entry',
            fields: <String>[
              'name',
              'payment_type',
              'party_type',
              'party',
              'party_name',
              'posting_date',
              'paid_amount',
              'mode_of_payment',
              'status',
            ],
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _payments = pays);
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> custs = await ErpApiClient.instance
          .getList(
            'Customer',
            fields: <String>['name', 'customer_name'],
            limitPageLength: 80,
          );
      final List<Map<String, dynamic>> itemDocs = await ErpApiClient.instance
          .getList(
            'Item',
            fields: <String>['name', 'item_code', 'item_name', 'standard_rate'],
            filters: <String, dynamic>{'disabled': 0},
            limitPageLength: 80,
          );
      if (mounted) {
        setState(() {
          _customers = custs;
          _items = itemDocs;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> jvs = await ErpApiClient.instance
          .getList(
            'Journal Entry',
            fields: <String>[
              'name',
              'voucher_type',
              'posting_date',
              'total_debit',
              'total_credit',
              'user_remark',
              'docstatus',
            ],
            limitPageLength: 40,
          );
      final List<Map<String, dynamic>> accs = await ErpApiClient.instance
          .getList(
            'Account',
            fields: <String>['name', 'account_name', 'account_type'],
            filters: <String, dynamic>{'is_group': 0, 'disabled': 0},
            limitPageLength: 80,
          );
      if (mounted) {
        setState(() {
          _journalEntries = jvs;
          _accounts = accs;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateSalesVoucherSheet(String doctype) async {
    final UserSession? session = ErpApiClient.instance.session;
    final TextEditingController phoneSearchCtrl = TextEditingController();
    final TextEditingController customerCtrl = TextEditingController(
      text: _customers.isNotEmpty
          ? (_customers.first['name'] ?? '').toString()
          : '',
    );
    final TextEditingController contactNumberCtrl = TextEditingController();
    String selectedContactPerson = '';
    String selectedItemCode = _items.isNotEmpty
        ? (_items.first['item_code'] ?? _items.first['name'] ?? '').toString()
        : '';
    final TextEditingController qtyCtrl = TextEditingController(text: '1');
    final TextEditingController rateCtrl = TextEditingController(
      text: _items.isNotEmpty
          ? ((_items.first['standard_rate'] ?? 1000)).toString()
          : '1000',
    );
    String selectedDepartment =
        (session != null && session.departments.isNotEmpty)
        ? session.departments.first
        : 'Branch Operations- DIBL';
    bool searchingPhone = false;

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
                      'New $doctype',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Replicates DIBL's `custom_search_by_mobile` Client Script
                    TextField(
                      controller: phoneSearchCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Search Customer by Mobile Number',
                        hintText: '017XXXXXXXX (Auto-fills Customer & Contact)',
                        prefixIcon: const Icon(Icons.phone_callback_rounded),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: searchingPhone
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                          onPressed: () async {
                            setModalState(() => searchingPhone = true);
                            try {
                              final Map<String, String>? found =
                                  await ErpApiClient.instance
                                      .findCustomerByMobile(
                                        phoneSearchCtrl.text,
                                      );
                              if (found != null) {
                                setModalState(() {
                                  if ((found['customer'] ?? '').isNotEmpty) {
                                    customerCtrl.text = found['customer']!;
                                  }
                                  selectedContactPerson =
                                      found['contact_person'] ?? '';
                                  contactNumberCtrl.text =
                                      found['contact_number'] ?? '';
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Found Customer: ${found['customer']} (${found['contact_number']})',
                                      ),
                                    ),
                                  );
                                }
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No linked customer found for that phone number.',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              setModalState(() => searchingPhone = false);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_customers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue:
                            _customers.any(
                              (Map<String, dynamic> c) =>
                                  c['name'] == customerCtrl.text,
                            )
                            ? customerCtrl.text
                            : (_customers.first['name'] ?? '').toString(),
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _customers
                            .map(
                              (Map<String, dynamic> c) =>
                                  DropdownMenuItem<String>(
                                    value: (c['name'] ?? '').toString(),
                                    child: Text(
                                      '${c['customer_name'] ?? c['name']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: (String? val) {
                          if (val != null) {
                            setModalState(() => customerCtrl.text = val);
                          }
                        },
                      )
                    else
                      TextField(
                        controller: customerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer ID / Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (session != null &&
                        session.departments.isNotEmpty &&
                        doctype != 'Quotation') ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: selectedDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: session.departments
                            .map(
                              (String d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d),
                              ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => selectedDepartment = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
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
                            final Map<String, dynamic>? itemObj = _items
                                .where(
                                  (Map<String, dynamic> e) =>
                                      (e['item_code'] ?? e['name']) == v,
                                )
                                .firstOrNull;
                            setModalState(() {
                              selectedItemCode = v;
                              if (itemObj != null &&
                                  itemObj['standard_rate'] != null &&
                                  (itemObj['standard_rate'] as num) > 0) {
                                rateCtrl.text = itemObj['standard_rate']
                                    .toString();
                              }
                            });
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
                            decoration: InputDecoration(
                              labelText:
                                  'Rate (${session?.currencySymbol ?? '৳'})',
                              border: const OutlineInputBorder(),
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
                          final Map<String, dynamic>
                          payload = <String, dynamic>{
                            if (session != null) 'company': session.company,
                            if (doctype == 'Quotation') ...<String, dynamic>{
                              'quotation_to': 'Customer',
                              'party_name': customerCtrl.text.trim(),
                              'transaction_date': today,
                            } else if (doctype ==
                                'Sales Order') ...<String, dynamic>{
                              'customer': customerCtrl.text.trim(),
                              'transaction_date': today,
                              'delivery_date': today,
                              'department': selectedDepartment,
                              if (contactNumberCtrl.text.isNotEmpty)
                                'custom_contact_number': contactNumberCtrl.text,
                              if (selectedContactPerson.isNotEmpty)
                                'contact_person': selectedContactPerson,
                            } else ...<String, dynamic>{
                              'customer': customerCtrl.text.trim(),
                              'posting_date': today,
                              'due_date': today,
                              'department': selectedDepartment,
                              if (contactNumberCtrl.text.isNotEmpty)
                                'custom_contact_number': contactNumberCtrl.text,
                              if (selectedContactPerson.isNotEmpty)
                                'contact_person': selectedContactPerson,
                            },
                            'items': <Map<String, dynamic>>[
                              <String, dynamic>{
                                'item_code': selectedItemCode,
                                'qty': qty,
                                'rate': rate,
                                if (doctype == 'Sales Order')
                                  'delivery_date': today,
                              },
                            ],
                          };
                          final Map<String, dynamic> created =
                              await ErpApiClient.instance.createDoc(
                                doctype,
                                payload,
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$doctype ${created['name'] ?? ''} created!',
                                ),
                              ),
                            );
                          }
                          await _loadSalesData();
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

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales, Billing & Accounts'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.receipt_rounded), text: 'Sales Invoices'),
            Tab(icon: Icon(Icons.shopping_bag_rounded), text: 'Sales Orders'),
            Tab(icon: Icon(Icons.request_quote_rounded), text: 'Quotations'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Payments'),
            Tab(
              icon: Icon(Icons.account_balance_rounded),
              text: 'Journal Entries',
            ),
          ],
        ),
      ),
      body: _loading && _salesInvoices.isEmpty && _salesOrders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _buildInvoicesTab(sym),
                _buildOrdersTab(sym),
                _buildQuotationsTab(sym),
                _buildPaymentsTab(sym),
                _buildJournalEntriesTab(sym),
              ],
            ),
    );
  }

  Widget _buildInvoicesTab(String sym) {
    // Replicates DIBL's `Sales Invoice List View Grand Total` Client Script
    double totalBilled = 0;
    double totalOutstanding = 0;
    int validCount = 0;

    for (final Map<String, dynamic> row in _salesInvoices) {
      if (row['status'] != 'Cancelled' && row['docstatus'] != 2) {
        totalBilled += (row['grand_total'] as num?)?.toDouble() ?? 0;
        totalOutstanding +=
            (row['outstanding_amount'] as num?)?.toDouble() ?? 0;
        validCount++;
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSalesVoucherSheet('Sales Invoice'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Invoice'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total Billed ($validCount Active)',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '$sym ${NumberFormat('#,##0.00').format(totalBilled)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Text(
                        'Total Outstanding',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '$sym ${NumberFormat('#,##0.00').format(totalOutstanding)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._salesInvoices.map((Map<String, dynamic> inv) {
              final String docName = (inv['name'] ?? '').toString();
              final double gt = (inv['grand_total'] as num?)?.toDouble() ?? 0;
              final double out =
                  (inv['outstanding_amount'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => ErpDocSheet.showViewAndEdit(
                    context,
                    doctype: 'Sales Invoice',
                    docname: docName,
                    onSaved: _loadSalesData,
                  ),
                  title: Text(
                    '${inv['customer_name'] ?? inv['customer'] ?? ''} • $sym${NumberFormat('#,##0').format(gt)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$docName • ${inv['posting_date'] ?? ''} • Due: $sym${NumberFormat('#,##0').format(out)} (${inv['status'] ?? ''})',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Download Invoice PDF',
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            ErpApiClient.instance.downloadAndOpenPdf(
                              doctype: 'Sales Invoice',
                              docname: docName,
                            ),
                      ),
                      const Icon(Icons.edit_note_rounded, size: 20),
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

  Widget _buildOrdersTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSalesVoucherSheet('Sales Order'),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('New Sales Order'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _salesOrders.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> so = _salesOrders[i];
            final String docName = (so['name'] ?? '').toString();
            final double gt = (so['grand_total'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Sales Order',
                  docname: docName,
                  onSaved: _loadSalesData,
                ),
                title: Text(
                  '${so['customer_name'] ?? so['customer'] ?? ''} • $sym${NumberFormat('#,##0').format(gt)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$docName • Date: ${so['transaction_date'] ?? ''} • ${so['status'] ?? ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Download Sales Order PDF',
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => ErpApiClient.instance.downloadAndOpenPdf(
                        doctype: 'Sales Order',
                        docname: docName,
                      ),
                    ),
                    const Icon(Icons.edit_note_rounded, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuotationsTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSalesVoucherSheet('Quotation'),
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('New Quotation'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _quotations.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> q = _quotations[i];
            final String docName = (q['name'] ?? '').toString();
            final double gt = (q['grand_total'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Quotation',
                  docname: docName,
                  onSaved: _loadSalesData,
                ),
                title: Text(
                  '${q['customer_name'] ?? q['party_name'] ?? ''} • $sym${NumberFormat('#,##0').format(gt)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$docName • ${q['transaction_date'] ?? ''} • ${q['status'] ?? ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Download Quotation PDF',
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => ErpApiClient.instance.downloadAndOpenPdf(
                        doctype: 'Quotation',
                        docname: docName,
                      ),
                    ),
                    const Icon(Icons.edit_note_rounded, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentsTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePaymentSheet,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('New Payment'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _payments.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> p = _payments[i];
            final String docName = (p['name'] ?? '').toString();
            final double paid = (p['paid_amount'] as num?)?.toDouble() ?? 0;
            final String pType = (p['payment_type'] ?? 'Receive').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Payment Entry',
                  docname: docName,
                  onSaved: _loadSalesData,
                ),
                leading: CircleAvatar(
                  backgroundColor: pType == 'Receive'
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  child: Icon(
                    pType == 'Receive'
                        ? Icons.call_received_rounded
                        : Icons.call_made_rounded,
                    color: pType == 'Receive'
                        ? Colors.green
                        : Colors.deepOrange,
                  ),
                ),
                title: Text(
                  '${p['party_name'] ?? p['party'] ?? p['name']} • $sym${NumberFormat('#,##0').format(paid)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$docName • $pType (${p['mode_of_payment'] ?? 'Cash/Bank'}) • ${p['posting_date'] ?? ''}',
                ),
                trailing: const Icon(Icons.edit_note_rounded, size: 20),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJournalEntriesTab(String sym) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateJournalEntrySheet,
        icon: const Icon(Icons.post_add_rounded),
        label: const Text('New Journal Entry'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _journalEntries.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> jv = _journalEntries[i];
            final String docName = (jv['name'] ?? '').toString();
            final double debit = (jv['total_debit'] as num?)?.toDouble() ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => ErpDocSheet.showViewAndEdit(
                  context,
                  doctype: 'Journal Entry',
                  docname: docName,
                  onSaved: _loadSalesData,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                title: Text(
                  '$docName • $sym${NumberFormat('#,##0').format(debit)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${jv['voucher_type'] ?? 'Journal Entry'} • ${jv['posting_date'] ?? ''}\n${jv['user_remark'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Download Journal Voucher PDF',
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => ErpApiClient.instance.downloadAndOpenPdf(
                        doctype: 'Journal Entry',
                        docname: docName,
                      ),
                    ),
                    const Icon(Icons.edit_note_rounded, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreatePaymentSheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String paymentType = 'Receive';
    final TextEditingController partyCtrl = TextEditingController(
      text: _customers.isNotEmpty
          ? (_customers.first['name'] ?? '').toString()
          : '',
    );
    final TextEditingController amountCtrl = TextEditingController();
    String modeOfPayment = 'Cash';

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
                  const Text(
                    'New Payment Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentType,
                    decoration: const InputDecoration(
                      labelText: 'Payment Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'Receive',
                        child: Text('Receive (From Customer)'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Pay',
                        child: Text('Pay (To Supplier / Employee)'),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => paymentType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Party (Customer / Supplier / Employee)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: modeOfPayment,
                    decoration: const InputDecoration(
                      labelText: 'Mode of Payment',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'Cash',
                        child: Text('Cash'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Bank Draft',
                        child: Text('Bank / Transfer'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Cheque',
                        child: Text('Cheque'),
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) {
                        setModalState(() => modeOfPayment = v);
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
                          'Paid Amount (${session?.currencySymbol ?? '৳'})',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Payment Entry'),
                    onPressed: () async {
                      final double amt =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt <= 0) {
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'Payment Entry',
                          <String, dynamic>{
                            if (session != null) 'company': session.company,
                            'payment_type': paymentType,
                            'party_type': paymentType == 'Receive'
                                ? 'Customer'
                                : 'Supplier',
                            'party': partyCtrl.text.trim(),
                            'mode_of_payment': modeOfPayment,
                            'paid_amount': amt,
                            'received_amount': amt,
                            'posting_date': DateFormat('yyyy-MM-dd')
                                .format(DateTime.now()),
                          },
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment Entry created!'),
                            ),
                          );
                        }
                        await _loadSalesData();
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

  Future<void> _showCreateJournalEntrySheet() async {
    final UserSession? session = ErpApiClient.instance.session;
    String debitAccount = _accounts.isNotEmpty
        ? (_accounts.first['name'] ?? '').toString()
        : '';
    String creditAccount = _accounts.length > 1
        ? (_accounts[1]['name'] ?? '').toString()
        : debitAccount;
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController remarkCtrl = TextEditingController();

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
                      'New Journal Entry (JV)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_accounts.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: debitAccount,
                        decoration: const InputDecoration(
                          labelText: 'Debit Account',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _accounts
                            .map(
                              (Map<String, dynamic> a) =>
                                  DropdownMenuItem<String>(
                                    value: (a['name'] ?? '').toString(),
                                    child: Text(
                                      (a['name'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => debitAccount = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: creditAccount,
                        decoration: const InputDecoration(
                          labelText: 'Credit Account',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _accounts
                            .map(
                              (Map<String, dynamic> a) =>
                                  DropdownMenuItem<String>(
                                    value: (a['name'] ?? '').toString(),
                                    child: Text(
                                      (a['name'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(),
                        onChanged: (String? v) {
                          if (v != null) {
                            setModalState(() => creditAccount = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (${session?.currencySymbol ?? '৳'})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarkCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'User Remark / Narration',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Create Journal Entry'),
                      onPressed: () async {
                        final double amt =
                            double.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (amt <= 0) {
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await ErpApiClient.instance.createDoc(
                            'Journal Entry',
                            <String, dynamic>{
                              if (session != null) 'company': session.company,
                              'voucher_type': 'Journal Entry',
                              'posting_date': DateFormat('yyyy-MM-dd')
                                  .format(DateTime.now()),
                              'user_remark': remarkCtrl.text.trim(),
                              if (debitAccount.isNotEmpty &&
                                  creditAccount.isNotEmpty)
                                'accounts': <Map<String, dynamic>>[
                                  <String, dynamic>{
                                    'account': debitAccount,
                                    'debit_in_account_currency': amt,
                                    'credit_in_account_currency': 0,
                                  },
                                  <String, dynamic>{
                                    'account': creditAccount,
                                    'debit_in_account_currency': 0,
                                    'credit_in_account_currency': amt,
                                  },
                                ],
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Journal Entry created!'),
                              ),
                            );
                          }
                          await _loadSalesData();
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
