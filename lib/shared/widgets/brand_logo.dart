import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 42,
    this.showSurface = false,
    this.padding = 5,
  });

  final double size;
  final bool showSurface;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final image = Padding(
      padding: EdgeInsets.all(padding),
      child: Image.asset(
        'assets/branding/logo_mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'YaLeCaigo',
      ),
    );

    if (!showSurface) {
      return SizedBox(width: size, height: size, child: image);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18073F43),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: image,
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 48,
    this.compact = false,
    this.textColor,
  });

  final double markSize;
  final bool compact;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.primaryDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (markSize > 0) ...[
          BrandMark(size: markSize),
          SizedBox(width: compact ? 7 : 11),
        ],
        Text(
          'YaLeCaigo',
          style: TextStyle(
            color: color,
            fontSize: compact ? 18 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({
    super.key,
    required this.title,
    this.showBrandName = false,
  });

  final String title;
  final bool showBrandName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 35, padding: 2),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            showBrandName ? 'YaLeCaigo' : title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
        ),
      ],
    );
  }
}

class OpenticAttribution extends StatelessWidget {
  const OpenticAttribution({
    super.key,
    this.imageWidth = 112,
    this.compact = false,
    this.textColor,
  });

  final double imageWidth;
  final bool compact;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textSecondary;
    final logo = Image.asset(
      'assets/branding/opentic_logo.png',
      width: imageWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Opentic, keep it simple',
    );

    if (compact) {
      return Semantics(
        label: 'Aplicación desarrollada por Opentic S.A.S.',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'by',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            logo,
            const SizedBox(width: 5),
            Text(
              '',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Aplicación desarrollada por Opentic S.A.S.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'by',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          logo,
          const SizedBox(height: 2),
          Text(
            '',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
