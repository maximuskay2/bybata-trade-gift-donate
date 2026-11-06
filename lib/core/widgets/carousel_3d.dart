import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:bybata/core/utils/media_utils.dart';
import '../theme/shadow_styles.dart';
import '../theme/theme_provider.dart';
import 'shadow_card.dart';
import '../utils/media_utils.dart';

/// A 3D carousel widget for displaying cards with smooth sliding animations
class Carousel3D extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final double itemWidth;
  final EdgeInsetsGeometry padding;
  final Function(int)? onItemTap;
  final String title;
  final IconData titleIcon;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onEndReached;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration animationDuration;
  final double viewportFraction;

  const Carousel3D({
    super.key,
    required this.items,
    this.height = 200,
    this.itemWidth = 280,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onItemTap,
    required this.title,
    required this.titleIcon,
    this.onSeeAllTap,
    this.onEndReached,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 300),
    this.viewportFraction = 0.85,
  });

  @override
  State<Carousel3D> createState() => _Carousel3DState();
}

class _Carousel3DState extends State<Carousel3D>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: widget.viewportFraction,
    );
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    if (widget.autoPlay && widget.items.isNotEmpty) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval).then((_) {
      if (mounted && widget.items.isNotEmpty) {
        final nextIndex = (_currentIndex + 1) % widget.items.length;
        _pageController.animateToPage(
          nextIndex,
          duration: widget.animationDuration,
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: widget.padding,
          child: _buildSectionHeader(context),
        ),
        const SizedBox(height: 16),
        
        // 3D Carousel
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (widget.onEndReached != null && index == widget.items.length - 1) {
            widget.onEndReached!();
          }
        },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                  } else {
                    value = index == 0 ? 1.0 : 0.7;
                  }

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(value == 1 ? 0 : (index > _currentIndex ? -0.3 : 0.3) * (1 - value))
                      ..scale(value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 20 * (1 - value),
                        ),
                        child: _build3DCard(context, widget.items[index], index, value),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Page Indicators
        const SizedBox(height: 16),
        _buildPageIndicators(context),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          widget.titleIcon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (widget.onSeeAllTap != null)
          TextButton(
            onPressed: widget.onSeeAllTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('See All'),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _build3DCard(BuildContext context, Widget item, int index, double value) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return GestureDetector(
      onTap: () {
        if (widget.onItemTap != null) {
          widget.onItemTap!(index);
        }
      },
      child: Container(
        width: widget.itemWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: ShadowStyles.getThemeAwareShadow(
            context,
            isGlass: themeProvider.isGlassTheme,
            intensity: value > 0.8 ? ShadowIntensity.heavy : ShadowIntensity.medium,
          ).map((shadow) => BoxShadow(
            color: shadow.color.withValues(alpha: shadow.color.a * value),
            offset: shadow.offset * value,
            blurRadius: shadow.blurRadius * value,
            spreadRadius: shadow.spreadRadius,
          )).toList(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: item,
        ),
      ),
    );
  }

  Widget _buildPageIndicators(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => AnimatedContainer(
              duration: widget.animationDuration,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: widget.padding,
          child: _buildSectionHeader(context),
        ),
        const SizedBox(height: 16),
        Container(
          height: widget.height,
          margin: widget.padding,
          child: ShadowCard(
            shadowIntensity: ShadowIntensity.light,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.titleIcon,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.title.toLowerCase()} available yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to add something!',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Data models for carousel items
class CarouselItem {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final IconData? icon;
  final Color? color;
  final Map<String, dynamic>? metadata;

  const CarouselItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.icon,
    this.color,
    this.metadata,
  });
}

/// Pre-built card widgets for different modules
class TradeCard extends StatelessWidget {
  final CarouselItem item;
  
  const TradeCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: _TradeImage(url: item.imageUrl),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeImage extends StatelessWidget {
  final String? url;
  const _TradeImage({required this.url});

  @override
  Widget build(BuildContext context) {
    // Use a consistent aspect ratio. If there’s no image URL, show a soft placeholder.
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFEFF2F7)),
        child: () {
          final u = url;
          final showNet = u != null && u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://'));
          if (!showNet) return _PlaceholderGraphic();
          return CachedNetworkImage(
            imageUrl: u!,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _PlaceholderGraphic(),
          );
        }(),
      ),
    );
  }
}

