import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/hive_service.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../models/txn.dart';
import 'auth_service.dart';

/// Firestore sync layer. Dormant until [AuthService.cloudEnabled] is true.
/// Enable by adding a Firebase project (google-services.json) — no code
/// changes needed beyond that.
class SyncService {
  static bool get enabled => AuthService.cloudEnabled;

  static String get statusText => enabled
      ? 'Connected — sync is active'
      : 'Not configured — connect Firebase to enable';

  static void _requireReady() {
    if (!enabled) {
      throw StateError('Cloud sync is not configured.');
    }
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Not signed in.');
    }
  }

  /// Pushes all local boxes to Firestore under users/{uid}/data/*.
  static Future<void> pushAll() async {
    _requireReady();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final root = db.collection('users').doc(uid);

    final batch = db.batch();
    for (final a in HiveService.accounts.values) {
      batch.set(root.collection('accounts').doc(a.id), a.toJson());
    }
    for (final c in HiveService.categories.values) {
      batch.set(root.collection('categories').doc(c.id), c.toJson());
    }
    for (final t in HiveService.txns.values) {
      batch.set(root.collection('txns').doc(t.id), t.toJson());
    }
    for (final b in HiveService.budgets.values) {
      batch.set(root.collection('budgets').doc(b.id), b.toJson());
    }
    for (final r in HiveService.recurring.values) {
      batch.set(root.collection('recurring').doc(r.id), r.toJson());
    }
    batch.set(root, {'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    await batch.commit();
  }

  /// Pulls cloud data and replaces local boxes (after user confirmation).
  static Future<void> pullAll() async {
    _requireReady();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final root =
        FirebaseFirestore.instance.collection('users').doc(uid);

    Future<List<Map<String, dynamic>>> fetch(String name) async {
      final snap = await root.collection(name).get();
      return snap.docs.map((d) => d.data()).toList();
    }

    final accounts = await fetch('accounts');
    final categories = await fetch('categories');
    final txns = await fetch('txns');
    final budgets = await fetch('budgets');
    final recurring = await fetch('recurring');

    await HiveService.accounts.clear();
    for (final j in accounts) {
      final a = Account.fromJson(j);
      await HiveService.accounts.put(a.id, a);
    }
    await HiveService.categories.clear();
    for (final j in categories) {
      final c = Category.fromJson(j);
      await HiveService.categories.put(c.id, c);
    }
    await HiveService.txns.clear();
    for (final j in txns) {
      final t = Txn.fromJson(j);
      await HiveService.txns.put(t.id, t);
    }
    await HiveService.budgets.clear();
    for (final j in budgets) {
      final b = Budget.fromJson(j);
      await HiveService.budgets.put(b.id, b);
    }
    await HiveService.recurring.clear();
    for (final j in recurring) {
      final r = Recurring.fromJson(j);
      await HiveService.recurring.put(r.id, r);
    }
  }

  /// Anonymous sign-in so sync works without the user typing credentials.
  static Future<void> signInAnonymously() async {
    _requireReady();
    await FirebaseAuth.instance.signInAnonymously();
  }

  static Future<void> signOut() async {
    if (!enabled) return;
    await FirebaseAuth.instance.signOut();
  }
}
