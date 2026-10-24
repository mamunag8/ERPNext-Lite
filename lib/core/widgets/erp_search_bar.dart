import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_session.dart';
import '../network/api_client.dart';

/// Reusable top search bar, quick-filter chip strip, and multi-field ERPNext
/// filter drawer for all DocType screens.
class ErpSearchBar extends StatefulWidget {
  const ErpSearchBar({
    super.key,
    required this.hintText,
    required this.query,
    required this.onQueryChanged,
    this.filters = const <String>[],
    this.selectedFilter = 'All',
    this.onFilterSelected,
    this.onFilterChanged,
    this.filteredCount,
    this.resultCount,
    this.totalCount,
    this.onSubmitted,
    this.onServerSearch,
  });

  final String hintText;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String>? onFilterSelected;
  final ValueChanged<String>? onFilterChanged;
  final int? filteredCount;
  final int? resultCount;
  final int? totalCount;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onServerSearch;

  /// Multi-token case-insensitive matching across all values in an ERPNext record,
  /// plus support for structured `field=value` filter tokens from the Filter Sheet.
  static bool matchesQuery(Map<String, dynamic> row, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    final List<String> tokens = q
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return true;
    }
    final StringBuffer buffer = StringBuffer();
    for (final MapEntry<String, dynamic> e in row.entries) {
      if (e.value != null) {
        buffer.write(e.key.toLowerCase());
        buffer.write(':');
        buffer.write(e.value.toString().toLowerCase());
        buffer.write(' ');
      }
    }
    final String haystack = buffer.toString();

