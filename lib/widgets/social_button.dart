// lib/widgets/social_button.dart
import 'package:flutter/material.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final String iconAssetPath;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double height;
  final double? width;

  const SocialButton({
    super.key,
    required this.text,
    required this.iconAssetPath,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor = const Color(0xFFFFFFFF), // White background
    this.textColor = Colors.black87,                // Black text
    this.borderColor = const Color(0xFFD0D0D0),     // Light grey border
    this.height = 50.0,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: Colors.grey[200],
          foregroundColor: textColor,
          elevation: 1, 
          shadowColor: Colors.grey.withAlpha(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Match AuthButton
            side: BorderSide(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500, 
          ),
        ),
        icon: isLoading
            ? const SizedBox.shrink()
            : Image.asset(iconAssetPath, height: 20.0, width: 20.0),
        label: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Text(text), // Google button text usually not uppercase
      ),
    );
  }
}