import 'package:flutter/material.dart';

/// String-keyed icon registry so icons survive Hive/JSON persistence.
const Map<String, IconData> kAppIcons = {
  // expense categories
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_car_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'bills': Icons.receipt_long_rounded,
  'health': Icons.favorite_rounded,
  'entertainment': Icons.movie_rounded,
  'education': Icons.school_rounded,
  'family': Icons.family_restroom_rounded,
  'travel': Icons.flight_rounded,
  'other': Icons.category_rounded,
  // income categories
  'salary': Icons.payments_rounded,
  'business': Icons.business_rounded,
  'freelance': Icons.laptop_rounded,
  'investment': Icons.trending_up_rounded,
  // accounts
  'cash': Icons.payments_rounded,
  'bank': Icons.account_balance_rounded,
  'jazzcash': Icons.phone_android_rounded,
  'easypaisa': Icons.smartphone_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
};

IconData appIcon(String key, [IconData fallback = Icons.category_rounded]) =>
    kAppIcons[key] ?? fallback;
