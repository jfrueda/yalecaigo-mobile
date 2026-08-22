import 'package:flutter/material.dart';

import '../../core/branding/app_branding.dart';
import '../../core/theme/app_colors.dart';

class AppBrandHeader extends StatelessWidget {
  const AppBrandHeader({super.key, this.compact = false, this.showName = true});

  final bool compact;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 82.0 : 128.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Símbolo de ${AppBranding.appName}',
          child: Image.asset(
            AppBranding.markAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.shield_outlined,
              size: size * 0.70,
              color: AppColors.primary,
            ),
          ),
        ),
        if (showName) ...[
          SizedBox(height: compact ? 7 : 11),
          Text(
            AppBranding.appName,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.headlineMedium)
                    ?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
          ),
          const SizedBox(height: 4),
          Text(
            AppBranding.tagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class AppBrandAppBarTitle extends StatelessWidget {
  const AppBrandAppBarTitle({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final normalizedLabel = label?.trim() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppBranding.markAsset,
          width: 35,
          height: 35,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.shield_outlined, color: AppColors.primary),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            normalizedLabel.isEmpty
                ? AppBranding.appName
                : '${AppBranding.appName} · $normalizedLabel',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class AppBrandInlineBanner extends StatelessWidget {
  const AppBrandInlineBanner({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Image.asset(
            AppBranding.markAsset,
            width: 55,
            height: 55,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.shield_outlined,
              size: 42,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OpenticFooter extends StatelessWidget {
  const OpenticFooter({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aplicación desarrollada por ${AppBranding.developerName}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Desarrollado por',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          SizedBox(height: compact ? 3 : 5),
          Image.asset(
            AppBranding.developerLogoAsset,
            height: compact ? 28 : 38,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => const Text(
              AppBranding.developerName,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
