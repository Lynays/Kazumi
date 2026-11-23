import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/date_time.dart';
import 'package:kazumi/utils/search_parser.dart';

class SearchFilterResult {
  const SearchFilterResult({
    required this.filterState,
    required this.notShowWatched,
    required this.notShowAbandoned,
  });

  final SearchFilterState filterState;
  final bool notShowWatched;
  final bool notShowAbandoned;
}

const Map<String, String> searchSortLabels = {
  'heat': '热度',
  'rank': '排名',
  'score': '评分',
  'match': '匹配',
};

String formatSearchSortLabel(String sort) => searchSortLabels[sort] ?? '热度';

String formatSearchFilterSummary(SearchFilterState state) => [
  ...state.tags,
  if (state.season.isNotEmpty) state.season,
  if (state.season.isEmpty && state.dateRange != null)
    '${state.dateRange!.start} 至 ${state.dateRange!.end}',
  if (state.scoreRange?.isValid == true) '评分 ${state.scoreRange!.toToken()}',
  if (state.rankRange?.isValid == true) '排名 ${state.rankRange!.toToken()}',
  if (state.weekdays.isNotEmpty)
    '周${state.weekdays.map((day) => '一二三四五六日'[day - 1]).join('、')}',
].join(' · ');

String formatReadableSearchQuery(String query) {
  final state = SearchParser(query).toFilterState();
  final summary = formatSearchFilterSummary(state);
  return [
    if (state.keyword.isNotEmpty) state.keyword,
    if (state.id.isNotEmpty) '条目 ${state.id}',
    if (summary.isNotEmpty) summary,
    if (state.sort != 'heat') '${formatSearchSortLabel(state.sort)}排序',
  ].join(' · ');
}

/// 可复用筛选面板，同时供 SearchPage 底部弹窗与顶栏二级下拉面板使用。
class SearchFilterPanel extends StatefulWidget {
  const SearchFilterPanel({
    super.key,
    required this.initialState,
    required this.initialNotShowWatched,
    required this.initialNotShowAbandoned,
    required this.onApply,
    required this.onClose,
    this.showDragHandle = true,
  });

  final SearchFilterState initialState;
  final bool initialNotShowWatched;
  final bool initialNotShowAbandoned;
  final ValueChanged<SearchFilterResult> onApply;
  final VoidCallback onClose;
  final bool showDragHandle;

  @override
  State<SearchFilterPanel> createState() => _SearchFilterPanelState();
}

