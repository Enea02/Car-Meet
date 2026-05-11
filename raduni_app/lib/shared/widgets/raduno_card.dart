import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/raduni/data/raduno_model.dart';

/// Card orizzontale compatta — replica la variante `compact` del design.
class RadunoCard extends StatelessWidget {
  final Raduno raduno;
  final VoidCallback? onTap;
  const RadunoCard({super.key, required this.raduno, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM', 'it_IT');
    final timeFmt = DateFormat('HH:mm', 'it_IT');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover 88×88
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: raduno.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: raduno.coverImageUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _imgPlaceholder(),
                      errorWidget: (_, __, ___) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
            const SizedBox(width: 12),

            // Content — no fixed height, grows with text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date · time · distance
                  Row(
                    children: [
                      Text(
                        dateFmt.format(raduno.startAt.toLocal()).toUpperCase(),
                        style: AppTheme.mono(
                          size: 11,
                          color: AppColors.accent,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: AppTheme.mono(
                            size: 11, color: AppColors.inkSubtle),
                      ),
                      Text(
                        timeFmt.format(raduno.startAt.toLocal()),
                        style: AppTheme.mono(
                            size: 11, color: AppColors.inkMuted),
                      ),
                      const Spacer(),
                      if (raduno.distanceKm != null)
                        Text(
                          '${raduno.distanceKm!.toStringAsFixed(0)} km',
                          style: AppTheme.mono(
                              size: 11, color: AppColors.inkSubtle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Title — 1 line to keep card compact
                  Text(
                    raduno.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Location
                  Text(
                    raduno.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom: price chip
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PriceChip(raduno: raduno),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 88,
        height: 88,
        color: AppColors.surfaceMuted,
        child: const Icon(Icons.directions_car_outlined,
            color: AppColors.inkSubtle, size: 28),
      );
}

class _PriceChip extends StatelessWidget {
  final Raduno raduno;
  const _PriceChip({required this.raduno});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = raduno.isFree
        ? ('Gratis', AppColors.surfaceMuted, AppColors.inkMuted)
        : (
            '€${raduno.entryPriceEuro.toStringAsFixed(0)}',
            AppColors.surfaceMuted,
            AppColors.ink
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
