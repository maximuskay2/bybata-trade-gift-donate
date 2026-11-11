import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/haptic_utils.dart';
import 'living_slide.dart';
import 'stage_controller.dart';
import 'stage_photo_well.dart';
import 'swipe_commit.dart';

/// Full-bleed hub color, neighbor peek, docked card, swipe-down commit.
class LivingHeroStage extends StatefulWidget {
  final StageController controller;
  final Color stageColor;
  final List<LivingSlide> slides;
  final Future<StageCommitResult?> Function(LivingSlide slide) onCommit;
  final Widget Function(LivingSlide slide)? railBuilder;
  final Widget Function(LivingSlide slide)? actBuilder;
  final Widget Function(LivingSlide slide)? detailsBuilder;
  final Future<bool> Function(LivingSlide slide)? beforeBuilder;
  final Future<void> Function(LivingSlide slide)? onEdit;
  final Future<void> Function(LivingSlide slide)? onMessage;
  final Listenable? numberTick;
  final String Function()? numberText;
  final String commitLabel;
  final IconData markIcon;

  /// The offer rail fills the hero instead of sitting in a thin side column.
  final bool railIsFocus;

  const LivingHeroStage({
    super.key,
    required this.controller,
    required this.stageColor,
    required this.slides,
    required this.onCommit,
    this.railBuilder,
    this.actBuilder,
    this.detailsBuilder,
    this.beforeBuilder,
    this.onEdit,
    this.onMessage,
    this.numberTick,
    this.numberText,
    this.commitLabel = 'Offer this',
    this.markIcon = Icons.check_rounded,
    this.railIsFocus = false,
  });

  @override
  State<LivingHeroStage> createState() => _LivingHeroStageState();
}

