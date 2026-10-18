import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  bool _loading = false;
  String? _downloadingSlipName;
  List<Map<String, dynamic>> _salarySlips = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadSalarySlips();
  }

  Future<void> _loadSalarySlips() async {
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> slips = await ErpApiClient.instance
          .getList(
            'Salary Slip',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'department',
              'designation',
              'start_date',
              'end_date',
              'posting_date',
              'gross_pay',
              'total_deduction',
              'net_pay',
              'payment_days',
              'status',
            ],
            orderBy: 'posting_date desc',
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _salarySlips = slips);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf(String slipName) async {
    setState(() => _downloadingSlipName = slipName);
    try {
      final String path = await ErpApiClient.instance.downloadAndOpenPdf(
        doctype: 'Salary Slip',
        docname: slipName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF saved & opened: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF download failed: ${ErpApiClient.formatErrorMessage(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingSlipName = null);
      }
    }
  }

  Future<void> _showSlipDetailBottomSheet(Map<String, dynamic> summary) async {
    final String name = (summary['name'] ?? '').toString();
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    Map<String, dynamic> fullDoc = summary;
    try {
      fullDoc = await ErpApiClient.instance.getDoc('Salary Slip', name);
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final List<dynamic> earnings =
        (fullDoc['earnings'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> deductions =
        (fullDoc['deductions'] as List<dynamic>?) ?? <dynamic>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (BuildContext context, ScrollController scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${fullDoc['employee_name'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$name • ${fullDoc['start_date'] ?? ''} to ${fullDoc['end_date'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _downloadPdf(name);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Download PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _metricColumn(
                        'Gross Pay',
                        '$sym${NumberFormat('#,##0').format(fullDoc['gross_pay'] ?? 0)}',
                      ),
                      _metricColumn(
                        'Deductions',
                        '$sym${NumberFormat('#,##0').format(fullDoc['total_deduction'] ?? 0)}',
                      ),
                      _metricColumn(
                        'Net Pay',
                        '$sym${NumberFormat('#,##0').format(fullDoc['net_pay'] ?? 0)}',
                        highlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Earnings Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                if (earnings.isEmpty)
                  const Text('No individual earning rows loaded.')
                else
                  ...earnings.map((dynamic e) {
                    final Map<String, dynamic> row = Map<String, dynamic>.from(
                      e as Map<dynamic, dynamic>,
                    );
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['salary_component'] ?? ''}'),
                      trailing: Text(
                        '$sym${NumberFormat('#,##0.00').format(row['amount'] ?? 0)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                const Divider(),
                const Text(
                  'Deductions Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                if (deductions.isEmpty)
                  const Text('No deductions.')
                else
                  ...deductions.map((dynamic d) {
                    final Map<String, dynamic> row = Map<String, dynamic>.from(
                      d as Map<dynamic, dynamic>,
                    );
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['salary_component'] ?? ''}'),
                      trailing: Text(
                        '$sym${NumberFormat('#,##0.00').format(row['amount'] ?? 0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _metricColumn(String label, String value, {bool highlight = false}) {
    return Column(
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 18 : 15,
            fontWeight: FontWeight.w800,
            color: highlight ? Colors.green.shade800 : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserSession? session = ErpApiClient.instance.session;
    final String sym = session?.currencySymbol ?? '৳';

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll & Salary Slips')),
      body: _loading && _salarySlips.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSalarySlips,
              child: _salarySlips.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        Center(child: Text('No Salary Slips found.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _salarySlips.length,
                      itemBuilder: (BuildContext context, int idx) {
                        final Map<String, dynamic> slip = _salarySlips[idx];
                        final String slipName = (slip['name'] ?? '').toString();
                        final double netPay =
                            (slip['net_pay'] as num?)?.toDouble() ?? 0;
                        final double grossPay =
                            (slip['gross_pay'] as num?)?.toDouble() ?? 0;
                        final bool isDownloading =
                            _downloadingSlipName == slipName;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => _showSlipDetailBottomSheet(slip),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.withValues(
                                alpha: 0.15,
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Colors.teal,
                              ),
                            ),
                            title: Text(
                              '${slip['employee_name'] ?? slip['employee'] ?? ''} • $sym${NumberFormat('#,##0').format(netPay)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Period: ${slip['start_date'] ?? ''} → ${slip['end_date'] ?? ''}\nGross: $sym${NumberFormat('#,##0').format(grossPay)} • Days: ${slip['payment_days'] ?? 30}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Download Salary Slip PDF',
                              onPressed: isDownloading
                                  ? null
                                  : () => _downloadPdf(slipName),
                              icon: isDownloading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.redAccent,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
