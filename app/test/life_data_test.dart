import 'dart:io';

import 'package:app/journal.dart';
import 'package:app/life_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('金额以整数分序列化并正确汇总指定月份', () {
    final augustIncome = _money(
      'a',
      MoneyKind.income,
      12345,
      DateTime(2026, 8, 2),
    );
    final augustExpense = _money(
      'b',
      MoneyKind.expense,
      2345,
      DateTime(2026, 8, 3),
    );
    final septemberIncome = _money(
      'c',
      MoneyKind.income,
      9999,
      DateTime(2026, 9, 1),
    );

    final decoded = MoneyEntry.fromJson(augustIncome.toJson());
    final summary = summarizeMonth([
      augustIncome,
      augustExpense,
      septemberIncome,
    ], DateTime(2026, 8));

    expect(decoded.cents, 12345);
    expect(summary.incomeCents, 12345);
    expect(summary.expenseCents, 2345);
    expect(summary.balanceCents, 10000);
    expect(parseMoneyToCents('12.34'), 1234);
    expect(parseMoneyToCents('12.345'), isNull);
  });

  test('今天无图时回退到最近照片并保留真实来源日期', () {
    final today = DateTime(2026, 8, 28, 12);
    final yesterday = DateTime(2026, 8, 27, 18);
    final older = DateTime(2026, 8, 26, 9);
    final selected = latestPhotoOnOrBefore(
      [
        _journal('today', Mood.happy, today),
        _journal('older', Mood.happy, older, photoPath: 'older.jpg'),
        _journal('latest', Mood.unhappy, yesterday, photoPath: 'latest.jpg'),
      ],
      today,
      exists: (_) => true,
    );

    expect(selected?.photoPath, 'latest.jpg');
    expect(selected?.createdAt, yesterday);
  });

  test('每日封面可往返、按日期替换，并且不会读取未来照片', () {
    final yesterday = DailyCover(
      dateKey: '2026-08-27',
      photoPath: 'yesterday.jpg',
      updatedAt: DateTime(2026, 8, 27, 18),
    );
    final today = DailyCover(
      dateKey: '2026-08-28',
      photoPath: 'today.jpg',
      updatedAt: DateTime(2026, 8, 28, 9),
    );
    final replacement = DailyCover(
      dateKey: '2026-08-28',
      photoPath: 'replacement.jpg',
      updatedAt: DateTime(2026, 8, 28, 10),
    );
    final future = DailyCover(
      dateKey: '2026-08-29',
      photoPath: 'future.jpg',
      updatedAt: DateTime(2026, 8, 29),
    );

    final decoded = DailyCover.fromJson(today.toJson());
    final replaced = upsertDailyCover([yesterday, today, future], replacement);

    expect(decoded.photoPath, 'today.jpg');
    expect(
      coverForDay(replaced, DateTime(2026, 8, 28))?.photoPath,
      'replacement.jpg',
    );
    expect(
      replaced.where((item) => item.dateKey == '2026-08-28'),
      hasLength(1),
    );
    expect(
      latestCoverOnOrBefore(replaced, DateTime(2026, 8, 27))?.photoPath,
      'yesterday.jpg',
    );
    expect(
      removeDailyCover(
        replaced,
        DateTime(2026, 8, 28),
      ).any((item) => item.dateKey == '2026-08-28'),
      isFalse,
    );
  });

  test('回想仅返回所选日期的心情、夸夸和收支', () {
    final selected = DateTime(2026, 8, 28);
    final other = DateTime(2026, 8, 27);
    final journals = [
      _journal('j1', Mood.happy, selected),
      _journal('j2', Mood.unhappy, other),
    ];
    final praises = [
      PraiseEntry(
        id: 'p1',
        text: '做完了',
        createdAt: selected,
        updatedAt: selected,
      ),
      PraiseEntry(id: 'p2', text: '别日', createdAt: other, updatedAt: other),
    ];
    final money = [
      _money('m1', MoneyKind.income, 500, selected),
      _money('m2', MoneyKind.expense, 300, other),
    ];

    expect(journalForDay(journals, selected).map((entry) => entry.id), ['j1']);
    expect(praiseForDay(praises, selected).map((entry) => entry.id), ['p1']);
    expect(moneyForDay(money, selected).map((entry) => entry.id), ['m1']);
  });

  test('名言去重并按固定随机顺序轮换', () {
    const source = "[['第一句。','来源甲'],\n  ['第二句。','来源乙'],\n  ['第一句。','来源丙']]";
    final quotes = parseQuotes(source);

    expect(quotes, hasLength(2));
    expect(quotes.first.text, '第一句。');
    expect(quotes.first.source, '来源甲');
    final firstDay = quoteForDay(quotes, DateTime(2026, 1, 1));
    final secondDay = quoteForDay(quotes, DateTime(2026, 1, 2));
    expect(quoteForDay(quotes, DateTime(2026, 1, 1)), firstDay);
    expect({firstDay.text, secondDay.text}, {'第一句。', '第二句。'});
  });

  test('名言来源只显示真实作者或出处', () {
    final screenshot = ['用户', '截图'].join();
    final excerpt = ['用户', '截图', '摘录'].join();
    final provided = ['《人民日报》', '（用户', '提供）'].join();

    expect(displayQuoteSource(screenshot), isEmpty);
    expect(displayQuoteSource(excerpt), isEmpty);
    expect(displayQuoteSource(provided), '《人民日报》');
    expect(displayQuoteSource('  毛泽东《实践论》  '), '毛泽东《实践论》');
  });

  test('正式词库只保留既有内容与用户内容，并把个人内容均匀打散', () {
    final source = File('assets/quotes/curated-quotes.txt').readAsStringSync();
    final quotes = parseQuotes(source);
    final schedule = buildQuoteSchedule(quotes);

    expect(quotes, isNotEmpty);
    expect(quotes.any((quote) => quote.source == '路慢慢·每日一句'), isFalse);
    for (var index = 1; index < schedule.length; index++) {
      expect(
        schedule[index - 1].source == '傻子' && schedule[index].source == '傻子',
        isFalse,
        reason: '“傻子”署名内容不能连续两天出现',
      );
    }

    final personal = schedule
        .where((quote) => quote.source == '傻子')
        .map((quote) => quote.text)
        .toList();
    expect(personal, hasLength(19));
    expect(personal.sublist(personal.length - 8).join(), '郑雯然天下第一好');
  });
}

MoneyEntry _money(String id, MoneyKind kind, int cents, DateTime date) =>
    MoneyEntry(
      id: id,
      kind: kind,
      category: kind == MoneyKind.income ? '工资' : '餐饮',
      cents: cents,
      note: '',
      occurredAt: date,
      updatedAt: date,
    );

JournalEntry _journal(
  String id,
  Mood mood,
  DateTime date, {
  String? photoPath,
}) => JournalEntry(
  id: id,
  mood: mood,
  text: id,
  followUp: '',
  createdAt: date,
  updatedAt: date,
  photoPath: photoPath,
);