class _LivingHeroStageState extends State<LivingHeroStage>
    with TickerProviderStateMixin {
  PageController? _page;
  final ScrollController _scroll = ScrollController();
  final SwipeCommitGate _gate = SwipeCommitGate();
  late final AnimationController _enter;
  late final AnimationController _goal;
  double _shrink = 0;
  double _drop = 0;
  double _lift = 0;
  double _stageHeight = 700;
  bool _lifting = false;
  String? _pickedSlide;
  int _pickedFrame = 0;
  bool _busy = false;
  int _karmaMarks = 0;
  bool _playGoal = false;
  bool _enterStarted = false;
  bool _closingRun = false;
  bool _reduceMotion = false;

  bool get _reduce => _reduceMotion;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _goal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _scroll.addListener(_onScroll);
    widget.controller.addListener(_onStage);
    _ensurePage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _enter.duration = Duration(milliseconds: _reduceMotion ? 160 : 560);
    _goal.duration = Duration(milliseconds: _reduceMotion ? 200 : 620);
    if (_enterStarted) return;
    _enterStarted = true;
    _enter.forward();
  }

  @override
  void didUpdateWidget(LivingHeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStage);
      widget.controller.addListener(_onStage);
    }
    if (oldWidget.slides.length != widget.slides.length) {
      _ensurePage(reset: true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStage);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _page?.dispose();
    _enter.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _onStage() {
    if (!mounted) return;
    if (widget.controller.isClosing && !_closingRun) {
      _closingRun = true;
      if (_reduceMotion) {
        widget.controller.finishClose();
      } else {
        _enter.reverse().whenComplete(() {
          if (mounted) widget.controller.finishClose();
        });
      }
    }
    if (widget.controller.showSuccess && _playGoal && !_goal.isAnimating) {
      _goal.forward(from: 0);
    }
    if (!widget.controller.showSuccess) {
      _playGoal = false;
      _karmaMarks = 0;
    }
    _syncPage();
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final next = (_scroll.offset / 160).clamp(0.0, 1.0);
    if ((next - _shrink).abs() < 0.02) return;
    setState(() => _shrink = next);
  }

  void _ensurePage({bool reset = false}) {
    final count = widget.slides.length;
    if (count == 0) return;
    final index = _indexOf(widget.controller.focusId);
    if (_page == null || reset) {
      _page?.dispose();
      _page = PageController(
        initialPage: index,
        viewportFraction: count > 1 ? 0.78 : 1,
      );
    }
  }

  int _indexOf(String? id) {
    final index = widget.slides.indexWhere((slide) => slide.id == id);
    return index < 0 ? 0 : index;
  }

  void _syncPage() {
    final page = _page;
    if (page == null || !page.hasClients || widget.controller.showBuilder) {
      return;
    }
    final index = _indexOf(widget.controller.focusId);
    final current = page.page?.round() ?? page.initialPage;
    if (current == index) return;
    if (_reduce) {
      page.jumpToPage(index);
      return;
    }
    page.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  LivingSlide? get _slide {
    if (widget.slides.isEmpty) return null;
    final id = widget.controller.focusId;
    for (final slide in widget.slides) {
      if (slide.id == id) return slide;
    }
    return widget.slides.first;
  }

  String _number(LivingSlide slide) {
    if (widget.controller.showBuilder && widget.numberText != null) {
      final custom = widget.numberText!();
      if (custom.isNotEmpty) return custom;
    }
    return slide.numberLabel;
  }

  Future<void> _primary(LivingSlide slide) async {
    if (slide.isOwner) {
      await widget.onEdit?.call(slide);
      return;
    }
    final allowed = await widget.beforeBuilder?.call(slide) ?? true;
    if (!allowed || !mounted) return;
    widget.controller.openBuilder();
  }

  Future<void> _commit(LivingSlide slide) async {
    if (_busy) return;
    setState(() => _busy = true);
    StageCommitResult? result;
    try {
      result = await _gate.run(() => widget.onCommit(slide));
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _drop = 0;
      });
      return;
    }
    if (!_reduce) {
      final start = _drop;
      for (var step = 1; step <= 8; step++) {
        if (!mounted) return;
        setState(() => _drop = start + (280 - start) * (step / 8));
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _karmaMarks = result!.karmaMarks;
      _playGoal = result.playGoalCheck;
    });
    widget.controller.markSuccess(result.line);
    if (_playGoal) _goal.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slide;
    final reduce = _reduce;
    return Material(
      color: widget.stageColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
              _stageHeight = constraints.maxHeight;
            }
            if (slide == null) return _missing();
            final enterCurve = CurvedAnimation(
              parent: _enter,
              curve: reduce ? Curves.linear : Curves.easeOutCubic,
            );
            final topFade = CurvedAnimation(
              parent: _enter,
              curve: reduce
                  ? Curves.linear
                  : const Interval(0.0, 0.45, curve: Curves.easeOut),
            );
            final dockFade = CurvedAnimation(
              parent: _enter,
              curve: reduce
                  ? Curves.linear
                  : const Interval(0.28, 1.0, curve: Curves.easeOutCubic),
            );
            return Stack(
              children: [
                if (!reduce &&
                    widget.controller.origin != null &&
                    _enter.value < 0.95)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: ReverseAnimation(enterCurve),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 14 * (1 - _enter.value),
                          sigmaY: 14 * (1 - _enter.value),
                        ),
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: 0.18 * (1 - _enter.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                Column(
                  children: [
                    FadeTransition(opacity: topFade, child: _topBar()),
                    Expanded(child: _heroBand(slide, reduce)),
                    FadeTransition(
                      opacity: dockFade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(dockFade),
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: reduce ? 160 : 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slideUp = Tween<Offset>(
                              begin: const Offset(0, 0.12),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slideUp,
                                child: child,
                              ),
                            );
                          },
                          layoutBuilder: (current, previous) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(
                              widget.controller.showSuccess
                                  ? 'success'
                                  : widget.controller.showBuilder
                                  ? 'builder'
                                  : 'dock',
                            ),
                            child: widget.controller.showSuccess
                                ? _success(slide)
                                : widget.controller.showBuilder
                                ? _builderCard(slide)
                                : _dock(slide),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.controller.showDetails)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _enter,
                      child: _detailsSheet(slide),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _missing() {
    return Align(alignment: Alignment.topLeft, child: _backChip());
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          _backChip(),
          const Spacer(),
          Text(
            'BYBATA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backChip() {
    return TextButton.icon(
      onPressed: widget.controller.back,
      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
      label: const Text(
        'BACK',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _heroBand(LivingSlide slide, bool reduce) {
    Widget band() {
      final enter = reduce ? 1.0 : Curves.easeOutCubic.transform(_enter.value);
      final enterSpring = reduce
          ? enter
          : Curves.easeOutBack.transform(enter.clamp(0.0, 1.0));
      final grow = reduce || widget.controller.origin == null
          ? 1.0
          : (0.18 + 0.82 * enterSpring);
      final sink = reduce ? 1.0 : (1 - (_drop / 340)).clamp(0.22, 1.0);
      final scale = reduce
          ? 1.0
          : (widget.controller.showBuilder ? 0.92 : (1 - 0.18 * _shrink));
      final cover = widget.controller.showBuilder ? 0.94 : (1 - 0.08 * _lift);
      final photoScale = reduce
          ? 1.0
          : scale * (0.82 + 0.18 * enterSpring) * grow * sink * cover;
      final drop = reduce ? 0.0 : _drop;
      final flight = _flight(enter);
      final number = _number(slide);
      final focusOffer =
          widget.controller.showBuilder &&
          widget.railIsFocus &&
          widget.railBuilder != null;
      final stage = focusOffer
          ? _offerStage(slide, number)
          : _photoColumn(
              slide,
              number,
              reduce,
              enter,
              photoScale,
              drop,
              flight,
            );
      return AnimatedSwitcher(
        duration: Duration(milliseconds: reduce ? 150 : 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) {
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [...previous, if (current != null) current],
          );
        },
        transitionBuilder: (child, animation) {
          final slideUp = Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slideUp, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(focusOffer ? 'offer-focus' : 'hero-photo'),
          child: stage,
        ),
      );
    }

    final tick = widget.numberTick;
    return AnimatedBuilder(
      animation: tick == null ? _enter : Listenable.merge([_enter, tick]),
      builder: (context, _) => band(),
    );
  }

  Widget _offerStage(LivingSlide slide, String number) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                height: 108,
                child: StagePhotoWell(
                  imageKey: _shownKey(slide),
                  color: widget.stageColor,
                  radius: 22,
                  inset: 8,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theirs',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    if (number.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        number,
                        key: const Key('living-stage-number'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: widget.railBuilder!(slide)),
      ],
    );
  }

  Widget _photoColumn(
    LivingSlide slide,
    String number,
    bool reduce,
    double enter,
    double photoScale,
    double drop,
    Offset flight,
  ) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              if (widget.controller.showBuilder && widget.railBuilder != null)
                SizedBox(width: 84, child: widget.railBuilder!(slide)),
              Expanded(
                child: Transform.translate(
                  offset: Offset(flight.dx, flight.dy + drop),
                  child: Transform.scale(
                    scale: photoScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!reduce &&
                            widget.controller.origin != null &&
                            enter < 0.94)
                          Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFFE8C872,
                                ).withValues(alpha: (1 - enter).clamp(0, 1)),
                                width: 2 + 8 * (1 - enter),
                              ),
                            ),
                          ),
                        widget.controller.showBuilder ||
                                widget.slides.length < 2
                            ? _photo(_shownKey(slide))
                            : _pager(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (number.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _numberLabel(number),
          ),
      ],
    );
  }

  Offset _flight(double enter) {
    final origin = widget.controller.origin;
    if (origin == null || enter >= 0.99) return Offset.zero;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Offset.zero;
    final from = box.globalToLocal(origin.center);
    final home = Offset(box.size.width / 2, box.size.height * 0.34);
    return (from - home) * (1 - enter);
  }

  Widget _numberLabel(String number) {
    final reduce = _reduce;
    return AnimatedSwitcher(
      key: const Key('living-stage-number'),
      duration: Duration(milliseconds: reduce ? 80 : 280),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        number,
        key: ValueKey(number),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
    );
  }

  Widget _pager() {
    final page = _page;
    final focused = _slide;
    if (page == null) {
      return _photo(focused == null ? null : _shownKey(focused));
    }
    return PageView.builder(
      key: const Key('living-stage-pager'),
      controller: page,
      itemCount: widget.slides.length,
      onPageChanged: (index) {
        final slide = widget.slides[index];
        widget.controller.focus(slide.id);
        HapticUtils.selection();
      },
      itemBuilder: (context, index) {
        final item = widget.slides[index];
        final key = item.id == focused?.id ? _shownKey(item) : item.imageKey;
        return _photo(key);
      },
    );
  }

  Widget _photo(String? key) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
      child: StagePhotoWell(
        imageKey: key,
        color: widget.stageColor,
        radius: 36,
        inset: 16,
      ),
    );
  }

  List<String> _framesOf(LivingSlide slide) {
    final frames = <String>[];
    void add(String? raw) {
      final key = raw?.trim() ?? '';
      if (key.isEmpty || frames.contains(key)) return;
      frames.add(key);
    }

    final image = slide.imageKey?.trim() ?? '';
    final imageRemote = image.isNotEmpty && stageImageIsRemote(image);
    // Storage keys first. A resolved preview URL is only a last resort so the
    // first hero frame matches a strip thumb that CachedMediaImage can load.
    if (!imageRemote) add(image);
    for (final key in slide.galleryKeys) {
      add(key);
    }
    if (frames.isEmpty && imageRemote) add(image);
    return frames;
  }

  String? _shownKey(LivingSlide slide) {
    final frames = _framesOf(slide);
    if (frames.isEmpty) return slide.imageKey;
    if (_pickedSlide != slide.id) return frames.first;
    return frames[_pickedFrame.clamp(0, frames.length - 1)];
  }

  double _dockExtent() {
    final available = (_stageHeight - 52).clamp(0.0, 4000.0);
    final collapsed = available < 328 ? available : 328.0;
    final expanded = available * 0.92;
    final span = expanded > collapsed ? expanded : collapsed;
    return collapsed + (span - collapsed) * _lift;
  }

  Widget _dock(LivingSlide slide) {
    final height = _dockExtent();
    final tint = Color.lerp(Colors.white, widget.stageColor, 0.07)!;
    return AnimatedContainer(
      duration: _lifting || _reduce
          ? Duration.zero
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.stageColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.stageColor.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _detailsHandle(),
          _frameStrip(slide),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text(
                  slide.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                if (slide.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _primaryButton(slide),
                if (slide.story.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(slide.story, style: const TextStyle(height: 1.45)),
                ],
                if (slide.place.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    slide.place,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (slide.want.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(slide.want, style: const TextStyle(height: 1.4)),
                ],
                if (widget.slides.length > 1) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Similar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  for (final other
                      in widget.slides
                          .where((item) => item.id != slide.id)
                          .take(6))
                    _similarRow(
                      other,
                      onTap: () => widget.controller.focus(other.id),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _frameStrip(LivingSlide slide) {
    final frames = _framesOf(slide);
    if (frames.isEmpty) return const SizedBox(height: 4);
    final picked = _pickedSlide == slide.id ? _pickedFrame : 0;
    final active = picked.clamp(0, frames.length - 1);
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: frames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _pickedSlide = slide.id;
                _pickedFrame = index;
              });
            },
            child: SizedBox(
              width: 92,
              height: 92,
              child: StagePhotoWell(
                imageKey: frames[index],
                color: widget.stageColor,
                radius: 18,
                inset: 6,
                lit: index == active,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _similarRow(LivingSlide other, {required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              other.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (other.subtitle.isNotEmpty)
              Text(
                other.subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(LivingSlide slide) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('living-primary'),
        onPressed: () => _primary(slide),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        child: Text(
          slide.primaryLabel,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }

  void _setLift(double next) {
    setState(() => _lift = next.clamp(0.0, 1.0));
  }

  Widget _detailsHandle() {
    final open = _lift > 0.5;
    return GestureDetector(
      key: const Key('living-details-handle'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _setLift(open ? 0 : 1),
      onVerticalDragStart: _reduce
          ? null
          : (_) => setState(() => _lifting = true),
      onVerticalDragUpdate: _reduce
          ? null
          : (details) {
              final available = (_stageHeight - 52).clamp(1.0, 4000.0);
              final collapsed = available < 328 ? available : 328.0;
              final span = (available * 0.92 - collapsed).abs().clamp(
                1.0,
                4000.0,
              );
              _setLift(_lift + (-details.delta.dy) / span);
            },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        setState(() => _lifting = false);
        if (velocity < -180) {
          _setLift(1);
        } else if (velocity > 180) {
          _setLift(0);
        } else if (!_reduce) {
          _setLift(_lift >= 0.45 ? 1 : 0);
        }
      },
      onVerticalDragCancel: () => setState(() => _lifting = false),
      child: SizedBox(
        height: 46,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 118,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    open
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _builderCard(LivingSlide slide) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slide.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (widget.onMessage != null && !slide.isOwner)
                  IconButton(
                    tooltip: 'Message',
                    onPressed: () => widget.onMessage!(slide),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
              ],
            ),
            if (widget.actBuilder != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(child: widget.actBuilder!(slide)),
              ),
            const SizedBox(height: 8),
            SwipeCommitControl(
              label: widget.commitLabel,
              busy: _busy,
              accent: widget.stageColor,
              onCommit: () => _commit(slide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final tint = Color.lerp(Colors.white, widget.stageColor, 0.08)!;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.52,
      ),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.stageColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.stageColor.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _detailsSheet(LivingSlide slide) {
    final glass = _glassOn(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.controller.back,
              child: const Text('Back to item'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _frameStrip(slide),
        if (widget.detailsBuilder != null)
          widget.detailsBuilder!(slide)
        else ...[
          if (slide.ownerName.isNotEmpty)
            Text(
              'Owner · ${slide.ownerName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if (slide.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(slide.subtitle),
          ],
          if (slide.place.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(slide.place),
          ],
          if (slide.story.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(slide.story, style: const TextStyle(height: 1.4)),
          ],
          if (slide.want.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(slide.want),
          ],
        ],
        const SizedBox(height: 16),
        const Text('Similar', style: TextStyle(fontWeight: FontWeight.w900)),
        for (final other
            in widget.slides.where((item) => item.id != slide.id).take(4))
          _similarRow(
            other,
            onTap: () {
              widget.controller.focus(other.id);
              widget.controller.back();
            },
          ),
      ],
    );
    final sheet = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: body,
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: _stageHeight * 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: glass
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.86),
                    child: sheet,
                  ),
                )
              : ColoredBox(color: Colors.white, child: sheet),
        ),
      ),
    );
  }

  bool _glassOn(BuildContext context) {
    try {
      return context.watch<ThemeProvider>().isGlassModeEnabled;
    } catch (_) {
      return false;
    }
  }

  Widget _success(LivingSlide slide) {
    final line = widget.controller.successLine ?? '';
    final check = _playGoal
        ? ScaleTransition(
            scale: CurvedAnimation(parent: _goal, curve: Curves.easeOutBack),
            child: _checkIcon(),
          )
        : _checkIcon();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        children: [
          Text(
            line,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          check,
          const SizedBox(height: 12),
          Icon(widget.markIcon, color: Colors.white, size: 28),
          if (_karmaMarks > 0) _KarmaBurst(count: _karmaMarks),
          Text(
            slide.title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _checkIcon() {
    return const Icon(
      Icons.check_circle_rounded,
      color: AppColors.success,
      size: 72,
    );
  }
}

class _KarmaBurst extends StatefulWidget {
  final int count;

  const _KarmaBurst({required this.count});

  @override
  State<_KarmaBurst> createState() => _KarmaBurstState();
}

class _KarmaBurstState extends State<_KarmaBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            children: [
              for (var i = 0; i < widget.count; i++)
                Align(
                  alignment: Alignment(-0.2 + (i - 3.5) * 0.08, 1 - t),
                  child: Opacity(
                    opacity: (1 - t).clamp(0, 1),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
