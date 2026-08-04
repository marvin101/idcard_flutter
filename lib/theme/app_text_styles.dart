import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const pageTitle = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const fieldLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(fontSize: 15, color: AppColors.textPrimary);

  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
}
