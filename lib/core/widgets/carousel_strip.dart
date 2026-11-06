import 'package:flutter/material.dart';
import '../theme/shadow_styles.dart';
import 'shadow_card.dart';

/// A compact horizontal strip slider for module sections
class CarouselStrip extends StatelessWidget {
  final List<Widget> items;
  final double height;
  final double itemWidth;
  final EdgeInsetsGeometry padding;
  final Function(int)? onItemTap;
  final String title;
  final IconData titleIcon;
  final VoidCallback? onSeeAllTap;

  const CarouselStrip({
    super.key,
    required this.items,
    this.height = 160,
    this.itemWidth = 220,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onItemTap,
    required this.title,
    required this.titleIcon,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Icon(titleIcon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (onSeeAllTap != null)
                TextButton(
                  onPressed: onSeeAllTap,
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => onItemTap?.call(index),
                child: SizedBox(
                  width: itemWidth,
                  child: ShadowCard(
                    shadowIntensity: ShadowIntensity.light,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: items[index],
                    ),
                    padding: const EdgeInsets.all(0),
                    borderRadius: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}