    for (final String token in tokens) {
      if (token.contains('=')) {
        final int eqIdx = token.indexOf('=');
        final String fieldKey = token.substring(0, eqIdx).trim();
        final String expectedVal = token
            .substring(eqIdx + 1)
            .replaceAll('_', ' ')
            .trim();
        if (expectedVal.isEmpty) {
          continue;
        }
        if (fieldKey == 'status') {
          if (!matchesFilter(row, expectedVal)) {
            return false;
          }
          continue;
        }
        bool matchedField = false;
        for (final MapEntry<String, dynamic> entry in row.entries) {
          if (entry.key.toLowerCase().contains(fieldKey) &&
              entry.value != null &&
              entry.value.toString().toLowerCase().contains(expectedVal)) {
            matchedField = true;
            break;
          }
        }
        if (!matchedField && !haystack.contains(expectedVal)) {
          return false;
        }
      } else {
        if (!haystack.contains(token)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Checks whether a record matches a quick-filter chip (status, docstatus, priority, or type).
  static bool matchesFilter(
    Map<String, dynamic> row,
    String selectedFilter, {
    String field = 'status',
  }) {
    final String f = selectedFilter.trim();
    if (f.isEmpty || f == 'All') {
      return true;
    }
    final String fLower = f.toLowerCase();
    final int? docstatus = (row['docstatus'] as num?)?.toInt();
    final String statusVal = (row[field] ?? row['status'] ?? '')
        .toString()
        .toLowerCase();
    final String priorityVal = (row['priority'] ?? '').toString().toLowerCase();

    if (fLower == 'draft') {
      return statusVal == 'draft' || docstatus == 0;
    }
    if (fLower == 'submitted') {
      return statusVal == 'submitted' || docstatus == 1;
    }
    if (fLower == 'cancelled') {
      return statusVal == 'cancelled' || docstatus == 2;
    }
    if (fLower == 'high priority' || fLower == 'high') {
      return priorityVal == 'high' || statusVal == 'high';
    }
    if (fLower == 'medium') {
      return priorityVal == 'medium' || statusVal == 'medium';
    }
    if (fLower == 'low') {
      return priorityVal == 'low' || statusVal == 'low';
    }
    return statusVal == fLower ||
        statusVal.contains(fLower) ||
        matchesQuery(row, fLower);
  }

  @override
  State<ErpSearchBar> createState() => _ErpSearchBarState();
}

class _ErpSearchBarState extends State<ErpSearchBar> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant ErpSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyStructuredFilterToken(String key, String rawVal) {
    final String encoded = '$key=${rawVal.trim().replaceAll(' ', '_')}';
    final List<String> existing = _ctrl.text
        .split(RegExp(r'\s+'))
        .where(
          (String t) => t.isNotEmpty && !t.toLowerCase().startsWith('$key='),
        )
        .toList();
    existing.add(encoded);
    final String nextQuery = existing.join(' ');
    _ctrl.text = nextQuery;
    widget.onQueryChanged(nextQuery);
  }

  void _removeToken(String tokenToRemove) {
    final List<String> remaining = _ctrl.text
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty && t != tokenToRemove)
        .toList();
    final String nextQuery = remaining.join(' ');
    _ctrl.text = nextQuery;
    widget.onQueryChanged(nextQuery);
  }

  Future<void> _openFilterBottomSheet(
    ValueChanged<String>? filterCallback,
  ) async {
    final UserSession? session = ErpApiClient.instance.session;
    final List<String> statusOptions = widget.filters.isNotEmpty
        ? widget.filters
        : const <String>['All', 'Draft', 'Submitted', 'Open', 'Completed'];
    final List<String> priorities = const <String>['High', 'Medium', 'Low'];
    final List<String> departments = session?.departments ?? const <String>[];
    final List<String> projects = session?.projects ?? const <String>[];
    final List<String> costCenters = session?.costCenters ?? const <String>[];
    final List<String> warehouses = session?.warehouses ?? const <String>[];
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String thisMonth = DateFormat('yyyy-MM').format(DateTime.now());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (BuildContext context, ScrollController scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.filter_alt_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ERPNext Multi-Field Filters',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _ctrl.clear();
                        widget.onQueryChanged('');
                        filterCallback?.call('All');
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                      label: const Text('Reset All'),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 6),
                const Text(
                  'Status / Stage Filter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: statusOptions.map((String st) {
                    final bool isSel = widget.selectedFilter == st;
                    return ChoiceChip(
                      label: Text(st, style: const TextStyle(fontSize: 12)),
                      selected: isSel,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        if (filterCallback != null) {
                          filterCallback(st);
                        } else if (st == 'All') {
                          _removeToken('status=${widget.selectedFilter}');
                        } else {
                          _applyStructuredFilterToken('status', st);
                        }
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Priority Filter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: priorities.map((String p) {
                    return ActionChip(
                      avatar: const Icon(Icons.flag_outlined, size: 15),
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _applyStructuredFilterToken('priority', p);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Date / Period Filter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(Icons.today_rounded, size: 15),
                      label: Text(
                        'Today ($today)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _applyStructuredFilterToken('date', today);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 15),
                      label: Text(
                        'This Month ($thisMonth)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _applyStructuredFilterToken('date', thisMonth);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_month_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Pick Specific Date...',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          _applyStructuredFilterToken(
                            'date',
                            DateFormat('yyyy-MM-dd').format(picked),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                    ),
                  ],
                ),
                if (projects.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Project Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: projects.take(12).map((String proj) {
                      return ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 15),
                        label: Text(proj, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _applyStructuredFilterToken('project', proj);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (departments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Department Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: departments.take(12).map((String dept) {
                      return ActionChip(
                        avatar: const Icon(Icons.apartment_rounded, size: 15),
                        label: Text(dept, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _applyStructuredFilterToken('department', dept);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (costCenters.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Cost Center Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: costCenters.take(10).map((String cc) {
                      return ActionChip(
                        avatar: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 15,
                        ),
                        label: Text(cc, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _applyStructuredFilterToken('cost_center', cc);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (warehouses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Warehouse Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: warehouses.take(10).map((String wh) {
                      return ActionChip(
                        avatar: const Icon(Icons.warehouse_outlined, size: 15),
                        label: Text(wh, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _applyStructuredFilterToken('warehouse', wh);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int? effectiveCount = widget.resultCount ?? widget.filteredCount;
    final ValueChanged<String>? filterCallback =
        widget.onFilterChanged ?? widget.onFilterSelected;
    final bool hasCount = effectiveCount != null && widget.totalCount != null;

    final List<String> structuredTokens = widget.query
        .split(RegExp(r'\s+'))
        .where((String t) => t.contains('='))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _ctrl,
            onChanged: widget.onQueryChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (hasCount)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$effectiveCount/${widget.totalCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (widget.query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search & filters',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _ctrl.clear();
                        widget.onQueryChanged('');
                      },
                    ),
                  if (widget.onServerSearch != null)
                    IconButton(
                      tooltip: 'Search ERPNext Server',
                      icon: const Icon(Icons.cloud_sync_rounded, size: 19),
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onServerSearch,
                    ),
                  IconButton(
                    tooltip: 'Filter Records',
                    icon: Badge(
                      isLabelVisible:
                          structuredTokens.isNotEmpty ||
                          widget.selectedFilter != 'All',
                      child: const Icon(Icons.tune_rounded, size: 19),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openFilterBottomSheet(filterCallback),
                  ),
                ],
              ),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colors.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colors.outline.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          if (structuredTokens.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: structuredTokens.map((String t) {
                return InputChip(
                  label: Text(
                    t.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _removeToken(t),
                );
              }).toList(),
            ),
          ],
          if (widget.filters.isNotEmpty && filterCallback != null) ...<Widget>[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.filters.map((String f) {
                  final bool selected = widget.selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: selected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => filterCallback(f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
