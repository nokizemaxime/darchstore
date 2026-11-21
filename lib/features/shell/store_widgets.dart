import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../catalog/domain/catalog_logic.dart';

class AppMark extends StatelessWidget {
  const AppMark({required this.name, this.iconUrl, this.size = 56, super.key});

  final String name;
  final String? iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final fallback = _FallbackMark(name: name, size: size);
    final url = iconUrl;
    return Semantics(
      label: 'Icône de $name',
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: (size * 3).round(),
                  placeholder: (context, url) => fallback,
                  errorWidget: (context, url, error) => fallback,
                ),
        ),
      ),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();
    return ColoredBox(
      color: _color(name),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Color _color(String value) {
    const palette = [
      AppColors.copper,
      AppColors.sage,
      Color(0xFF8AA4C4),
      Color(0xFFD08A7A),
      Color(0xFFD2B56A),
      Color(0xFFB4A0D4),
    ];
    final index = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[index % palette.length];
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final ReleaseStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReleaseStatus.updateAvailable => AppColors.sage,
      ReleaseStatus.notInstalled => AppColors.copper,
      ReleaseStatus.upToDate || ReleaseStatus.installedNewer => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        releaseStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StoreMessage extends StatelessWidget {
  const StoreMessage({
    required this.title,
    required this.body,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.copper, size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.parchment,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
