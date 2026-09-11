import 'package:app/main.dart';
import 'package:app/life_data.dart';
import 'package:app/life_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('choose-cover')).evaluate().isNotEmpty) return;
  }
  fail('首页没有在预期时间内完成加载');
}

void main() {
  setUp(rootBundle.clear);

  testWidgets('小屏夸夸新增和修改后重新打开仍保留，历史不丢失', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    SharedPreferences.setMockInitialValues({});
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await savePraiseEntries([
      PraiseEntry(
        id: 'history',
        text: '历史测试记录',
        createdAt: yesterday,
        updatedAt: yesterday,
      ),
    ]);
    await tester.pumpWidget(const LumanmanApp());
    await _pumpUntilLoaded(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('add-praise')), 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-praise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-praise')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('praise-text')), '新增测试记录');
    await tester.ensureVisible(find.byKey(const Key('save-praise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-praise')));
    await tester.pumpAndSettle();
    final beforeEdit = await loadPraiseEntries();
    expect(
      beforeEdit.map((entry) => entry.text),
      containsAll(['历史测试记录', '新增测试记录']),
    );
    final created = beforeEdit.singleWhere((entry) => entry.id != 'history');
    await tester.ensureVisible(find.byKey(const Key('primary-praise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-praise')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('praise-text')), '修改后的测试记录');
    await tester.ensureVisible(find.byKey(const Key('save-praise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-praise')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const LumanmanApp());
    await _pumpUntilLoaded(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('primary-praise')),
      300,
    );
    expect(find.text('修改后的测试记录'), findsOneWidget);
    expect(find.text('新增测试记录'), findsNothing);
    final afterReload = await loadPraiseEntries();
    expect(afterReload, hasLength(2));
    expect(
      afterReload.singleWhere((entry) => entry.id == 'history').text,
      '历史测试记录',
    );
    expect(
      afterReload.singleWhere((entry) => entry.id == created.id).createdAt,
      created.createdAt,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('两个心情页互斥切换', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const LumanmanApp());
    await _pumpUntilLoaded(tester);

    expect(
      tester
          .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    expect(
      tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .every((widget) => widget.duration == Duration.zero),
      isTrue,
    );
    expect(
      tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .every((widget) => widget.duration == Duration.zero),
      isTrue,
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('zh', 'CN'));

    expect(find.text('路 慢 慢'), findsOneWidget);
    expect(find.text('今天'), findsWidgets);
    expect(find.text('今天拍下的'), findsOneWidget);
    expect(find.byKey(const Key('today-cat-dog')), findsOneWidget);
    final todayPet = tester.widget<Image>(
      find.byKey(const Key('today-cat-dog')),
    );
    final todayPetProvider = todayPet.image as ResizeImage;
    expect(
      (todayPetProvider.imageProvider as AssetImage).assetName,
      'assets/stickers/today-cat-dog-exact.png',
    );
    expect(find.byKey(const Key('choose-cover')), findsOneWidget);
    expect(find.byTooltip('选择首页照片'), findsOneWidget);
    expect(find.textContaining('《人民日报》'), findsNothing);
    final removedCopy = [
      ['给今天的自己', '留一句好话'].join(),
      ['今天哪件小事，', '值得拍拍自己的肩？'].join(),
      ['不用做得完美，', '向前一点也值得。'].join(),
    ];
    for (final copy in removedCopy) {
      expect(find.text(copy), findsNothing);
    }
    expect(find.byType(AnimatedSwitcher), findsWidgets);

    final quoteAsset = await rootBundle.loadString(
      'assets/quotes/curated-quotes.txt',
    );
    expect(quoteAsset, isNot(contains(['用户', '截图'].join())));
    expect(quoteAsset, isNot(contains(['用户', '提供'].join())));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('夸夸墙'), findsOneWidget);
    expect(find.text('已经夸了 0 次'), findsOneWidget);
    expect(find.text('你其实比你想的更勇敢'), findsNothing);
    expect(find.byKey(const Key('praise-wall-cat-dog')), findsOneWidget);
    final praisePet = tester.widget<Image>(
      find.byKey(const Key('praise-wall-cat-dog')),
    );
    final praisePetProvider = praisePet.image as ResizeImage;
    expect(
      (praisePetProvider.imageProvider as AssetImage).assetName,
      'assets/stickers/praise-wall-cat-dog-exact.png',
    );
    expect(
      (await rootBundle.load('assets/stickers/praise-wall-cat-dog-exact.png'))
          .lengthInBytes,
      greaterThan(0),
    );
    expect(find.text('+ 贴一张夸夸'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('add-praise')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('add-praise')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('夸夸墙'), findsWidgets);
    expect(find.text(['换个', '问法'].join()), findsNothing);
    expect(find.text(['写给今天的', '自己……'].join()), findsNothing);
    expect(find.byKey(const Key('praise-text')), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('praise-text')))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('nav-收支')));
    await tester.pumpAndSettle();
    expect(find.text('本月还剩'), findsOneWidget);
    expect(find.byKey(const Key('ledger-paw-trail')), findsOneWidget);
    expect(find.byKey(const Key('ledger-cat-dog')), findsNothing);

    await tester.tap(find.byKey(const Key('add-money')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    expect(find.text('选择日期'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-回想')));
    await tester.pumpAndSettle();
    expect(find.text('回想'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav-记下')));
    await tester.pumpAndSettle();
    expect(find.text('还没有开心记录'), findsOneWidget);
    expect(find.text('还没有不开心记录'), findsNothing);

    await tester.tap(find.byKey(const Key('unhappy-tab')));
    await tester.pumpAndSettle();

    expect(find.text('还没有开心记录'), findsNothing);
    expect(find.text('还没有不开心记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speech-input')), findsOneWidget);
    expect(find.byKey(const Key('pick-photo')), findsOneWidget);
  });

  testWidgets('小屏和字体放大时收支摘要不会溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final now = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'money_v1':
          '{"version":1,"entries":[{"id":"large","kind":"income",'
          '"category":"副业","cents":99999999999,"note":"",'
          '"occurredAt":"$now","updatedAt":"$now"}]}',
    });

    await tester.pumpWidget(const LumanmanApp());
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('nav-收支')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const Key('nav-收支')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-收支')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('本月还剩'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('每天第一条夸夸在猫狗纸条，其余和历史夸夸全部保留', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final praises = [
      PraiseEntry(
        id: 'yesterday-first',
        text: '昨天第一条',
        createdAt: yesterday.add(const Duration(hours: 8)),
        updatedAt: yesterday.add(const Duration(hours: 8)),
      ),
      PraiseEntry(
        id: 'yesterday-second',
        text: '昨天第二条',
        createdAt: yesterday.add(const Duration(hours: 9)),
        updatedAt: yesterday.add(const Duration(hours: 9)),
      ),
      PraiseEntry(
        id: 'today-first',
        text: '今天第一条',
        createdAt: today.add(const Duration(hours: 8)),
        updatedAt: today.add(const Duration(hours: 8)),
      ),
      PraiseEntry(
        id: 'today-second',
        text: '今天第二条',
        createdAt: today.add(const Duration(hours: 9)),
        updatedAt: today.add(const Duration(hours: 9)),
      ),
    ];
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayPage(
            journalEntries: const [],
            moneyEntries: const [],
            praiseEntries: praises,
            dailyCovers: const [],
            quotes: const [],
            loading: false,
            onSavePraise: (_, _) async => true,
            onDeletePraise: (_) async => true,
            onChooseCover: (_) async {},
            onWrite: () {},
          ),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('已经夸了 2 次'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('primary-praise')),
        matching: find.text('今天第一条'),
      ),
      findsOneWidget,
    );
    expect(find.text('今天第二条'), findsOneWidget);
    expect(find.text('昨天第一条'), findsOneWidget);
    expect(find.text('昨天第二条'), findsOneWidget);
    final noteKeys = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.key)
        .whereType<ValueKey<String>>()
        .map((key) => key.value)
        .where((key) => key.startsWith('praise-note-'))
        .toList();
    expect(noteKeys, [
      'praise-note-today-second',
      'praise-note-yesterday-first',
      'praise-note-yesterday-second',
    ]);
    expect(find.textContaining('今天哪件小事'), findsNothing);
    expect(find.textContaining('给今天的自己'), findsNothing);
  });
}
