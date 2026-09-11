import 'package:app/journal.dart';
import 'package:app/life_data.dart';
import 'package:app/life_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('月底切换到二月时选择有效日期，覆盖平年与闰年', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RecallPage(
            journalEntries: [],
            moneyEntries: [],
            praiseEntries: [],
            dailyCovers: [],
            loading: false,
          ),
        ),
      ),
    );
    var month = DateTime(DateTime.now().year, DateTime.now().month);
    for (final year in [2027, 2028]) {
      final target = DateTime(year, 1);
      final delta =
          (target.year - month.year) * 12 + target.month - month.month;
      for (var step = 0; step < delta.abs(); step++) {
        await tester.tap(
          find.byKey(Key(delta > 0 ? 'next-month' : 'previous-month')),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(ValueKey('recall-day-$year-01-31')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pumpAndSettle();
      final last = DateTime(year, 3, 0).day;
      expect(find.text('2月$last日'), findsOneWidget);
      expect(
        find.byKey(ValueKey('recall-day-$year-02-${last + 1}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      month = DateTime(year, 2);
    }
  });

  testWidgets('小屏放大字体的长回忆可滚动读完，猫狗在正文之后', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final day = DateTime.now();
    final text = '这是一条用于检查换行和滚动的测试记录。' * 12;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecallPage(
            journalEntries: [],
            moneyEntries: [],
            dailyCovers: [],
            loading: false,
            praiseEntries: [
              PraiseEntry(
                id: 'long',
                text: text,
                createdAt: day,
                updatedAt: day,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('recall-cat-dog')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(text)).maxLines, isNull);
    expect(
      tester.getBottomLeft(find.text(text)).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('recall-cat-dog'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('回想切换日期只展示对应记录，跨月后年份同步', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 1);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecallPage(
            journalEntries: [
              JournalEntry(
                id: 'one',
                mood: Mood.happy,
                text: '当天心情',
                followUp: '',
                createdAt: day,
                updatedAt: day,
              ),
            ],
            praiseEntries: [
              PraiseEntry(
                id: 'p',
                text: '当天夸夸',
                createdAt: day,
                updatedAt: day,
              ),
            ],
            moneyEntries: const [],
            dailyCovers: const [],
            loading: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('recall-day-${dayKey(day)}')));
    await tester.pumpAndSettle();
    expect(find.text('2条回忆'), findsOneWidget);
    expect(find.text('当天心情'), findsOneWidget);
    expect(find.text('当天夸夸'), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey('recall-day-${dayKey(day.add(const Duration(days: 1)))}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0条回忆'), findsOneWidget);
    expect(find.text('当天心情'), findsNothing);
    expect(find.text('当天夸夸'), findsNothing);
    for (var i = 0; i < now.month; i++) {
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pumpAndSettle();
    }
    expect(find.text('${now.year - 1}'), findsOneWidget);
    expect(find.text('12月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
