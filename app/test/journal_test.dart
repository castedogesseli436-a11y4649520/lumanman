import 'dart:io';

import 'package:app/journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('开心与不开心互相隔离并按时间倒序', () {
    final today = DateTime(2026, 8, 28, 10);
    final yesterday = DateTime(2026, 8, 27, 22);
    final entries = [
      _entry('h1', Mood.happy, today),
      _entry('u1', Mood.unhappy, today.add(const Duration(hours: 1))),
      _entry('h2', Mood.happy, today.add(const Duration(hours: 2))),
      _entry('u2', Mood.unhappy, today.add(const Duration(hours: 3))),
      _entry('u0', Mood.unhappy, yesterday),
    ];

    expect(entriesForMood(entries, Mood.happy).map((e) => e.id), ['h2', 'h1']);
    expect(entriesForMood(entries, Mood.unhappy).map((e) => e.id), [
      'u2',
      'u1',
      'u0',
    ]);
  });

  test('记录能原样写入并从本机存储读回', () async {
    SharedPreferences.setMockInitialValues({});
    final source = [
      JournalEntry(
        id: '1',
        mood: Mood.unhappy,
        text: '今天有点累',
        followUp: '早点休息。',
        createdAt: DateTime(2026, 8, 28, 21),
        updatedAt: DateTime(2026, 8, 28, 21),
      ),
    ];

    await saveEntries(source);
    final loaded = await loadEntries();

    expect(loaded.single.id, '1');
    expect(loaded.single.mood, Mood.unhappy);
    expect(loaded.single.text, '今天有点累');
    expect(loaded.single.followUp, '早点休息。');
  });

  test('v0.1 旧记录没有照片字段时仍可读取', () {
    const legacy =
        '{"version":1,"entries":[{"id":"old","mood":"happy",'
        '"text":"旧记录","followUp":"","createdAt":"2026-08-28T10:00:00.000",'
        '"updatedAt":"2026-08-28T10:00:00.000"}]}';

    final loaded = decodeJournal(legacy);

    expect(loaded.single.text, '旧记录');
    expect(loaded.single.photoPath, isNull);
  });

  test('照片字段能往返，私有副本可创建和清理', () async {
    final temporary = await Directory.systemTemp.createTemp('lumanman_test_');
    try {
      final source = File(
        '${temporary.path}${Platform.pathSeparator}source.jpeg',
      );
      await source.writeAsBytes([1, 2, 3, 4]);
      final copied = await importPhoto(
        source.path,
        'record',
        baseDirectory: temporary,
        now: DateTime(2026, 8, 28),
      );
      final entry = _entry(
        'record',
        Mood.happy,
        DateTime(2026, 8, 28),
        photoPath: copied,
      );

      final decoded = decodeJournal(encodeJournal([entry])).single;

      expect(decoded.photoPath, copied);
      expect(await File(copied).readAsBytes(), [1, 2, 3, 4]);
      await deletePrivatePhoto(copied, baseDirectory: temporary);
      expect(await File(copied).exists(), isFalse);
      expect(await source.exists(), isTrue);
    } finally {
      await temporary.delete(recursive: true);
    }
  });

  test('语音文字以新段落合并且不重复空内容', () {
    expect(mergeSpeechText('', '今天很好'), '今天很好');
    expect(mergeSpeechText('先写的内容', '后来想到'), '先写的内容\n后来想到');
    expect(mergeSpeechText('保留', '   '), '保留');
  });
}

JournalEntry _entry(
  String id,
  Mood mood,
  DateTime createdAt, {
  String? photoPath,
}) => JournalEntry(
  id: id,
  mood: mood,
  text: id,
  followUp: '',
  createdAt: createdAt,
  updatedAt: createdAt,
  photoPath: photoPath,
);
