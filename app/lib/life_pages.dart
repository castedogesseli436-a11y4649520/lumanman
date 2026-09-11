import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'journal.dart';
import 'life_data.dart';

const _muted = Color(0xFF626B60);
const _green = Color(0xFF3F5F4C);
const _paper = Color(0xFFF6F4ED);

typedef SavePraise = Future<bool> Function(PraiseEntry? old, PraiseEntry next);
typedef SaveMoney = Future<bool> Function(MoneyEntry? old, MoneyEntry next);

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.journalEntries,
    required this.praiseEntries,
    required this.dailyCovers,
    required this.quotes,
    required this.loading,
    required this.onSavePraise,
    required this.onDeletePraise,
    required this.onChooseCover,
    required this.onWrite,
  });

  final List<JournalEntry> journalEntries;
  final List<PraiseEntry> praiseEntries;
  final List<DailyCover> dailyCovers;
  final List<DailyQuote> quotes;
  final bool loading;
  final SavePraise onSavePraise;
  final Future<bool> Function(PraiseEntry entry) onDeletePraise;
  final Future<void> Function(DateTime day) onChooseCover;
  final VoidCallback onWrite;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  bool _showPraise = false;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cover = latestCoverOnOrBefore(
      widget.dailyCovers,
      now,
      exists: (path) => File(path).existsSync(),
    );
    final legacyPhoto = cover == null
        ? latestPhotoOnOrBefore(
            widget.journalEntries,
            now,
            exists: (path) => File(path).existsSync(),
          )
        : null;
    final quote = widget.quotes.isEmpty
        ? null
        : quoteForDay(widget.quotes, now);
    final actionStyle = OutlinedButton.styleFrom(
      foregroundColor: _green,
      side: const BorderSide(color: Color(0x403F5F4C)),
      shape: const StadiumBorder(),
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: TextStyle(
        fontSize: 13,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      ),
    );
    return PopScope(
      canPop: !_showPraise,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showPraise) setState(() => _showPraise = false);
      },
      child: CustomScrollView(
        key: PageStorageKey(_showPraise ? 'praise-page' : 'today-page-v3'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
            sliver: SliverList.list(
              children: _showPraise
                  ? [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: const Key('close-praise'),
                          tooltip: '返回今天',
                          onPressed: () => setState(() => _showPraise = false),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      _PraiseWall(
                        entries: widget.praiseEntries,
                        day: now,
                        onAdd: () => _editPraise(context, null, now),
                        onEdit: (entry) => _editPraise(context, entry, now),
                        onDelete: (entry) => _deletePraise(context, entry),
                      ),
                    ]
                  : [
                      _TodayHeader(date: now),
                      const SizedBox(height: 8),
                      if (widget.loading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _MainPhoto(
                          photoPath: cover?.photoPath ?? legacyPhoto?.photoPath,
                          onChoose: () => widget.onChooseCover(now),
                        ),
                        const SizedBox(height: 22),
                        if (quote != null) _QuoteBlock(quote: quote),
                        const SizedBox(height: 34),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('quick-write'),
                                onPressed: widget.onWrite,
                                style: actionStyle,
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('记下'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('open-praise'),
                                onPressed: () =>
                                    setState(() => _showPraise = true),
                                style: actionStyle,
                                icon: const Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 17,
                                ),
                                label: const Text('夸夸墙'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPraise(
    BuildContext context,
    PraiseEntry? entry,
    DateTime today,
  ) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _paper,
      builder: (_) => _PraiseEditorSheet(entry: entry),
    );
    if (text == null || !context.mounted) return;
    final now = DateTime.now();
    await widget.onSavePraise(
      entry,
      PraiseEntry(
        id: entry?.id ?? now.microsecondsSinceEpoch.toString(),
        text: text,
        createdAt: entry?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _deletePraise(BuildContext context, PraiseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这句夸夸？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDeletePraise(entry);
  }
}

class _PraiseEditorSheet extends StatefulWidget {
  const _PraiseEditorSheet({this.entry});
  final PraiseEntry? entry;

  @override
  State<_PraiseEditorSheet> createState() => _PraiseEditorSheetState();
}

class _PraiseEditorSheetState extends State<_PraiseEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.entry?.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets_outlined, color: _green, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.entry == null ? '夸夸墙' : '修改夸夸',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('praise-text'),
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 7,
            maxLength: 300,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(hintText: '写下夸夸', filled: true),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const Key('save-praise'),
              onPressed: _submit,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.entries,
    required this.loading,
    required this.onSave,
    required this.onDelete,
  });

  final List<MoneyEntry> entries;
  final bool loading;
  final SaveMoney onSave;
  final Future<bool> Function(MoneyEntry entry) onDelete;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  MoneyKind _kind = MoneyKind.income;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = summarizeMonth(widget.entries, now);
    final visible = widget.entries.where((entry) {
      return entry.kind == _kind &&
          entry.occurredAt.year == now.year &&
          entry.occurredAt.month == now.month;
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return CustomScrollView(
      key: const PageStorageKey('ledger-page'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          sliver: SliverList.list(
            children: [
              _LedgerHeader(date: now),
              const SizedBox(height: 18),
              _MonthSummary(summary: summary),
              const SizedBox(height: 24),
              _KindSwitch(
                selected: _kind,
                onSelected: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 10),
              _SectionTitle(
                '${now.month}月${_kind.label}',
                action: FilledButton.icon(
                  key: const Key('add-money'),
                  onPressed: () => _edit(context, null),
                  icon: const Text(
                    '+',
                    style: TextStyle(fontSize: 20, height: 1),
                  ),
                  label: Text('记${_kind.label}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(102, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final entry in visible)
                  _MoneyRow(
                    entry: entry,
                    onEdit: () => _edit(context, entry),
                    onDelete: () => _delete(context, entry),
                  ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerRight,
                child: _PawTrail(key: Key('ledger-paw-trail')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, MoneyEntry? entry) async {
    final result = await showModalBottomSheet<MoneyEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _paper,
      builder: (_) =>
          _MoneyEditorSheet(kind: entry?.kind ?? _kind, entry: entry),
    );
    if (result != null) await widget.onSave(entry, result);
  }

  Future<void> _delete(BuildContext context, MoneyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除这笔${entry.kind.label}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(entry);
  }
}

class RecallPage extends StatefulWidget {
  const RecallPage({
    super.key,
    required this.journalEntries,
    required this.moneyEntries,
    required this.praiseEntries,
    required this.dailyCovers,
    required this.loading,
  });

  final List<JournalEntry> journalEntries;
  final List<MoneyEntry> moneyEntries;
  final List<PraiseEntry> praiseEntries;
  final List<DailyCover> dailyCovers;
  final bool loading;

  @override
  State<RecallPage> createState() => _RecallPageState();
}

class _RecallPageState extends State<RecallPage> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      _selected = DateTime(
        _month.year,
        _month.month,
        _selected.day.clamp(1, lastDay),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final journals = journalForDay(widget.journalEntries, _selected);
    final praises = praiseForDay(widget.praiseEntries, _selected);
    final money = moneyForDay(widget.moneyEntries, _selected);
    final income = money
        .where((entry) => entry.kind == MoneyKind.income)
        .fold(0, (sum, entry) => sum + entry.cents);
    final expense = money
        .where((entry) => entry.kind == MoneyKind.expense)
        .fold(0, (sum, entry) => sum + entry.cents);
    return CustomScrollView(
      key: const PageStorageKey('recall-page'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
          sliver: SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _RecallHeader(month: _month),
              ),
              const SizedBox(height: 12),
              _CalendarHeader(
                month: _month,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 43),
                child: Divider(height: 1),
              ),
              const _WeekHeader(),
              _MonthGrid(
                month: _month,
                selected: _selected,
                journals: widget.journalEntries,
                covers: widget.dailyCovers,
                onSelected: (day) => setState(() => _selected = day),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Column(
                    key: ValueKey(dayKey(_selected)),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _SectionTitle(
                              '${_selected.month}月${_selected.day}日',
                            ),
                          ),
                          Text(
                            '${journals.length + praises.length}条回忆',
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                      if (widget.loading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        const SizedBox(height: 10),
                        for (final entry in journals)
                          _RecallRow(
                            label: entry.mood.label,
                            text: entry.text,
                            color: entry.mood == Mood.happy
                                ? const Color(0xFFD97849)
                                : const Color(0xFFA3A89F),
                          ),
                        for (final praise in praises)
                          _RecallRow(
                            label: '夸夸',
                            text: praise.text,
                            color: _green,
                          ),
                        if (money.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const _SectionTitle('当日收支'),
                          _DailyMoney(income: income, expense: expense),
                        ],
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'assets/stickers/recall-cat-dog-exact.png',
                          key: const Key('recall-cat-dog'),
                          width: 140,
                          height: 112,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '路 慢 慢',
          style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 2),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${date.month}月${date.day}日',
              key: const Key('today-date'),
              style: const TextStyle(
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
            Text(
              weekdays[date.weekday - 1],
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecallHeader extends StatelessWidget {
  const _RecallHeader({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '路 慢 慢',
                style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 2),
              ),
              SizedBox(height: 8),
              Text(
                '回想',
                style: TextStyle(
                  fontSize: 34,
                  height: .94,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${month.year}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            const Text('慢慢走过', style: TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _MainPhoto extends StatelessWidget {
  const _MainPhoto({required this.photoPath, required this.onChoose});
  final String? photoPath;
  final VoidCallback onChoose;

  void _viewPhoto(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: _paper,
          appBar: AppBar(backgroundColor: _paper),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: Image.file(
                  File(photoPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = photoPath == null ? '选一张' : '换一张';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 83),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                key: const Key('today-photo-frame'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 36, 12, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF5),
                  border: Border.all(color: const Color(0x246F675A)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x105B5133),
                      blurRadius: 17,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Semantics(
                  button: true,
                  label: photoPath == null ? '选择首页照片' : '查看完整照片',
                  child: GestureDetector(
                    key: const Key('view-cover'),
                    onTap: photoPath == null
                        ? onChoose
                        : () => _viewPhoto(context),
                    child: Align(
                      alignment: Alignment.center,
                      heightFactor: 1,
                      child: photoPath == null
                          ? const SizedBox(
                              height: 217,
                              width: double.infinity,
                              child: ColoredBox(
                                color: Color(0xFFEAEDE6),
                                child: Icon(
                                  Icons.landscape_outlined,
                                  color: _muted,
                                  size: 44,
                                ),
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 350),
                              child: Image.file(
                                File(photoPath!),
                                key: const Key('today-photo-image'),
                                fit: BoxFit.contain,
                                cacheWidth: 1080,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -83,
                right: 2,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/stickers/today-cat-dog-exact.png',
                      key: const Key('today-cat-dog'),
                      width: 166,
                      fit: BoxFit.contain,
                      cacheWidth: 498,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: photoPath == null ? '选择首页照片' : '替换首页照片',
            child: TextButton(
              key: const Key('choose-cover'),
              onPressed: onChoose,
              style: TextButton.styleFrom(
                minimumSize: const Size(56, 44),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.quote});
  final DailyQuote quote;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '“',
          style: TextStyle(color: Color(0xFFD5794B), fontSize: 23, height: 1),
        ),
        const SizedBox(height: 5),
        Text(
          quote.text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.85,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -.2,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _DailyMoney extends StatelessWidget {
  const _DailyMoney({required this.income, required this.expense});
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: _MoneyNumber('收入', income)),
          Container(
            width: 1,
            height: 34,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(child: _MoneyNumber('支出', expense)),
          Container(
            width: 1,
            height: 34,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(child: _MoneyNumber('结余', income - expense)),
        ],
      ),
    );
  }
}

class _MoneyNumber extends StatelessWidget {
  const _MoneyNumber(this.label, this.cents);
  final String label;
  final int cents;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 5),
      FittedBox(
        child: Text(
          formatMoney(cents),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}

class _PraiseWall extends StatelessWidget {
  const _PraiseWall({
    required this.entries,
    required this.day,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PraiseEntry> entries;
  final DateTime day;
  final VoidCallback onAdd;
  final ValueChanged<PraiseEntry> onEdit;
  final ValueChanged<PraiseEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final ordered = [...entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final today =
        ordered.where((entry) => isSameDay(entry.createdAt, day)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = today.isEmpty ? null : today.first;
    final remaining = ordered.where((entry) => entry.id != first?.id).toList()
      ..sort((a, b) {
        final aDay = DateTime(
          a.createdAt.year,
          a.createdAt.month,
          a.createdAt.day,
        );
        final bDay = DateTime(
          b.createdAt.year,
          b.createdAt.month,
          b.createdAt.day,
        );
        final newestDayFirst = bDay.compareTo(aDay);
        return newestDayFirst != 0
            ? newestDayFirst
            : a.createdAt.compareTo(b.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                '夸夸墙',
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '今天',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '已经夸了 ${today.length} 次',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        _PraiseCompanion(
          entry: first,
          onEdit: first == null ? null : () => onEdit(first),
          onDelete: first == null ? null : () => onDelete(first),
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 22),
          for (var index = 0; index < remaining.length; index++)
            _PraiseNote(
              entry: remaining[index],
              day: day,
              index: index,
              onEdit: () => onEdit(remaining[index]),
              onDelete: () => onDelete(remaining[index]),
            ),
        ],
        const SizedBox(height: 38),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 84),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            key: const Key('add-praise'),
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF20261F),
              side: const BorderSide(color: Color(0xFF20261F)),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              '+ 贴一张夸夸',
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PraiseCompanion extends StatelessWidget {
  const _PraiseCompanion({this.entry, this.onEdit, this.onDelete});

  final PraiseEntry? entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width / 1.5;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/stickers/praise-wall-cat-dog-exact.png',
                key: const Key('praise-wall-cat-dog'),
                fit: BoxFit.contain,
                cacheWidth: 1000,
              ),
            ),
            if (entry != null)
              Positioned(
                left: width * .39,
                top: height * .59,
                width: width * .32,
                height: height * .34,
                child: Semantics(
                  key: const Key('primary-praise'),
                  button: true,
                  label: '编辑夸夸，长按删除',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      onLongPress: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(3, 4, 3, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                entry!.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.55,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _formatPraiseTime(entry!.createdAt),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PraiseNote extends StatelessWidget {
  const _PraiseNote({
    required this.entry,
    required this.day,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final PraiseEntry entry;
  final DateTime day;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFFE5EFEC), Color(0xFFFFFDF5)];
    const turns = [-0.012, 0.008];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 230),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Transform.rotate(
            angle: turns[index % turns.length] * value,
            child: child,
          ),
        ),
      ),
      child: Semantics(
        key: Key('praise-note-${entry.id}'),
        button: true,
        label: '编辑夸夸，长按删除',
        child: InkWell(
          onTap: onEdit,
          onLongPress: onDelete,
          child: Container(
            width: 270,
            constraints: const BoxConstraints(minHeight: 132),
            margin: const EdgeInsets.only(left: 26, bottom: 9),
            padding: const EdgeInsets.fromLTRB(17, 20, 17, 15),
            decoration: BoxDecoration(
              color: colors[index % colors.length],
              boxShadow: const [
                BoxShadow(
                  color: Color(0x143F5F4C),
                  blurRadius: 9,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _formatPraiseStamp(entry.createdAt, day),
                  style: const TextStyle(color: _muted, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatPraiseTime(DateTime time) {
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$period $hour:$minute';
}

String _formatPraiseStamp(DateTime time, DateTime day) => isSameDay(time, day)
    ? _formatPraiseTime(time)
    : '${time.month}月${time.day}日 · ${_formatPraiseTime(time)}';

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '路 慢 慢',
              style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 2),
            ),
            SizedBox(height: 8),
            Text(
              '收支',
              style: TextStyle(
                fontSize: 34,
                height: .94,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${date.month}月',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          const Text('本月', style: TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    ],
  );
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.summary});
  final MonthSummary summary;
  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(border: Border.all(color: divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '本月还剩',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
              _PawPrint(size: 22, color: Color(0x307BA286)),
            ],
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(summary.balanceCents),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 34,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LedgerAmount(label: '收入', cents: summary.incomeCents),
              ),
              Container(width: 1, height: 34, color: divider),
              const SizedBox(width: 16),
              Expanded(
                child: _LedgerAmount(label: '支出', cents: summary.expenseCents),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerAmount extends StatelessWidget {
  const _LedgerAmount({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatMoney(cents),
          maxLines: 1,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.selected, required this.onSelected});
  final MoneyKind selected;
  final ValueChanged<MoneyKind> onSelected;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          for (final kind in MoneyKind.values)
            Expanded(
              child: InkWell(
                key: Key('money-${kind.value}'),
                onTap: () => onSelected(kind),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        kind.label,
                        style: TextStyle(
                          fontWeight: selected == kind
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (selected == kind)
                        const Positioned(
                          bottom: 0,
                          child: ColoredBox(
                            color: Color(0xFFD97945),
                            child: SizedBox(width: 54, height: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });
  final MoneyEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onEdit,
    onLongPress: onDelete,
    child: Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '${entry.occurredAt.day}日',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              entry.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(entry.cents),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            padding: EdgeInsets.zero,
            icon: const Text(
              '•••',
              style: TextStyle(fontSize: 12, letterSpacing: 1),
            ),
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('修改')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PawTrail extends StatelessWidget {
  const _PawTrail({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    height: 58,
    child: Stack(
      children: [
        Positioned(
          right: 66,
          bottom: 3,
          child: Transform.rotate(
            angle: -.24,
            child: _PawPrint(size: 19, color: Color(0x247BA286)),
          ),
        ),
        Positioned(
          right: 34,
          bottom: 20,
          child: Transform.rotate(
            angle: .15,
            child: _PawPrint(size: 23, color: Color(0x307BA286)),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 36,
          child: Transform.rotate(
            angle: -.18,
            child: _PawPrint(size: 18, color: Color(0x247BA286)),
          ),
        ),
      ],
    ),
  );
}

class _PawPrint extends StatelessWidget {
  const _PawPrint({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PawPainter(color));
}

class _PawPainter extends CustomPainter {
  const _PawPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .5, size.height * .68),
        width: size.width * .58,
        height: size.height * .45,
      ),
      paint,
    );
    for (final toe in const [
      Offset(.2, .35),
      Offset(.4, .22),
      Offset(.6, .22),
      Offset(.8, .35),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * toe.dx, size.height * toe.dy),
          width: size.width * .2,
          height: size.height * .25,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PawPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MoneyEditorSheet extends StatefulWidget {
  const _MoneyEditorSheet({required this.kind, this.entry});
  final MoneyKind kind;
  final MoneyEntry? entry;
  @override
  State<_MoneyEditorSheet> createState() => _MoneyEditorSheetState();
}

class _MoneyEditorSheetState extends State<_MoneyEditorSheet> {
  late MoneyKind _kind;
  late String _category;
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  List<String> get _categories => _kind == MoneyKind.income
      ? const ['工资', '副业', '其他']
      : const ['餐饮', '交通', '购物', '居住', '其他'];

  @override
  void initState() {
    super.initState();
    _kind = widget.entry?.kind ?? widget.kind;
    _category = widget.entry?.category ?? _categories.first;
    _date = widget.entry?.occurredAt ?? DateTime.now();
    _amount = TextEditingController(
      text: widget.entry == null
          ? ''
          : (widget.entry!.cents / 100).toStringAsFixed(2),
    );
    _note = TextEditingController(text: widget.entry?.note);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _save() {
    final cents = parseMoneyToCents(_amount.text);
    if (cents == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入正确金额，最多两位小数')));
      return;
    }
    final now = DateTime.now();
    Navigator.pop(
      context,
      MoneyEntry(
        id: widget.entry?.id ?? now.microsecondsSinceEpoch.toString(),
        kind: _kind,
        category: _category,
        cents: cents,
        note: _note.text.trim(),
        occurredAt: DateTime(
          _date.year,
          _date.month,
          _date.day,
          now.hour,
          now.minute,
        ),
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.entry == null ? '记一笔${_kind.label}' : '修改这笔${_kind.label}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),
          SegmentedButton<MoneyKind>(
            segments: const [
              ButtonSegment(value: MoneyKind.income, label: Text('收入')),
              ButtonSegment(value: MoneyKind.expense, label: Text('支出')),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) => setState(() {
              _kind = selection.first;
              if (!_categories.contains(_category)) {
                _category = _categories.first;
              }
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('money-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: '金额（元）',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('money-category'),
            initialValue: _category,
            items: [
              for (final category in _categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => setState(() => _category = value!),
            decoration: const InputDecoration(
              labelText: '分类',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            subtitle: Text('${_date.year}年${_date.month}月${_date.day}日'),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: _chooseDate,
          ),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '备注（可以不写）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: const Key('previous-month'),
        tooltip: '上个月',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          '${month.month}月',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        key: const Key('next-month'),
        tooltip: '下个月',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final label in ['一', '二', '三', '四', '五', '六', '日'])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
        ),
    ],
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.journals,
    required this.covers,
    required this.onSelected,
  });
  final DateTime month;
  final DateTime selected;
  final List<JournalEntry> journals;
  final List<DailyCover> covers;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final offset = DateTime(month.year, month.month).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + count + 6) ~/ 7) * 7;
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 40,
      ),
      itemBuilder: (context, index) {
        final number = index - offset + 1;
        if (number < 1 || number > count) return const SizedBox.shrink();
        final day = DateTime(month.year, month.month, number);
        final entries = journalForDay(journals, day);
        final cover = coverForDay(
          covers,
          day,
          exists: (path) => File(path).existsSync(),
        );
        final photos = entries
            .where(
              (entry) =>
                  entry.photoPath != null &&
                  File(entry.photoPath!).existsSync(),
            )
            .toList();
        final photoPath = cover?.photoPath ?? photos.firstOrNull?.photoPath;
        return _DayCell(
          day: day,
          selected: isSameDay(day, selected),
          entries: entries,
          photoPath: photoPath,
          onTap: () => onSelected(day),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.entries,
    required this.photoPath,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final List<JournalEntry> entries;
  final String? photoPath;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final happy = entries.any((entry) => entry.mood == Mood.happy);
    final unhappy = entries.any((entry) => entry.mood == Mood.unhappy);
    return Semantics(
      label: '${day.year}年${day.month}月${day.day}日',
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('recall-day-${dayKey(day)}'),
        onTap: onTap,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: selected ? const Color(0x14D97849) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: selected ? const Color(0xFFD97849) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photoPath != null)
                  Image.file(
                    File(photoPath!),
                    fit: BoxFit.cover,
                    cacheWidth: 180,
                  ),
                if (photoPath == null)
                  Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  )
                else
                  Positioned(
                    top: 3,
                    left: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      color: photoPath == null
                          ? Colors.transparent
                          : _paper.withValues(alpha: .78),
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (photoPath == null && (happy || unhappy))
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (happy)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97849),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (unhappy)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFA3A89F),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecallRow extends StatelessWidget {
  const _RecallRow({
    required this.label,
    required this.text,
    required this.color,
  });
  final String label;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.6),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
