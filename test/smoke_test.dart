import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:hisab/data/hive_service.dart';
import 'package:hisab/main.dart';
import 'package:hisab/models/account.dart';
import 'package:hisab/models/budget.dart';
import 'package:hisab/models/category.dart';
import 'package:hisab/models/goal.dart';
import 'package:hisab/models/recurring.dart';
import 'package:hisab/models/txn.dart';
import 'package:hisab/screens/main_shell.dart';
import 'package:hisab/widgets/glass_bottom_nav.dart';
import 'package:hisab/theme.dart';

/// Headless UI smoke test: boots the real app against a temp Hive store,
/// pumps the main screens and captures golden screenshots. Run with:
///   flutter test --update-goldens   (first time, to record goldens)
///   flutter test                    (verify - fails if UI regresses)
Future<void> initTestHive() async {
  final dir = await Directory.systemTemp.createTemp('hisab_smoke');
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AccountAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TxnAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RecurringAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(GoalAdapter());
  HiveService.accounts = await Hive.openBox<Account>('accounts');
  HiveService.categories = await Hive.openBox<Category>('categories');
  HiveService.txns = await Hive.openBox<Txn>('txns');
  HiveService.budgets = await Hive.openBox<Budget>('budgets');
  HiveService.recurring = await Hive.openBox<Recurring>('recurring');
  HiveService.goals = await Hive.openBox<Goal>('goals');
  HiveService.settings = await Hive.openBox('settings');
  await HiveService.seedDefaults();
}

Future<void> seedSampleData() async {
  final cash = HiveService.accounts.values.first;
  final cats = HiveService.categories.values.toList();
  final now = DateTime.now();
  Future<void> addTxn(double amount, String kind, int daysAgo, String note) async {
    final t = Txn(
      id: 't-$note-$daysAgo',
      amount: amount,
      kind: kind,
      categoryId: cats.isNotEmpty ? cats.first.id : '',
      accountId: cash.id,
      date: now.subtract(Duration(days: daysAgo)),
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await HiveService.txns.put(t.id, t);
  }

  await addTxn(150000, 'income', 2, 'Salary');
  await addTxn(2500, 'expense', 1, 'Groceries');
  await addTxn(800, 'expense', 0, 'Fuel');
}

Widget wrap(Widget child) => MaterialApp(
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: child,
    );

void main() {
  setUpAll(() async {
    await initTestHive();
    await seedSampleData();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('app boots to onboarding on fresh install', (tester) async {
    await tester.pumpWidget(const HisabApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // Fresh install -> onboarding flow visible (no crash).
    expect(find.byType(Scaffold), findsWidgets);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/01_onboarding.png'));
  });

  testWidgets('main shell renders all tabs without errors', (tester) async {
    await tester.pumpWidget(wrap(const MainShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byType(MainShell), matchesGoldenFile('goldens/02_home.png'));

    // Walk through bottom-nav tabs and screenshot each.
    final navFinder = find.byType(GlassBottomNav);
    expect(navFinder, findsOneWidget);
    final tabTaps = find.descendant(
      of: navFinder,
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null,
      ),
    );
    // First GestureDetector is the center ADD button; the rest are tabs.
    for (var i = 1; i < tabTaps.evaluate().length; i++) {
      await tester.tap(tabTaps.at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MainShell),
          matchesGoldenFile('goldens/03_tab_$i.png'));
    }
  });
}
