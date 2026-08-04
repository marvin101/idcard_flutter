import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  final IconData? icon;

  final bool loading;

  final double width;

  final double height;

  final Color? backgroundColor;

  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.width = double.infinity,
    this.height = 50,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,

      child: ElevatedButton(
        onPressed: loading ? null : onPressed,

        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : icon == null
            ? Text(text)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(icon), const SizedBox(width: 8), Text(text)],
              ),
      ),
    );
  }
}
