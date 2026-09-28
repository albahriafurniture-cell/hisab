import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import '../utils/app_paths.dart';
import '../utils/format.dart';

/// Central Hive access: boxes, seeding, balance-aware txn operations.
class HiveService {
  static const accountsBox = 'accounts';
  static const categoriesBox = 'categories';
  static const txnsBox = 'txns';
  static const budgetsBox = 'budgets';
  static const recurringBox = 'recurring';
  static const goalsBox = 'goals';
  static const settingsBox = 'settings';

  static late Box<Account> accounts;
  static late Box<Category> categories;
  static late Box<Txn> txns;
  static late Box<Budget> budgets;
  static late Box<Recurring> recurring;
  static late Box<Goal> goals;
  static late Box settings;

  static Future<void> init() async {
    // NOTE: Hive.initFlutter() is deliberately NOT used on native — it goes
    // through path_provider, whose jni native library our manual APK pipeline
    // cannot bundle (instant crash on launch). AppPaths.documentsDir()
    // resolves the identical location with plain dart:io. On web,
    // initFlutter() is safe (hive_flutter stubs path_provider out and Hive
    // uses IndexedDB automatically).
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final docsDir = await AppPaths.documentsDir();
      Hive.init(docsDir.path);
    }
    _registerAdapters();
    accounts = await Hive.openBox<Account>(accountsBox);
    categories = await Hive.openBox<Category>(categoriesBox);
    txns = await Hive.openBox<Txn>(txnsBox);
    budgets = await Hive.openBox<Budget>(budgetsBox);
    recurring = await Hive.openBox<Recurring>(recurringBox);
    goals = await Hive.openBox<Goal>(goalsBox);
    settings = await Hive.openBox(settingsBox);
    await seedDefaults();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AccountAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TxnAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RecurringAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(GoalAdapter());
  }

  // ---------------------------------------------------------------- seeding
  static Future<void> seedDefaults() async {
    if (categories.isEmpty) {
      for (final c in _defaultCategories()) {
        await categories.put(c.id, c);
      }
    }
    if (accounts.isEmpty) {
      final cash = Account(
        id: Uuid().v4(),
        name: 'Cash',
        type: 'cash',
        balance: 0,
        color: 0xFF10B981,
        icon: 'cash',
        createdAt: DateTime.now(),
      );
      await accounts.put(cash.id, cash);
    }
  }

  static List<Category> _defaultCategories() {
    const exp = [
      ('Food', 'food', 0xFFF59E0B),
      ('Transport', 'transport', 0xFF22D3EE),
      ('Shopping', 'shopping', 0xFF8B5CF6),
      ('Bills & Utilities', 'bills', 0xFF38BDF8),
      ('Health', 'health', 0xFF34D399),
      ('Entertainment', 'entertainment', 0xFFF472B6),
      ('Education', 'education', 0xFF60A5FA),
      ('Family', 'family', 0xFFFB7185),
      ('Travel', 'travel', 0xFF2DD4BF),
      ('Other', 'other', 0xFF94A3B8),
    ];
    const inc = [
      ('Salary', 'salary', 0xFF10B981),
      ('Business', 'business', 0xFF22D3EE),
      ('Freelance', 'freelance', 0xFF8B5CF6),
      ('Investment', 'investment', 0xFFF59E0B),
      ('Other', 'other', 0xFF94A3B8),
    ];
    final uuid = Uuid();
    return [
      for (final e in exp)
        Category(
            id: uuid.v4(),
            name: e.$1,
            icon: e.$2,
            color: e.$3,
            kind: 'expense'),
      for (final e in inc)
        Category(
            id: uuid.v4(), name: e.$1, icon: e.$2, color: e.$3, kind: 'income'),
    ];
  }

  /// Wipes everything and re-seeds (used by "forgot PIN" reset).
  static Future<void> resetAll() async {
    await accounts.clear();
    await categories.clear();
    await txns.clear();
    await budgets.clear();
    await recurring.clear();
    await goals.clear();
    await settings.clear();
    await seedDefaults();
  }

  // ------------------------------------------------------- balance-aware ops
  static Future<void> _applyEffect(
      String accountId, String kind, double amount, int sign) async {
    final a = accounts.get(accountId);
    if (a == null) return;
    final delta = (kind == 'income' ? amount : -amount) * sign;
    a.balance += delta;
    await accounts.put(a.id, a);
  }

  static Future<void> addTxn(Txn t) async {
    await _applyEffect(t.accountId, t.kind, t.amount, 1);
    await txns.put(t.id, t);
  }

  static Future<void> restoreTxn(Txn t) async {
    // Re-insert a previously deleted txn (undo) with its original id.
    await _applyEffect(t.accountId, t.kind, t.amount, 1);
    await txns.put(t.id, t);
  }

  static Future<void> deleteTxn(Txn t) async {
    await _applyEffect(t.accountId, t.kind, t.amount, -1);
    await txns.delete(t.id);
  }

  static Future<void> updateTxn(Txn oldT, Txn newT) async {
    await _applyEffect(oldT.accountId, oldT.kind, oldT.amount, -1);
    await _applyEffect(newT.accountId, newT.kind, newT.amount, 1);
    await txns.put(newT.id, newT);
  }

  /// Moves every txn from one account to another, fixing both balances.
  static Future<void> moveTxns(String fromId, String toId) async {
    final moving =
        txns.values.where((t) => t.accountId == fromId).toList();
    for (final t in moving) {
      await _applyEffect(fromId, t.kind, t.amount, -1);
      await _applyEffect(toId, t.kind, t.amount, 1);
      t.accountId = toId;
      await txns.put(t.id, t);
    }
  }

  // ----------------------------------------------------------------- queries
  static double totalBalance() =>
      accounts.values.fold(0.0, (s, a) => s + a.balance);

  static double _sumForMonth(String kind, String key) => txns.values
      .where((t) => t.kind == kind && monthKey(t.date) == key)
      .fold(0.0, (s, t) => s + t.amount);

  static double incomeForMonth(String key) => _sumForMonth('income', key);
  static double expenseForMonth(String key) => _sumForMonth('expense', key);

  static double spentForCategory(String categoryId, String key) => txns.values
      .where((t) =>
          t.kind == 'expense' &&
          t.categoryId == categoryId &&
          monthKey(t.date) == key)
      .fold(0.0, (s, t) => s + t.amount);

  static List<Txn> txnsForMonth(String key) {
    final list = txns.values
        .where((t) => monthKey(t.date) == key)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static List<Txn> txnsForAccount(String accountId) {
    final list =
        txns.values.where((t) => t.accountId == accountId).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static List<Txn> recentTxns(int n) {
    final list = txns.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list.take(n).toList();
  }

  static double netForDay(DateTime day) {
    double net = 0;
    for (final t in txns.values) {
      final d = t.date;
      if (d.year == day.year && d.month == day.month && d.day == day.day) {
        net += t.kind == 'income' ? t.amount : -t.amount;
      }
    }
    return net;
  }

  static double expenseForDay(DateTime day) {
    double sum = 0;
    for (final t in txns.values) {
      final d = t.date;
      if (d.year == day.year &&
          d.month == day.month &&
          d.day == day.day &&
          t.kind == 'expense') {
        sum += t.amount;
      }
    }
    return sum;
  }

  // ---------------------------------------------------------------- recurring
  static bool isDue(Recurring r, DateTime now) {
    if (!r.active) return false;
    final key = monthKey(now);
    if (r.lastPostedKey == key) return false;
    final dueDay = r.dayOfMonth.clamp(1, daysInMonth(now.year, now.month));
    return now.day >= dueDay;
  }

  static List<Recurring> dueRecurrings(DateTime now) =>
      recurring.values.where((r) => isDue(r, now)).toList();

  static Future<void> postRecurring(Recurring r, {DateTime? on}) async {
    final now = on ?? DateTime.now();
    final t = Txn(
      id: Uuid().v4(),
      amount: r.amount,
      kind: r.kind,
      categoryId: r.categoryId,
      accountId: r.accountId,
      date: DateTime(now.year, now.month, now.day),
      note: r.title,
      createdAt: now,
      updatedAt: now,
    );
    await addTxn(t);
    r.lastPostedKey = monthKey(now);
    await recurring.put(r.id, r);
  }

  // --------------------------------------------------------------------- goals
  /// Progress 0..1, clamped. A goal with no positive target reads 0.
  static double goalProgress(Goal g) {
    if (g.targetAmount <= 0) return 0.0;
    return (g.savedAmount / g.targetAmount).clamp(0.0, 1.0);
  }

  static double totalGoalsSaved() =>
      goals.values.fold(0.0, (s, g) => s + g.savedAmount);

  static double totalGoalsTarget() =>
      goals.values.fold(0.0, (s, g) => s + g.targetAmount);

  /// Adds [amount] to a goal. When [fromAccountId] is given, the same amount
  /// is deducted from that account's balance (balance-aware, like txns).
  static Future<void> contributeToGoal(String goalId, double amount,
      {String? fromAccountId}) async {
    if (amount <= 0) return;
    if (fromAccountId != null) {
      await _applyEffect(fromAccountId, 'expense', amount, 1);
    }
    final g = goals.get(goalId);
    if (g == null) return;
    g.savedAmount += amount;
    await goals.put(g.id, g);
  }

  /// Removes [amount] from a goal (never below zero). When [toAccountId] is
  /// given, the withdrawn amount is returned to that account's balance.
  static Future<void> withdrawFromGoal(String goalId, double amount,
      {String? toAccountId}) async {
    if (amount <= 0) return;
    final g = goals.get(goalId);
    if (g == null) return;
    final take = amount.clamp(0.0, g.savedAmount);
    if (toAccountId != null) {
      await _applyEffect(toAccountId, 'income', take, 1);
    }
    g.savedAmount -= take;
    await goals.put(g.id, g);
  }

  static Future<void> deleteGoal(String id) async => goals.delete(id);

  // ----------------------------------------------------------------- settings
  static String? get pinHash => settings.get('pinHash') as String?;
  static Future<void> setPinHash(String hash) =>
      settings.put('pinHash', hash);
}
