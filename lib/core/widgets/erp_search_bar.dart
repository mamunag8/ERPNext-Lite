import 'package:flutter/material.dart';

/// Reusable top search bar and quick-filter chip strip for ERPNext DocType screens.
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

  /// Multi-token case-insensitive matching across all values in an ERPNext record.
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
    for (final dynamic val in row.values) {
      if (val != null) {
        buffer.write(val.toString().toLowerCase());
        buffer.write(' ');
      }
    }
    final String haystack = buffer.toString();
    for (final String token in tokens) {
      if (!haystack.contains(token)) {
        return false;
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
    return statusVal == fLower || statusVal.contains(fLower);
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int? effectiveCount = widget.resultCount ?? widget.filteredCount;
    final ValueChanged<String>? filterCallback =
        widget.onFilterChanged ?? widget.onFilterSelected;
    final bool hasCount = effectiveCount != null && widget.totalCount != null;

    return Column(
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
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _ctrl.clear();
                      widget.onQueryChanged('');
                    },
                  )
                else
                  const SizedBox(width: 6),
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
    );
  }
}
