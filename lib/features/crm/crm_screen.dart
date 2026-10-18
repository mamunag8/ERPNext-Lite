import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

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

  List<Map<String, dynamic>> _leads = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _deals = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _crmTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _todos = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
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

    // 1. Leads: Try FCRM `CRM Lead` first (1,827+ records at DIBL), fallback to standard `Lead`
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
              limitPageLength: 50,
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
              limitPageLength: 50,
            );
        if (mounted) {
          setState(() {
            _usingFcrm = false;
            _leads = stdLeads;
          });
        }
      } catch (_) {}
    }

    // 2. Deals / Opportunities: Try `CRM Deal` (595 records at DIBL) or `Opportunity`
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
                'Creation',
              ],
              limitPageLength: 40,
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
              limitPageLength: 40,
            );
        if (mounted) {
          setState(() => _deals = opps);
        }
      }
    } catch (_) {}

    // 3. CRM Tasks & ToDos (2,141 CRM Tasks + 5,574 ToDos at DIBL)
    try {
      if (_usingFcrm) {
        final List<Map<String, dynamic>> tasks = await ErpApiClient.instance
            .getList(
              'CRM Task',
              fields: <String>[
                'name',
                'title',
                'status',
                'priority',
                'due_date',
                'assigned_to',
              ],
              limitPageLength: 40,
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
            limitPageLength: 40,
          );
      if (mounted) {
        setState(() => _todos = todoDocs);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateLeadSheet() async {
    final TextEditingController firstNameCtrl = TextEditingController();
    final TextEditingController orgCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();

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
              Text(
                _usingFcrm ? 'New CRM Lead (FCRM)' : 'New ERPNext Lead',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact / Lead Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organization / Company Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
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
                        },
                      );
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lead created!')),
                      );
                    }
                    await _loadCrmData();
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

  Future<void> _showCreateTodoSheet() async {
    final TextEditingController titleCtrl = TextEditingController();
    String priority = 'Medium';

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
                    'New To-Do / Follow-up Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Task Description / Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: const <String>['Low', 'Medium', 'High']
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Create Task'),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'ToDo',
                          <String, dynamic>{
                            'description': titleCtrl.text.trim(),
                            'priority': priority,
                            'status': 'Open',
                          },
                        );
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
        title: Text(_usingFcrm ? 'CRM (Frappe CRM) & Tasks' : 'CRM & Tasks'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.leaderboard_rounded), text: 'Leads'),
            Tab(icon: Icon(Icons.handshake_rounded), text: 'Deals / Opps'),
            Tab(icon: Icon(Icons.task_alt_rounded), text: 'To-Do & Tasks'),
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
              ],
            ),
    );
  }

  Widget _buildLeadsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeadSheet,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Lead'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCrmData,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _leads.length,
          itemBuilder: (BuildContext context, int i) {
            final Map<String, dynamic> l = _leads[i];
            final String title =
                (l['lead_name'] ??
                        l['first_name'] ??
                        l['organization'] ??
                        l['name'] ??
                        '')
                    .toString();
            final String org = (l['organization'] ?? l['company_name'] ?? '')
                .toString();
            final String mobile = (l['mobile_no'] ?? '').toString();
            final String status = (l['status'] ?? 'New').toString();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_search_rounded),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${org.isNotEmpty ? '$org • ' : ''}$status ${mobile.isNotEmpty ? '\nTel: $mobile' : ''}',
                ),
                isThreeLine: mobile.isNotEmpty,
                trailing: mobile.isNotEmpty
                    ? IconButton(
                        tooltip: 'Call Lead',
                        icon: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          launchUrl(Uri.parse('tel:$mobile'));
                        },
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDealsTab() {
    return RefreshIndicator(
      onRefresh: _loadCrmData,
      child: _deals.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: const <Widget>[
                Center(child: Text('No Deals / Opportunities found.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _deals.length,
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> d = _deals[i];
                final String org =
                    (d['organization'] ??
                            d['customer_name'] ??
                            d['party_name'] ??
                            d['name'] ??
                            '')
                        .toString();
                final String status = (d['status'] ?? 'Open').toString();
                final dynamic val =
                    d['deal_value'] ?? d['opportunity_amount'] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.monetization_on_outlined),
                    ),
                    title: Text(
                      org,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${d['name']} • Value: $val • Owner: ${d['deal_owner'] ?? d['opportunity_owner'] ?? ''}',
                    ),
                    trailing: Chip(
                      label: Text(status, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTasksTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTodoSheet,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New To-Do'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCrmData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_crmTasks.isNotEmpty) ...<Widget>[
              const Text(
                'CRM Follow-up Tasks',
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
            const Text(
              'Desk To-Do List',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._todos.map((Map<String, dynamic> td) {
              final String rawDesc = (td['description'] ?? td['name'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'<[^>]*>'), '');
              final String status = (td['status'] ?? 'Open').toString();
              final bool closed = status == 'Closed';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
                    'Status: $status • Priority: ${td['priority'] ?? 'Medium'}',
                  ),
                  trailing: IconButton(
                    tooltip: closed ? 'Reopen ToDo' : 'Close ToDo',
                    icon: Icon(
                      closed ? Icons.replay_rounded : Icons.done_all_rounded,
                    ),
                    onPressed: () async {
                      try {
                        await ErpApiClient.instance.updateDoc(
                          'ToDo',
                          (td['name'] ?? '').toString(),
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
    );
  }
}
