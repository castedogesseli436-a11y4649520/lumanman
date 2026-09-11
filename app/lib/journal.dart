import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Mood { happy, unhappy }

extension MoodText on Mood {
  String get value => this == Mood.happy ? 'happy' : 'unhappy';

  String get label => this == Mood.happy ? '开心' : '不开心';

  static Mood parse(String value) => switch (value) {
    'happy' => Mood.happy,
    'unhappy' => Mood.unhappy,
    _ => throw FormatException('未知心情类型：$value'),
  };
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.mood,
    required this.text,
    required this.followUp,
    required this.createdAt,
    required this.updatedAt,
    this.photoPath,
  });

  final String id;
  final Mood mood;
  final String text;
  final String followUp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoPath;

  JournalEntry copyWith({String? text, String? followUp, DateTime? updatedAt}) {
    return JournalEntry(
      id: id,
      mood: mood,
      text: text ?? this.text,
      followUp: followUp ?? this.followUp,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoPath: photoPath,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'id': id,
      'mood': mood.value,
      'text': text,
      'followUp': followUp,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (photoPath != null) json['photoPath'] = photoPath!;
    return json;
  }

  factory JournalEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final mood = json['mood'];
    final text = json['text'];
    final followUp = json['followUp'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final photoPath = json['photoPath'];
    if (id is! String ||
        id.isEmpty ||
        mood is! String ||
        text is! String ||
        text.trim().isEmpty ||
        followUp is! String ||
        createdAt is! String ||
        updatedAt is! String ||
        (photoPath != null && photoPath is! String)) {
      throw const FormatException('记录字段不完整');
    }
    return JournalEntry(
      id: id,
      mood: MoodText.parse(mood),
      text: text,
      followUp: followUp,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      photoPath: photoPath as String?,
    );
  }
}

class JournalDraft {
  const JournalDraft({
    required this.text,
    required this.followUp,
    required this.photoChanged,
    this.photoSourcePath,
  });

  final String text;
  final String followUp;
  final bool photoChanged;
  final String? photoSourcePath;
}

String mergeSpeechText(String existing, String spoken) {
  final before = existing.trim();
  final words = spoken.trim();
  if (words.isEmpty) return before;
  if (before.isEmpty) return words;
  return '$before\n$words';
}

Future<Directory> _photoDirectory([Directory? baseDirectory]) async {
  final base = baseDirectory ?? await getApplicationDocumentsDirectory();
  final directory = Directory(
    '${base.path}${Platform.pathSeparator}journal_photos',
  );
  await directory.create(recursive: true);
  return directory;
}

Future<String> importPhoto(
  String sourcePath,
  String recordId, {
  Directory? baseDirectory,
  DateTime? now,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) throw const FileSystemException('照片文件不存在');
  final directory = await _photoDirectory(baseDirectory);
  final rawExtension = sourcePath.split('.').last.toLowerCase();
  final extension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(rawExtension)
      ? '.$rawExtension'
      : '.jpg';
  final timestamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  final target = File(
    '${directory.path}${Platform.pathSeparator}${recordId}_$timestamp$extension',
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

Future<void> deletePrivatePhoto(
  String? photoPath, {
  Directory? baseDirectory,
}) async {
  if (photoPath == null) return;
  final file = File(photoPath);
  if (!await file.exists()) return;
  final directory = await _photoDirectory(baseDirectory);
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

List<JournalEntry> entriesForMood(Iterable<JournalEntry> entries, Mood mood) {
  final result = entries.where((entry) => entry.mood == mood).toList();
  result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return result;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String encodeJournal(Iterable<JournalEntry> entries) => jsonEncode({
  'version': 1,
  'entries': entries.map((entry) => entry.toJson()).toList(),
});

List<JournalEntry> decodeJournal(String source) {
  final root = jsonDecode(source);
  if (root is! Map<String, Object?> ||
      root['version'] != 1 ||
      root['entries'] is! List<Object?>) {
    throw const FormatException('不支持的记录格式');
  }
  return (root['entries'] as List<Object?>).map((item) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('记录格式错误');
    }
    return JournalEntry.fromJson(item);
  }).toList();
}

const _storageKey = 'journal_v1';

Future<List<JournalEntry>> loadEntries() async {
  final source = (await SharedPreferences.getInstance()).getString(_storageKey);
  return source == null ? [] : decodeJournal(source);
}

Future<void> saveEntries(Iterable<JournalEntry> entries) async {
  final saved = await (await SharedPreferences.getInstance()).setString(
    _storageKey,
    encodeJournal(entries),
  );
  if (!saved) throw StateError('记录未能写入本机');
}