class _SearchFilterPanelState extends State<SearchFilterPanel> {
  late SearchFilterState _draft = widget.initialState;
  late bool _notShowWatched = widget.initialNotShowWatched;
  late bool _notShowAbandoned = widget.initialNotShowAbandoned;
  final TextEditingController _tagController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Map<String, String> get _seasonOptions {
    final now = DateTime.now();
    final values = <String, String>{};
    for (int year = now.year; year >= now.year - 19; year--) {
      for (int quarter = 4; quarter >= 1; quarter--) {
        final date = DateTime(year, (quarter - 1) * 3 + 1, 1);
        if (now.isAfter(date)) {
          values['${year}Q$quarter'] =
              '$year ${const ['冬季', '春季', '夏季', '秋季'][quarter - 1]}';
        }
      }
    }
    return {
      if (_draft.season.isNotEmpty && !values.containsKey(_draft.season))
        _draft.season: _draft.season,
      ...values,
    };
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty || _draft.tags.contains(tag)) return;
    setState(() {
      _draft = _draft.copyWith(tags: [..._draft.tags, tag]);
      _tagController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _reset() {
    setState(() {
      _draft = SearchFilterState(id: _draft.id, keyword: _draft.keyword);
      _notShowWatched = false;
      _notShowAbandoned = false;
      _tagController.clear();
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialStart = _draft.dateRange?.start != null
        ? DateTime.tryParse(_draft.dateRange!.start)
        : null;
    final initialEnd = _draft.dateRange?.end != null
        ? DateTime.tryParse(_draft.dateRange!.end)
        : null;
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialDateRange: initialStart != null && initialEnd != null
          ? DateTimeRange(start: initialStart, end: initialEnd)
          : null,
    );
    if (!mounted || result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        season: '',
        dateRange: SearchDateRange(
          start: formatDateTime(result.start),
          end: formatDateTime(result.end),
        ),
      );
    });
  }

  Widget _buildScoreRangeSlider(SearchDoubleRange range) {
    final values = _safeRangeValues(range.min ?? 0, range.max ?? 10, 0, 10);
    return RangeSlider(
      values: values,
      min: 0,
      max: 10,
      divisions: 20,
      labels: RangeLabels(
        values.start.toStringAsFixed(1),
        values.end.toStringAsFixed(1),
      ),
      onChanged: (value) {
        setState(() {
          _draft = _draft.copyWith(
            scoreRange: SearchDoubleRange(min: value.start, max: value.end),
          );
        });
      },
    );
  }

  Widget _buildRankRangeSlider(SearchIntRange range) {
    final values = _safeRangeValues(
      (range.min ?? 1).toDouble(),
      (range.max ?? 10000).toDouble(),
      1,
      10000,
    );
    return RangeSlider(
      values: values,
      min: 1,
      max: 10000,
      divisions: 100,
      labels: RangeLabels('${values.start.round()}', '${values.end.round()}'),
      onChanged: (value) {
        setState(() {
          _draft = _draft.copyWith(
            rankRange: SearchIntRange(
              min: value.start.round(),
              max: value.end.round(),
            ),
          );
        });
      },
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
    // Keep labels inside the fill to avoid ExpansionTile clipping.
    border: UnderlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  void _apply() => widget.onApply(
    SearchFilterResult(
      filterState: _draft,
      notShowWatched: _notShowWatched,
      notShowAbandoned: _notShowAbandoned,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final keyboardInset = widget.showDragHandle
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final colors = Theme.of(context).colorScheme;
    final isPopover = !widget.showDragHandle;
    final dateSummary = _draft.season.isNotEmpty
        ? _draft.season
        : _draft.dateRange == null
        ? '不限日期'
        : '${_draft.dateRange!.start} 至 ${_draft.dateRange!.end}';
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortWindow =
              widget.showDragHandle &&
              keyboardInset > 0 &&
              constraints.maxHeight < 280;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!shortWindow)
                Padding(
                  padding: EdgeInsets.only(top: isPopover ? 14 : 0),
                  child: MaterialBottomSheetHeader(
                    title: '筛选番剧',
                    compact: isPopover,
                    onClose: widget.onClose,
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: isPopover
                      ? const EdgeInsets.fromLTRB(20, 4, 20, 12)
                      : const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  children: [
                    if (_draft.isIdSearch)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('当前按编号定位番剧'),
                        subtitle: const Text('清除编号后，可以组合其他条件查找。'),
                        trailing: TextButton(
                          onPressed: () =>
                              setState(() => _draft = _draft.copyWith(id: '')),
                          child: const Text('清除编号'),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sort-${_draft.sort}'),
                      initialValue: _draft.sort,
                      isExpanded: true,
                      decoration: _fieldDecoration('排序方式'),
                      items: [
                        for (final sort in searchSortLabels.entries)
                          DropdownMenuItem(
                            value: sort.key,
                            child: Text('按${sort.value}排序'),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(sort: value ?? 'heat'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchFilterGroup(
                      title: '题材标签',
                      summary: _draft.tags.isEmpty
                          ? '不限题材'
                          : _draft.tags.join('、'),
                      initiallyExpanded: _draft.tags.isNotEmpty,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final tag in {
                                ...defaultAnimeTags,
                                ..._draft.tags,
                              })
                                FilterChip(
                                  label: Text(tag),
                                  selected: _draft.tags.contains(tag),
                                  onSelected: (selected) => setState(
                                    () => _draft = _draft.copyWith(
                                      tags: selected
                                          ? [..._draft.tags, tag]
                                          : _draft.tags
                                                .where((item) => item != tag)
                                                .toList(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          // Separate scroll offsets from the expansion's boolean state.
                          key: const PageStorageKey('custom-tag-input'),
                          controller: _tagController,
                          textInputAction: TextInputAction.done,
                          decoration: _fieldDecoration('自定义标签').copyWith(
                            suffixIcon: IconButton(
                              tooltip: '添加标签',
                              onPressed: () => _addTag(_tagController.text),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ),
                          onSubmitted: _addTag,
                        ),
                      ],
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _SearchFilterGroup(
                      title: '放送时间',
                      summary:
                          '$dateSummary${_draft.weekdays.isNotEmpty ? ' · 已选 ${_draft.weekdays.length} 天' : ''}',
                      initiallyExpanded:
                          _draft.season.isNotEmpty ||
                          _draft.dateRange != null ||
                          _draft.weekdays.isNotEmpty,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey('season-${_draft.season}'),
                          initialValue: _draft.season,
                          isExpanded: true,
                          decoration: _fieldDecoration('放送季度'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('不限季度'),
                            ),
                            for (final season in _seasonOptions.entries)
                              DropdownMenuItem(
                                value: season.key,
                                child: Text(season.value),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _draft = _draft.copyWith(
                              season: value ?? '',
                              dateRange: null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _pickCustomDateRange,
                                icon: const Icon(Icons.date_range_outlined),
                                label: const Text('自定义日期'),
                              ),
                              if (_draft.dateRange != null ||
                                  _draft.season.isNotEmpty)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _draft = _draft.copyWith(
                                      season: '',
                                      dateRange: null,
                                    ),
                                  ),
                                  child: const Text('清除日期'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (var day = 1; day <= 7; day++)
                                FilterChip(
                                  label: Text('周${'一二三四五六日'[day - 1]}'),
                                  selected: _draft.weekdays.contains(day),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    final days = _draft.weekdays.toSet();
                                    selected ? days.add(day) : days.remove(day);
                                    setState(
                                      () => _draft = _draft.copyWith(
                                        weekdays: days.toList()..sort(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _SearchFilterGroup(
                      title: '评分与排名',
                      summary: [
                        if (_draft.scoreRange?.isValid == true)
                          '评分 ${_draft.scoreRange!.toToken()}',
                        if (_draft.rankRange?.isValid == true)
                          '排名 ${_draft.rankRange!.toToken()}',
                        if (_draft.scoreRange == null &&
                            _draft.rankRange == null)
                          '不限',
                      ].join(' · '),
                      initiallyExpanded:
                          _draft.scoreRange != null || _draft.rankRange != null,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('限定评分'),
                          value: _draft.scoreRange?.isValid == true,
                          onChanged: (value) => setState(
                            () => _draft = _draft.copyWith(
                              scoreRange: value
                                  ? const SearchDoubleRange(min: 7, max: 10)
                                  : null,
                            ),
                          ),
                        ),
                        if (_draft.scoreRange?.isValid == true) ...[
                          _buildScoreRangeSlider(_draft.scoreRange!),
                          Text('评分 ${_draft.scoreRange!.toToken()}'),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('限定排名'),
                          value: _draft.rankRange?.isValid == true,
                          onChanged: (value) => setState(
                            () => _draft = _draft.copyWith(
                              rankRange: value
                                  ? const SearchIntRange(min: 1, max: 5000)
                                  : null,
                            ),
                          ),
                        ),
                        if (_draft.rankRange?.isValid == true) ...[
                          _buildRankRangeSlider(_draft.rankRange!),
                          Text('排名 ${_draft.rankRange!.toToken()}'),
                        ],
                      ],
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _SearchFilterGroup(
                      title: '收藏状态',
                      summary: [
                        if (_notShowWatched) '隐藏已看',
                        if (_notShowAbandoned) '隐藏已弃',
                        if (!_notShowWatched && !_notShowAbandoned) '显示全部',
                      ].join(' · '),
                      initiallyExpanded: _notShowWatched || _notShowAbandoned,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('隐藏看过的番剧'),
                          value: _notShowWatched,
                          onChanged: (value) =>
                              setState(() => _notShowWatched = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('隐藏抛弃的番剧'),
                          value: _notShowAbandoned,
                          onChanged: (value) =>
                              setState(() => _notShowAbandoned = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!shortWindow)
                Padding(
                  padding: isPopover
                      ? const EdgeInsets.fromLTRB(20, 10, 20, 16)
                      : const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      TextButton(onPressed: _reset, child: const Text('重置')),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _apply,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(48, isPopover ? 44 : 56),
                          ),
                          child: const Text('查看结果'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchFilterGroup extends StatelessWidget {
  const _SearchFilterGroup({
    required this.title,
    required this.summary,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey(title),
    title: Text(title),
    subtitle: Text(summary),
    initiallyExpanded: initiallyExpanded,
    tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
    shape: const Border(),
    collapsedShape: const Border(),
    children: children,
  );
}

RangeValues _safeRangeValues(double start, double end, double min, double max) {
  final safeStart = start.clamp(min, max).toDouble();
  final safeEnd = end.clamp(min, max).toDouble();
  if (safeStart <= safeEnd) {
    return RangeValues(safeStart, safeEnd);
  }
  return RangeValues(safeEnd, safeStart);
}
