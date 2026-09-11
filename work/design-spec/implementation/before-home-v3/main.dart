import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'journal.dart';
import 'life_data.dart';
import 'life_pages.dart';

void main() => runApp(const LumanmanApp());

class LumanmanApp extends StatelessWidget {
  const LumanmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF20261F);
    const paper = Color(0xFFF6F4ED);
    const green = Color(0xFF3F5F4C);
    const softSurface = Color(0xFFF0F2EC);
    return MaterialApp(
      title: '路慢慢',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.light,
          surface: paper,
        ),
        textTheme: ThemeData.light().textTheme
            .apply(bodyColor: ink, displayColor: ink)
            .copyWith(
              bodyMedium: const TextStyle(fontSize: 14, height: 1.55),
              titleMedium: const TextStyle(fontWeight: FontWeight.w600),
            ),
        dividerColor: ink.withValues(alpha: 0.14),
        splashColor: green.withValues(alpha: 0.08),
        highlightColor: green.withValues(alpha: 0.04),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: softSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ink.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ink.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: paper,
            minimumSize: const Size(44, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: green,
            minimumSize: const Size(44, 44),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: green,
            minimumSize: const Size(44, 44),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: const TextStyle(color: paper),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: paper,
          modalBackgroundColor: paper,
          showDragHandle: true,
        ),
      ),
      home: const JournalPage(),
    );
  }
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const _muted = Color(0xFF626B60);

  final _entries = <JournalEntry>[];
  final _moneyEntries = <MoneyEntry>[];
  final _praiseEntries = <PraiseEntry>[];
  final _dailyCovers = <DailyCover>[];
  List<DailyQuote> _quotes = const [];
  Mood _mood = Mood.happy;
  int _currentTab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var failed = false;
    try {
      final loaded = await loadEntries();
      _entries.addAll(loaded);
    } catch (_) {
      failed = true;
    }
    try {
      _moneyEntries.addAll(await loadMoneyEntries());
    } catch (_) {
      failed = true;
    }
    try {
      _praiseEntries.addAll(await loadPraiseEntries());
    } catch (_) {
      failed = true;
    }
    try {
      _dailyCovers.addAll(await loadDailyCovers());
    } catch (_) {
      failed = true;
    }
    try {
      _quotes = parseQuotes(
        await rootBundle.loadString('assets/quotes/curated-quotes.txt'),
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMessage('部分本机内容读取失败，原数据没有被改动');
      });
    }
  }

  Future<bool> _persist(List<JournalEntry> next) async {
    try {
      await saveEntries(next);
      if (!mounted) return false;
      setState(() {
        _entries
          ..clear()
          ..addAll(next);
      });
      return true;
    } catch (_) {
      if (mounted) _showMessage('没有保存成功，请稍后再试');
      return false;
    }
  }

  Future<bool> _persistMoney(List<MoneyEntry> next) async {
    try {
      await saveMoneyEntries(next);
      if (!mounted) return false;
      setState(() {
        _moneyEntries
          ..clear()
          ..addAll(next);
      });
      return true;
    } catch (_) {
      if (mounted) _showMessage('收支没有保存成功，请稍后再试');
      return false;
    }
  }

  Future<bool> _persistPraise(List<PraiseEntry> next) async {
    try {
      await savePraiseEntries(next);
      if (!mounted) return false;
      setState(() {
        _praiseEntries
          ..clear()
          ..addAll(next);
      });
      return true;
    } catch (_) {
      if (mounted) _showMessage('夸夸没有保存成功，请稍后再试');
      return false;
    }
  }

  Future<bool> _persistCovers(List<DailyCover> next) async {
    try {
      await saveDailyCovers(next);
      if (!mounted) return false;
      setState(() {
        _dailyCovers
          ..clear()
          ..addAll(next);
      });
      return true;
    } catch (_) {
      if (mounted) _showMessage('照片没有保存成功，请稍后再试');
      return false;
    }
  }

  Future<void> _chooseDailyCover(DateTime day) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (picked == null) return;
    final key = dayKey(day);
    final old = coverForDay(_dailyCovers, day);
    String? imported;
    try {
      imported = await importCoverPhoto(picked.path, key);
    } catch (_) {
      if (mounted) _showMessage('照片没有保存成功，请重新选择');
      return;
    }
    final next = upsertDailyCover(
      _dailyCovers,
      DailyCover(dateKey: key, photoPath: imported, updatedAt: DateTime.now()),
    );
    final saved = await _persistCovers(next);
    if (!saved) {
      try {
        await deleteCoverPhoto(imported);
      } catch (_) {}
      return;
    }
    if (old != null && old.photoPath != imported) {
      try {
        await deleteCoverPhoto(old.photoPath);
      } catch (_) {
        if (mounted) _showMessage('新照片已保存，旧文件稍后会自动清理');
      }
    }
  }

  Future<bool> _saveMoney(MoneyEntry? old, MoneyEntry nextEntry) async {
    final next = [..._moneyEntries];
    if (old == null) {
      next.add(nextEntry);
    } else {
      final index = next.indexWhere((entry) => entry.id == old.id);
      if (index == -1) return Future.value(false);
      next[index] = nextEntry;
    }
    final saved = await _persistMoney(next);
    if (saved && mounted) {
      HapticFeedback.lightImpact();
      _showMessage(old == null ? '已记下' : '已保存');
    }
    return saved;
  }

  Future<bool> _deleteMoney(MoneyEntry entry) => _persistMoney(
    _moneyEntries.where((item) => item.id != entry.id).toList(),
  );

  Future<bool> _savePraise(PraiseEntry? old, PraiseEntry nextEntry) async {
    final next = [..._praiseEntries];
    if (old == null) {
      next.add(nextEntry);
    } else {
      final index = next.indexWhere((entry) => entry.id == old.id);
      if (index == -1) return Future.value(false);
      next[index] = nextEntry;
    }
    final saved = await _persistPraise(next);
    if (saved && mounted) {
      HapticFeedback.lightImpact();
      _showMessage(old == null ? '已贴上夸夸墙' : '已保存');
    }
    return saved;
  }

  Future<bool> _deletePraise(PraiseEntry entry) => _persistPraise(
    _praiseEntries.where((item) => item.id != entry.id).toList(),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit([JournalEntry? entry]) async {
    final mood = entry?.mood ?? _mood;
    final draft = await showModalBottomSheet<JournalDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF6F4ED),
      builder: (_) => _EditorSheet(mood: mood, entry: entry),
    );
    if (draft == null) return;

    final now = DateTime.now();
    final recordId = entry?.id ?? now.microsecondsSinceEpoch.toString();
    String? importedPhoto;
    if (draft.photoChanged && draft.photoSourcePath != null) {
      try {
        importedPhoto = await importPhoto(draft.photoSourcePath!, recordId);
      } catch (_) {
        if (mounted) _showMessage('照片没有保存成功，请重新选择');
        return;
      }
    }
    final nextPhoto = draft.photoChanged ? importedPhoto : entry?.photoPath;
    final next = [..._entries];
    if (entry == null) {
      next.add(
        JournalEntry(
          id: recordId,
          mood: mood,
          text: draft.text,
          followUp: draft.followUp,
          createdAt: now,
          updatedAt: now,
          photoPath: nextPhoto,
        ),
      );
    } else {
      final index = next.indexWhere((item) => item.id == entry.id);
      if (index == -1) {
        if (importedPhoto != null) await deletePrivatePhoto(importedPhoto);
        return;
      }
      next[index] = JournalEntry(
        id: entry.id,
        mood: entry.mood,
        text: draft.text,
        followUp: draft.followUp,
        createdAt: entry.createdAt,
        updatedAt: now,
        photoPath: nextPhoto,
      );
    }
    final saved = await _persist(next);
    if (!saved && importedPhoto != null) {
      try {
        await deletePrivatePhoto(importedPhoto);
      } catch (_) {
        if (mounted) _showMessage('没有保存成功，临时照片也未能清理');
      }
      return;
    }
    if (saved && draft.photoChanged && entry?.photoPath != null) {
      try {
        await deletePrivatePhoto(entry!.photoPath);
      } catch (_) {
        if (mounted) _showMessage('记录已保存，旧照片暂时没有清理');
      }
    }
    if (saved && mounted) {
      HapticFeedback.lightImpact();
      _showMessage(entry == null ? '已记下' : '已保存');
    }
  }

  Future<void> _delete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后无法恢复。'),
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
    if (confirmed == true) {
      final saved = await _persist(
        _entries.where((item) => item.id != entry.id).toList(),
      );
      if (saved) {
        try {
          await deletePrivatePhoto(entry.photoPath);
        } catch (_) {
          if (mounted) _showMessage('记录已删除，照片暂时没有清理');
        }
      }
    }
  }

  void _selectMood(Mood mood) {
    if (_mood == mood) return;
    HapticFeedback.selectionClick();
    setState(() => _mood = mood);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = entriesForMood(_entries, _mood);
    final todayHappy = _entries
        .where(
          (entry) =>
              entry.mood == Mood.happy && isSameDay(entry.createdAt, now),
        )
        .length;
    final todayUnhappy = _entries
        .where(
          (entry) =>
              entry.mood == Mood.unhappy && isSameDay(entry.createdAt, now),
        )
        .length;

    final content = switch (_currentTab) {
      0 => TodayPage(
        journalEntries: _entries,
        moneyEntries: _moneyEntries,
        praiseEntries: _praiseEntries,
        dailyCovers: _dailyCovers,
        quotes: _quotes,
        loading: _loading,
        onSavePraise: _savePraise,
        onDeletePraise: _deletePraise,
        onChooseCover: _chooseDailyCover,
        onWrite: () => setState(() => _currentTab = 3),
      ),
      1 => LedgerPage(
        entries: _moneyEntries,
        loading: _loading,
        onSave: _saveMoney,
        onDelete: _deleteMoney,
      ),
      2 => RecallPage(
        journalEntries: _entries,
        moneyEntries: _moneyEntries,
        praiseEntries: _praiseEntries,
        dailyCovers: _dailyCovers,
        loading: _loading,
      ),
      _ => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(now)),
          SliverToBoxAdapter(
            child: _MoodTabs(
              selected: _mood,
              happyCount: todayHappy,
              unhappyCount: todayUnhappy,
              onSelected: _selectMood,
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyMood(mood: _mood),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 25, 22, 28),
              sliver: SliverList.list(children: _buildDays(visible)),
            ),
        ],
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: CustomPaint(
          painter: const _PaperPainter(),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: KeyedSubtree(
                    key: ValueKey(_currentTab),
                    child: content,
                  ),
                ),
              ),
              if (_currentTab == 3)
                _ActionBar(mood: _mood, onAdd: () => _edit()),
              _BottomNav(
                selected: _currentTab,
                onSelected: (index) => setState(() => _currentTab = index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(DateTime now) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '路慢慢',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  '记下',
                  style: TextStyle(
                    fontSize: 30,
                    height: 0.94,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${now.month}月${now.day}日\n${weekdays[now.weekday - 1]}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDays(List<JournalEntry> entries) {
    final grouped = <DateTime, List<JournalEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (var index = 0; index < days.length; index++) ...[
        if (index > 0) const SizedBox(height: 27),
        _DaySection(
          day: days[index],
          entries: grouped[days[index]]!,
          mood: _mood,
          onEdit: _edit,
          onDelete: _delete,
        ),
      ],
    ];
  }
}

class _MoodTabs extends StatelessWidget {
  const _MoodTabs({
    required this.selected,
    required this.happyCount,
    required this.unhappyCount,
    required this.onSelected,
  });

  final Mood selected;
  final int happyCount;
  final int unhappyCount;
  final ValueChanged<Mood> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MoodTab(
              key: const Key('happy-tab'),
              mood: Mood.happy,
              selected: selected == Mood.happy,
              count: happyCount,
              onTap: onSelected,
            ),
          ),
          Container(
            width: 1,
            height: 92,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _MoodTab(
              key: const Key('unhappy-tab'),
              mood: Mood.unhappy,
              selected: selected == Mood.unhappy,
              count: unhappyCount,
              onTap: onSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodTab extends StatelessWidget {
  const _MoodTab({
    super.key,
    required this.mood,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final int count;
  final ValueChanged<Mood> onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final asset = mood == Mood.happy
        ? 'assets/stickers/happy-dog.png'
        : 'assets/stickers/unhappy-cat.png';
    return Semantics(
      selected: selected,
      button: true,
      label: '${mood.label}，今天$count条',
      child: InkWell(
        onTap: () => onTap(mood),
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: selected ? const Color(0x173F5F4C) : Colors.transparent,
          child: Row(
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0.86,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0.5,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Image.asset(
                    asset,
                    width: 58,
                    height: 58,
                    cacheWidth: 180,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '今天 $count 条',
                      style: const TextStyle(
                        color: Color(0xFF626B60),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    required this.mood,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime day;
  final List<JournalEntry> entries;
  final Mood mood;
  final ValueChanged<JournalEntry> onEdit;
  final ValueChanged<JournalEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final title = isSameDay(day, now)
        ? '今天'
        : isSameDay(day, yesterday)
        ? '昨天'
        : '${day.month}月${day.day}日';
    final asset = mood == Mood.happy
        ? 'assets/stickers/happy-dog.png'
        : 'assets/stickers/unhappy-cat.png';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${day.month}月${day.day}日 · ${entries.length}条',
              style: const TextStyle(color: Color(0xFF626B60), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (final entry in entries)
          InkWell(
            onTap: () => onEdit(entry),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 45,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _timeOfDay(entry.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF626B60),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.text,
                          style: const TextStyle(fontSize: 14, height: 1.7),
                        ),
                        if (entry.followUp.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            entry.followUp,
                            style: const TextStyle(
                              color: Color(0xFF626B60),
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                        ],
                        if (entry.photoPath != null &&
                            File(entry.photoPath!).existsSync()) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.file(
                                File(entry.photoPath!),
                                fit: BoxFit.cover,
                                cacheWidth: 720,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    children: [
                      Image.asset(
                        asset,
                        width: 42,
                        height: 42,
                        cacheWidth: 126,
                      ),
                      SizedBox(
                        width: 38,
                        height: 34,
                        child: PopupMenuButton<String>(
                          tooltip: '记录操作',
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: Color(0xFF626B60),
                          ),
                          onSelected: (value) =>
                              value == 'edit' ? onEdit(entry) : onDelete(entry),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('修改')),
                            PopupMenuItem(value: 'delete', child: Text('删除')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _timeOfDay(DateTime time) => switch (time.hour) {
    < 6 => '凌晨',
    < 9 => '早上',
    < 12 => '上午',
    < 14 => '中午',
    < 18 => '下午',
    < 22 => '晚上',
    _ => '夜里',
  };
}

class _EmptyMood extends StatelessWidget {
  const _EmptyMood({required this.mood});

  final Mood mood;

  @override
  Widget build(BuildContext context) {
    final asset = mood == Mood.happy
        ? 'assets/stickers/happy-dog.png'
        : 'assets/stickers/unhappy-cat.png';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.72,
              child: Image.asset(asset, width: 86, height: 86, cacheWidth: 220),
            ),
            const SizedBox(height: 14),
            Text(
              '还没有${mood.label}记录',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.mood, required this.onAdd});

  final Mood mood;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4ED).withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('add-entry'),
          onPressed: onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3F5F4C),
            foregroundColor: const Color(0xFFF3F6F1),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('记一条${mood.label}'),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4ED).withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < 4; index++)
            _NavItem(
              const ['今天', '收支', '回想', '记下'][index],
              active: selected == index,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.label, {this.active = false, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        key: Key('nav-$label'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active
                    ? const Color(0xFF20261F)
                    : const Color(0xFF626B60),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              width: active ? 22 : 4,
              height: 2,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFD5794B) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({required this.mood, this.entry});

  final Mood mood;
  final JournalEntry? entry;

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final TextEditingController _text;
  late final TextEditingController _followUp;
  final _picker = ImagePicker();
  final _speech = SpeechToText();
  String? _photoPath;
  bool _photoChanged = false;
  bool _listening = false;
  String _speechBase = '';

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.entry?.text);
    _followUp = TextEditingController(text: widget.entry?.followUp);
    _photoPath = widget.entry?.photoPath;
  }

  @override
  void dispose() {
    if (_listening) _speech.cancel();
    _text.dispose();
    _followUp.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先写下一点内容')));
      return;
    }
    Navigator.pop(
      context,
      JournalDraft(
        text: text,
        followUp: _followUp.text.trim(),
        photoChanged: _photoChanged,
        photoSourcePath: _photoPath,
      ),
    );
  }

  void _sheetMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photoPath = picked.path;
        _photoChanged = true;
      });
    } on PlatformException {
      if (mounted) _sheetMessage('无法打开系统相册，请稍后再试');
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
      _photoChanged = true;
    });
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == SpeechToText.listeningStatus);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
          final message = error.errorMsg.contains('permission')
              ? '没有麦克风权限，请在系统设置中允许后重试'
              : error.errorMsg.contains('no_match') ||
                    error.errorMsg.contains('speech_timeout')
              ? '没有听清，可以再试一次'
              : '语音识别暂时不可用';
          _sheetMessage(message);
        },
      );
      if (!available) {
        final allowed = await _speech.hasPermission;
        if (mounted) {
          _sheetMessage(allowed ? '这台设备没有可用的语音识别服务' : '没有麦克风权限，请在系统设置中允许后重试');
        }
        return;
      }
      _speechBase = _text.text;
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          final merged = mergeSpeechText(_speechBase, result.recognizedWords);
          _text.value = TextEditingValue(
            text: merged,
            selection: TextSelection.collapsed(offset: merged.length),
          );
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } on PlatformException {
      if (mounted) {
        setState(() => _listening = false);
        _sheetMessage('语音识别暂时不可用');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final asset = widget.mood == Mood.happy
        ? 'assets/stickers/happy-dog.png'
        : 'assets/stickers/unhappy-cat.png';
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 14, 22, 22 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x3320261F),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Image.asset(asset, width: 58, height: 58, cacheWidth: 180),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry == null
                          ? '记一条${widget.mood.label}'
                          : '修改这条${widget.mood.label}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.mood == Mood.happy
                          ? '这一刻，什么让你觉得很好？'
                          : '慢慢写，不必急着解决它。',
                      style: const TextStyle(
                        color: Color(0xFF626B60),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('entry-text'),
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: _listening ? '正在听…点一下停止' : '写下此刻',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                key: const Key('speech-input'),
                tooltip: _listening ? '停止语音输入' : '语音转文字',
                onPressed: _toggleSpeech,
                icon: Icon(
                  _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                ),
                color: const Color(0xFF3F5F4C),
              ),
            ),
          ),
          if (_photoPath != null && File(_photoPath!).existsSync()) ...[
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(_photoPath!),
                  fit: BoxFit.cover,
                  cacheWidth: 960,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('pick-photo'),
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_outlined, size: 19),
                label: Text(_photoPath == null ? '放一张照片' : '换一张照片'),
              ),
              if (_photoPath != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: _removePhoto, child: const Text('移除')),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('entry-follow-up'),
            controller: _followUp,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '后面的思考（可以不写）',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('save-entry'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3F5F4C),
              ),
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3F5F4C).withValues(alpha: 0.014)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
