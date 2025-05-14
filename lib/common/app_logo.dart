
import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double logoSymbolSize;
  final double appNameFontSize;
  final bool showAppName;
  final Color symbolColor;
  final Color symbolBackgroundColor;
  final Color appNameColor;

  const AppLogo({
    super.key,
    this.logoSymbolSize = 50.0,
    this.appNameFontSize = 28.0,
    this.showAppName = false,
    this.symbolColor = Colors.white,
    this.symbolBackgroundColor = Colors.black,
    this.appNameColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoSymbol = Container(
      width: logoSymbolSize,
      height: logoSymbolSize,
      decoration: BoxDecoration(
        color: symbolBackgroundColor,
        borderRadius: BorderRadius.circular(logoSymbolSize * 0.22),
      ),
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            fontFamily: 'Arial', 
            color: symbolColor,
            fontSize: logoSymbolSize * 0.65,
            fontWeight: FontWeight.w900,
            height: 1.0, 
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (!showAppName) {
      return logoSymbol;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoSymbol,
        const SizedBox(height: 10),
        Text(
          'NIVARAN',
          style: TextStyle(
            fontSize: appNameFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: appNameColor,
          ),
        ),
      ],
    );
  }
}