class _PlaceholderGraphic extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image,
        size: 48,
        color: Colors.grey[500],
      ),
    );
  }
}

class DonationCard extends StatelessWidget {
  final CarouselItem item;
  
  const DonationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final progress = (item.metadata?['progress'] ?? 0.0) as double;
    final supporters = (item.metadata?['supporters'] ?? 0) as int;
    final location = (item.metadata?['location'] ?? '') as String;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top image with location chip
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Stack(
              children: [
                _DonationImage(url: item.imageUrl),
                if (location.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            location,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content panel
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // People donated row
                Row(
                  children: [
                    _DonorAvatars(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${supporters.toString()}+ people Donated',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Title
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Raised label and percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Raised', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationImage extends StatelessWidget {
  final String? url;
  const _DonationImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 95,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF4F6FB)),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (url == null || url!.isEmpty) {
      return _PlaceholderGraphic();
    }
    final value = url!;
    final isAbsolute = value.startsWith('http://') || value.startsWith('https://');
    if (isAbsolute) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _PlaceholderGraphic(),
      );
    }
    // Resolve storage key to absolute URL asynchronously
    return FutureBuilder<String?>
      (future: MediaResolver.resolveUrl(value),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) return _PlaceholderGraphic();
        final showNet = resolved != null && (resolved.startsWith('http://') || resolved.startsWith('https://'));
        if (!showNet) return _PlaceholderGraphic();
        return Image.network(
          resolved!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _PlaceholderGraphic(),
        );
      },
    );
  }
}

class _DonorAvatars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Container(
          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 14, color: Colors.black54),
          ),
        );
      }),
    );
  }
}

class CommunityCard extends StatelessWidget {
  final CarouselItem item;
  
  const CommunityCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final handle = (item.metadata?['handle'] ?? '@bybata_user') as String;
    final likes = (item.metadata?['likes'] ?? 0) as int;
    final comments = (item.metadata?['comments'] ?? 0) as int;
    final views = (item.metadata?['views'] ?? 0) as int;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: avatar, name, handle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange[200],
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        handle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // Image
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: FutureBuilder<String?>(
                    future: MediaResolver.resolveUrl(item.imageUrl),
                    builder: (context, snapshot) {
                      final resolved = snapshot.data;
                      final showNet = resolved != null && (resolved.startsWith('http://') || resolved.startsWith('https://'));
                      if (!showNet) return _PlaceholderGraphic();
                      return CachedNetworkImage(
                        imageUrl: resolved!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => _PlaceholderGraphic(),
                      );
                    },
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Metrics row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _Metric(icon: Icons.favorite, color: Colors.pink, label: _fmt(likes)),
                const SizedBox(width: 14),
                _Metric(icon: Icons.chat_bubble, color: Colors.grey, label: _fmt(comments)),
                const SizedBox(width: 14),
                _Metric(icon: Icons.visibility, color: Colors.grey, label: _fmt(views)),
                const Spacer(),
                Icon(Icons.share, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Metric({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class GiftCard extends StatelessWidget {
  final CarouselItem item;
  
  const GiftCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: _GiftImage(url: item.imageUrl),
          ),
          // Content panel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber[500],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Text(
                        'VIEW',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
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
    );
  }
}

class _GiftImage extends StatelessWidget {
  final String? url;
  const _GiftImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 98,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF4F6FB)),
        child: url == null || url!.isEmpty
            ? _PlaceholderGraphic()
            : FutureBuilder<String?>(
                future: MediaResolver.resolveUrl(url),
                builder: (context, snapshot) {
                  final resolved = snapshot.data;
                  final showNet = resolved != null && (resolved.startsWith('http://') || resolved.startsWith('https://'));
                  if (!showNet) return _PlaceholderGraphic();
                  return Image.network(
                    resolved!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _PlaceholderGraphic(),
                  );
                },
              ),
      ),
    );
  }
}

class AdCard extends StatelessWidget {
  final CarouselItem item;
  
  const AdCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.amber.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          
          // Sponsored badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'SPONSORED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.campaign,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            item.metadata?['cta'] ?? 'Learn More',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
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
    );
  }
}
