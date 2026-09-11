import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal.dart';

enum MoneyKind { income, expense }

extension MoneyKindText on MoneyKind {
  String get value => this == MoneyKind.income ? 'income' : 'expense';

  String get label => this == MoneyKind.income ? '收入' : '支出';

  static MoneyKind parse(String value) => switch (value) {
    'income' => MoneyKind.income,
    'expense' => MoneyKind.expense,
    _ => throw FormatException('未知收支类型：$value'),
  };
}

class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.kind,
    required this.category,
    required this.cents,
    required this.note,
    required this.occurredAt,
    required this.updatedAt,
  });

  final String id;
  final MoneyKind kind;
  final String category;
  final int cents;
  final String note;
  final DateTime occurredAt;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.value,
    'category': category,
    'cents': cents,
    'note': note,
    'occurredAt': occurredAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MoneyEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kind = json['kind'];
    final category = json['category'];
    final cents = json['cents'];
    final note = json['note'];
    final occurredAt = json['occurredAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String ||
        id.isEmpty ||
        kind is! String ||
        category is! String ||
        category.isEmpty ||
        cents is! int ||
        cents <= 0 ||
        note is! String ||
        occurredAt is! String ||
        updatedAt is! String) {
      throw const FormatException('收支字段不完整');
    }
    return MoneyEntry(
      id: id,
      kind: MoneyKindText.parse(kind),
      category: category,
      cents: cents,
      note: note,
      occurredAt: DateTime.parse(occurredAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

class PraiseEntry {
  const PraiseEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PraiseEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final text = json['text'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String ||
        id.isEmpty ||
        text is! String ||
        text.trim().isEmpty ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('夸夸字段不完整');
    }
    return PraiseEntry(
      id: id,
      text: text,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

class MonthSummary {
  const MonthSummary(this.incomeCents, this.expenseCents);

  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;
}

class DailyQuote {
  const DailyQuote(this.text, this.source);

  final String text;
  final String source;
}

String displayQuoteSource(String value) {
  var source = value.trim();
  const providedSuffix =
      '（用户'
      '提供）';
  if (source.endsWith(providedSuffix)) {
    source = source.substring(0, source.length - providedSuffix.length).trim();
  }
  if (source.startsWith('用户') &&
      (source.contains('截图') || source.contains('摘录'))) {
    return '';
  }
  return source;
}

class DailyCover {
  const DailyCover({
    required this.dateKey,
    required this.photoPath,
    required this.updatedAt,
  });

  final String dateKey;
  final String photoPath;
  final DateTime updatedAt;

  DateTime get day => DateTime.parse(dateKey);

  Map<String, Object> toJson() => {
    'dateKey': dateKey,
    'photoPath': photoPath,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DailyCover.fromJson(Map<String, Object?> json) {
    final dateKey = json['dateKey'];
    final photoPath = json['photoPath'];
    final updatedAt = json['updatedAt'];
    if (dateKey is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey) ||
        photoPath is! String ||
        photoPath.isEmpty ||
        updatedAt is! String) {
      throw const FormatException('每日封面字段不完整');
    }
    final day = DateTime.tryParse(dateKey);
    if (day == null || dayKey(day) != dateKey) {
      throw const FormatException('每日封面日期无效');
    }
    return DailyCover(
      dateKey: dateKey,
      photoPath: photoPath,
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DailyCover? coverForDay(
  Iterable<DailyCover> covers,
  DateTime day, {
  bool Function(String path)? exists,
}) {
  final key = dayKey(day);
  for (final cover in covers) {
    if (cover.dateKey == key && (exists == null || exists(cover.photoPath))) {
      return cover;
    }
  }
  return null;
}

DailyCover? latestCoverOnOrBefore(
  Iterable<DailyCover> covers,
  DateTime day, {
  bool Function(String path)? exists,
}) {
  final key = dayKey(day);
  final candidates =
      covers
          .where(
            (cover) =>
                cover.dateKey.compareTo(key) <= 0 &&
                (exists == null || exists(cover.photoPath)),
          )
          .toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  return candidates.isEmpty ? null : candidates.first;
}

List<DailyCover> upsertDailyCover(
  Iterable<DailyCover> covers,
  DailyCover next,
) => [
  for (final cover in covers)
    if (cover.dateKey != next.dateKey) cover,
  next,
];

List<DailyCover> removeDailyCover(Iterable<DailyCover> covers, DateTime day) {
  final key = dayKey(day);
  return covers.where((cover) => cover.dateKey != key).toList();
}

List<DailyQuote> parseQuotes(String source) {
  final pattern = RegExp(r"\['((?:\\'|[^'])*)','((?:\\'|[^'])*)'\]");
  final seen = <String>{};
  final quotes = <DailyQuote>[];
  for (final match in pattern.allMatches(source)) {
    final text = match.group(1)!.replaceAll(r"\'", "'");
    if (!seen.add(text)) continue;
    quotes.add(DailyQuote(text, match.group(2)!.replaceAll(r"\'", "'")));
  }
  return quotes;
}

DailyQuote quoteForDay(List<DailyQuote> quotes, DateTime day) {
  if (quotes.isEmpty) throw StateError('名言列表为空');
  final schedule = buildQuoteSchedule(quotes);
  final date = DateTime(day.year, day.month, day.day);
  final index = date.difference(DateTime(2026)).inDays % schedule.length;
  return schedule[index < 0 ? index + schedule.length : index];
}

List<DailyQuote> buildQuoteSchedule(List<DailyQuote> quotes) {
  final personal = quotes.where((quote) => quote.source == '傻子').toList();
  final ordinary = _stableShuffle(
    quotes.where((quote) => quote.source != '傻子').toList(),
  );
  if (personal.isEmpty) return ordinary;

  final schedule = <DailyQuote>[];
  var personalIndex = 0;
  var ordinaryIndex = 0;
  for (var slot = 0; slot < quotes.length; slot++) {
    final expectedPersonal = ((slot + 1) * personal.length) ~/ quotes.length;
    if (expectedPersonal > personalIndex) {
      schedule.add(personal[personalIndex++]);
    } else {
      schedule.add(ordinary[ordinaryIndex++]);
    }
  }
  return schedule;
}

List<DailyQuote> _stableShuffle(List<DailyQuote> source) {
  final result = [...source];
  var state = 0x13579BDF;
  for (var index = result.length - 1; index > 0; index--) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    final swapIndex = state % (index + 1);
    final value = result[index];
    result[index] = result[swapIndex];
    result[swapIndex] = value;
  }
  return result;
}

MonthSummary summarizeMonth(Iterable<MoneyEntry> entries, DateTime month) {
  var income = 0;
  var expense = 0;
  for (final entry in entries) {
    if (entry.occurredAt.year != month.year ||
        entry.occurredAt.month != month.month) {
      continue;
    }
    if (entry.kind == MoneyKind.income) {
      income += entry.cents;
    } else {
      expense += entry.cents;
    }
  }
  return MonthSummary(income, expense);
}

List<MoneyEntry> moneyForDay(Iterable<MoneyEntry> entries, DateTime day) =>
    entries.where((entry) => isSameDay(entry.occurredAt, day)).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

List<PraiseEntry> praiseForDay(Iterable<PraiseEntry> entries, DateTime day) =>
    entries.where((entry) => isSameDay(entry.createdAt, day)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

List<JournalEntry> journalForDay(
  Iterable<JournalEntry> entries,
  DateTime day,
) =>
    entries.where((entry) => isSameDay(entry.createdAt, day)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

JournalEntry? latestPhotoOnOrBefore(
  Iterable<JournalEntry> entries,
  DateTime day, {
  bool Function(String path)? exists,
}) {
  final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999, 999);
  final candidates =
      entries
          .where(
            (entry) =>
                entry.photoPath != null &&
                !entry.createdAt.isAfter(end) &&
                (exists == null || exists(entry.photoPath!)),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return candidates.isEmpty ? null : candidates.first;
}

String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  return '$sign¥${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
}

int? parseMoneyToCents(String source) {
  final normalized = source.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.parse(parts.first);
  final decimal = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  final cents = whole * 100 + decimal;
  return cents > 0 ? cents : null;
}

String _encodeList(Iterable<Map<String, Object>> items) =>
    jsonEncode({'version': 1, 'entries': items.toList()});

List<Object?> _decodeList(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, Object?> ||
      root['version'] != 1 ||
      root['entries'] is! List<Object?>) {
    throw const FormatException('不支持的本机数据格式');
  }
  return root['entries'] as List<Object?>;
}

const _moneyKey = 'money_v1';
const _praiseKey = 'praise_v1';
const _coversKey = 'daily_covers_v1';

Future<List<MoneyEntry>> loadMoneyEntries() async {
  final source = (await SharedPreferences.getInstance()).getString(_moneyKey);
  if (source == null) return [];
  return _decodeList(source).map((item) {
    if (item is! Map<String, Object?>) throw const FormatException('收支格式错误');
    return MoneyEntry.fromJson(item);
  }).toList();
}

Future<void> saveMoneyEntries(Iterable<MoneyEntry> entries) async {
  final saved = await (await SharedPreferences.getInstance()).setString(
    _moneyKey,
    _encodeList(entries.map((entry) => entry.toJson())),
  );
  if (!saved) throw StateError('收支未能写入本机');
}

Future<List<PraiseEntry>> loadPraiseEntries() async {
  final source = (await SharedPreferences.getInstance()).getString(_praiseKey);
  if (source == null) return [];
  return _decodeList(source).map((item) {
    if (item is! Map<String, Object?>) throw const FormatException('夸夸格式错误');
    return PraiseEntry.fromJson(item);
  }).toList();
}

Future<void> savePraiseEntries(Iterable<PraiseEntry> entries) async {
  final saved = await (await SharedPreferences.getInstance()).setString(
    _praiseKey,
    _encodeList(entries.map((entry) => entry.toJson())),
  );
  if (!saved) throw StateError('夸夸未能写入本机');
}

Future<List<DailyCover>> loadDailyCovers() async {
  final source = (await SharedPreferences.getInstance()).getString(_coversKey);
  if (source == null) return [];
  return _decodeList(source).map((item) {
    if (item is! Map<String, Object?>) throw const FormatException('每日封面格式错误');
    return DailyCover.fromJson(item);
  }).toList();
}

Future<void> saveDailyCovers(Iterable<DailyCover> covers) async {
  final saved = await (await SharedPreferences.getInstance()).setString(
    _coversKey,
    _encodeList(covers.map((cover) => cover.toJson())),
  );
  if (!saved) throw StateError('每日封面未能写入本机');
}

Future<Directory> _coverDirectory([Directory? baseDirectory]) async {
  final base = baseDirectory ?? await getApplicationDocumentsDirectory();
  final directory = Directory(
    '${base.path}${Platform.pathSeparator}cover_photos',
  );
  await directory.create(recursive: true);
  return directory;
}

Future<String> importCoverPhoto(
  String sourcePath,
  String dateKey, {
  Directory? baseDirectory,
  DateTime? now,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) throw const FileSystemException('照片文件不存在');
  final directory = await _coverDirectory(baseDirectory);
  final rawExtension = sourcePath.split('.').last.toLowerCase();
  final extension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(rawExtension)
      ? '.$rawExtension'
      : '.jpg';
  final timestamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  final target = File(
    '${directory.path}${Platform.pathSeparator}${dateKey}_$timestamp$extension',
  );
  final temporary = File('${target.path}.tmp');
  try {
    await source.copy(temporary.path);
    return (await temporary.rename(target.path)).path;
  } catch (_) {
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

Future<void> deleteCoverPhoto(
  String? photoPath, {
  Directory? baseDirectory,
}) async {
  if (photoPath == null) return;
  final file = File(photoPath);
  if (!await file.exists()) return;
  final directory = await _coverDirectory(baseDirectory);
  final root = await directory.resolveSymbolicLinks();
  final candidate = await file.resolveSymbolicLinks();
  final separator = Platform.pathSeparator;
  final rootPrefix =
      '${Platform.isWindows ? root.toLowerCase() : root}$separator';
  final compared = Platform.isWindows ? candidate.toLowerCase() : candidate;
  if (!compared.startsWith(rootPrefix)) {
    throw const FileSystemException('拒绝删除 App 私有目录之外的文件');
  }
  await file.delete();
}
