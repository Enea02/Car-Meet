import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/distance_formatter.dart';
import '../../features/raduni/data/raduno_model.dart';

class RadunoCard extends StatelessWidget {
  final Raduno raduno;
  final VoidCallback? onTap;
  const RadunoCard({super.key, required this.raduno, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM • HH:mm', 'it_IT');
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (raduno.coverImageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: raduno.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black12),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black12,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(raduno.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 6),
                      Text(dateFmt.format(raduno.startAt.toLocal())),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          raduno.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (raduno.distanceKm != null)
                        Text(
                          DistanceFormatter.format(raduno.distanceKm!),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: raduno.isFree
                              ? Colors.green.withValues(alpha: 0.15)
                              : Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          raduno.isFree
                              ? 'Gratuito'
                              : '${raduno.entryPriceEuro.toStringAsFixed(2)} €',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
