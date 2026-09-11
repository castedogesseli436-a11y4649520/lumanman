import 'dart:io';
import 'dart:ui' as ui;

import 'package:app/life_data.dart';
import 'package:app/life_pages.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(rootBundle.clear);

  testWidgets('首页五种比例完整适配，小屏大字体可操作并查看原图', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    const photoConstraints = BoxConstraints(maxWidth: 252, maxHeight: 350);
    for (final size in [
      const Size(160, 90),
      const Size(90, 160),
      const Size(100, 100),
      const Size(800, 100),
      const Size(100, 800),
    ]) {
      final fitted = photoConstraints
          .constrainSizeAndAttemptToPreserveAspectRatio(size);
      expect(
        fitted.width / fitted.height,
        closeTo(size.width / size.height, .001),
      );
      expect(fitted.height, lessThanOrEqualTo(350));
      expect(fitted.width, lessThanOrEqualTo(252));
      expect(applyBoxFit(BoxFit.contain, size, fitted).source, size);
    }

    var writeCount = 0;
    final photo = File('assets/stickers/happy-dog.png').absolute;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayPage(
            journalEntries: const [],
            praiseEntries: const [],
            dailyCovers: [
              DailyCover(
                dateKey: dayKey(DateTime.now()),
                photoPath: photo.path,
                updatedAt: DateTime.now(),
              ),
            ],
            quotes: const [DailyQuote('测试长句，用于验证首页自然换行与按钮滚动可达。', '')],
            loading: false,
            onSavePraise: (_, _) async => true,
            onDeletePraise: (_) async => true,
            onChooseCover: (_) async {},
            onWrite: () => writeCount++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Image>(find.byKey(const Key('today-photo-image'))).fit,
      BoxFit.contain,
    );
    expect(find.text('今天的心情'), findsNothing);
    expect(find.text('今天拍下的'), findsNothing);
    tester
        .widget<GestureDetector>(find.byKey(const Key('view-cover')))
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('quick-write')), 200);
    expect(
      tester.getSize(find.byKey(const Key('quick-write'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('open-praise'))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byKey(const Key('quick-write')));
    await tester.tap(find.byKey(const Key('open-praise')));
    await tester.pumpAndSettle();
    expect(find.text('夸夸墙'), findsOneWidget);
    expect(find.byKey(const Key('add-praise')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-praise')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-date')), findsOneWidget);
    expect(writeCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页快捷记下打开编辑器而非记录列表', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LumanmanApp());
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('quick-write')).evaluate().isNotEmpty) break;
    }
    await tester.scrollUntilVisible(find.byKey(const Key('quick-write')), 200);
    await tester.ensureVisible(find.byKey(const Key('quick-write')));
    await tester.tap(find.byKey(const Key('quick-write')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speech-input')), findsOneWidget);
    expect(find.byKey(const Key('pick-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可选：保存正式组件的首页截图', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_TODAY');
    if (!capture) return;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      final loader = FontLoader('MicrosoftYaHei')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
            ),
          ),
        );
      final materialIcons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await Future.wait([loader.load(), materialIcons.load()]);
      SharedPreferences.setMockInitialValues({});
      await saveDailyCovers([
        DailyCover(
          dateKey: dayKey(DateTime.now()),
          photoPath: File(
            '../work/design-spec/mockups/today-photo-extracted.jpg',
          ).absolute.path,
          updatedAt: DateTime.now(),
        ),
      ]);
    });
    await tester.pumpWidget(const LumanmanApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: app.theme!.copyWith(
          textTheme: app.theme!.textTheme.apply(fontFamily: 'MicrosoftYaHei'),
        ),
        locale: app.locale,
        localizationsDelegates: app.localizationsDelegates,
        supportedLocales: app.supportedLocales,
        home: RepaintBoundary(key: boundary, child: const JournalPage()),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final finder = find.byKey(const Key('today-photo-image'));
    for (var i = 0; i < 20 && tester.getSize(finder).isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(tester.getSize(finder).isEmpty, isFalse);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../work/design-spec/implementation/today-v3-actual.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
