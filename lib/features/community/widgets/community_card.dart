import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/media_utils.dart';
import 'package:bybata/core/theme/app_theme.dart';

class CommunityCard extends StatelessWidget {
  final String id;
  final String name;
  final String? avatarUrl;
  final String description;
  final double distanceKm;
  final bool inRange;
  final VoidCallback? onJoin;
  final VoidCallback onOpen;
  final bool isJoined;

  const CommunityCard({
    super.key,
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.description,
    required this.distanceKm,
    required this.inRange,
    this.onJoin,
    required this.onOpen,
    this.isJoined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.brightness == Brightness.dark 
        ? Colors.grey[400]! 
        : Colors.grey[600]!;
    final errorColor = Colors.red[400]!;

    return Semantics(
      button: true,
      label: 'Open community $name',
      child: InkWell(
        onTap: inRange ? onOpen : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.brightness == Brightness.dark 
                  ? Colors.grey[800]! 
                  : Colors.grey[200]!,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String?>(
                future: MediaResolver.resolveUrl(avatarUrl),
                builder: (context, snapshot) {
                  final resolved = snapshot.data;
                  final showNet = resolved != null && 
                      (resolved.startsWith('http://') || 
                       resolved.startsWith('https://'));
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: inRange 
                        ? Colors.orange[200] 
                        : errorColor.withValues(alpha: 0.3),
                    child: showNet
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: resolved!,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                              errorWidget: (context, url, error) => Icon(
                                Icons.groups,
                                color: inRange ? Colors.white : errorColor,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.groups,
                            color: inRange ? Colors.white : errorColor,
                          ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: inRange ? inactiveColor : errorColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 16,
                          color: inRange ? inactiveColor : errorColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            inRange 
                                ? '${distanceKm.toStringAsFixed(1)} km away' 
                                : 'Out of range (${distanceKm.toStringAsFixed(1)} km)',
                            style: TextStyle(
                              fontSize: 12,
                              color: inRange ? inactiveColor : errorColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onJoin != null || isJoined)
                          Semantics(
                            button: true,
                            enabled: inRange || isJoined,
                            label: isJoined
                                ? 'Explore community $name'
                                : inRange 
                                    ? 'Join community $name' 
                                    : 'Out of range',
                            child: ElevatedButton(
                              onPressed: isJoined ? onOpen : (inRange ? onJoin : null),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                backgroundColor: isJoined
                                    ? AppColors.primary
                                    : inRange 
                                        ? null 
                                        : errorColor.withValues(alpha: 0.3),
                              ),
                              child: Text(
                                isJoined 
                                    ? 'Explore' 
                                    : inRange 
                                        ? 'Join' 
                                        : 'Out of Range',
                                style: TextStyle(
                                  color: isJoined 
                                      ? Colors.white 
                                      : inRange 
                                          ? null 
                                          : errorColor,
                                ),
                              ),
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
      ),
    );
  }
}

