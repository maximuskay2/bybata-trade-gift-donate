import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/listing_media.dart';
import '../../../core/services/listing_media_upload_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/listing_create_shell.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/edit_form_scaffold.dart';
import '../../../core/widgets/editable_listing_media_picker.dart';
import '../../../core/widgets/enhanced_form_field.dart';
import '../../../core/widgets/preference_radio_group.dart';
import '../../../core/widgets/smart_type_selector.dart';
import '../../karma/providers/karma_provider.dart';
import '../models/trade_models.dart';
import '../providers/trade_backend_provider.dart';
import 'create_trade_screen.dart' show DeliveryPreference;

class EditTradeScreen extends StatefulWidget {
  final Trade trade;

  const EditTradeScreen({super.key, required this.trade});

  @override
  State<EditTradeScreen> createState() => _EditTradeScreenState();
}

class _EditTradeScreenState extends State<EditTradeScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TradeCategory _selectedCategory;
  late DeliveryPreference _deliveryPreference;
  late bool _isNegotiable;
  late bool _enableBYCPromotion;
  late EditableListingMediaState _mediaState;

  bool _isLoading = false;
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final t = widget.trade;
    _titleController = TextEditingController(text: t.title);
    _descriptionController = TextEditingController(text: t.description);
    _selectedCategory = t.category;
    _isNegotiable = t.isNegotiable;
    _enableBYCPromotion = t.enableBYCPromotion;
    _mediaState = EditableListingMediaState.fromExisting(t.listingMedia);
    _deliveryPreference = t.allowPickup
        ? DeliveryPreference.pickupOnly
        : DeliveryPreference.mixed;
    _initialSnapshot = _snapshot();
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  String _snapshot() {
    return [
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      _selectedCategory.name,
      _deliveryPreference.name,
      _isNegotiable,
      _enableBYCPromotion,
      _mediaState.mediaType.name,
      _mediaState.keptImageKeys.join('|'),
      _mediaState.keptVideoKey ?? '',
      _mediaState.newImageFiles.length,
      _mediaState.newVideoPath ?? '',
    ].join('::');
  }

  bool get _isDirty => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_titleController.text.trim().isEmpty) {
      AppToast.error(context, 'Title is required');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      AppToast.error(context, 'Description is required');
      return false;
    }
    if (!_mediaState.hasMedia) {
      AppToast.error(context, 'Add at least one photo or a video');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    try {
      final provider = context.read<TradeBackendProvider>();
      final requiresPickup = _deliveryPreference == DeliveryPreference.pickupOnly;
      final allowDelivery = _deliveryPreference == DeliveryPreference.mixed;

      final mediaPayload = await ListingMediaUploadService.resolveEditMediaForApi(
        state: _mediaState,
        domain: 'trades',
      );

      final ok = await provider.updateTrade(
        tradeId: widget.trade.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        mediaType: mediaPayload['mediaType'] as String?,
        mediaKeys: (mediaPayload['mediaKeys'] as List?)?.cast<String>(),
        videoKey: mediaPayload['videoKey'] as String?,
        thumbnailKey: mediaPayload['thumbnailKey'] as String?,
        category: _selectedCategory.name.toUpperCase(),
        isNegotiable: _isNegotiable,
        requiresPickup: requiresPickup,
        allowDelivery: allowDelivery,
        allowShipping: false,
        enableBYCPromotion: _enableBYCPromotion,
      );

      if (!mounted) return;
      if (ok) {
        final karma = context.read<KarmaProvider>();
        await karma.addTransaction(
          15,
          'trade_update',
          'Updated trade: ${_titleController.text.trim()}',
        );
        AppToast.success(context, 'Trade updated');
        Navigator.of(context).pop(true);
      } else {
        AppToast.error(context, provider.error ?? 'Failed to update trade');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.tradeColor;

    return EditFormScaffold(
      title: 'Edit Trade',
      subtitle: 'Update photos, details, and how people can get your item.',
      accentColor: accent,
      discardItemLabel: 'trade',
      isLoading: _isLoading,
      isDirty: _isDirty,
      onSave: _save,
      swipeCommitLabel: 'Save Trade',
      onSwipeCommit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditFormCard(
            title: 'Listing',
            subtitle: 'What you are offering',
            icon: Icons.storefront_rounded,
            accentColor: accent,
            child: Column(
              children: [
                EditableListingMediaPicker(
                  accentColor: accent,
                  compact: true,
                  moduleLabel: 'trade',
                  initialExisting: widget.trade.listingMedia,
                  onChanged: (state) => setState(() => _mediaState = state),
                ),
                const EditFormDivider(),
                EnhancedFormField(
                  controller: _titleController,
                  label: 'Title',
                  hint: 'What are you trading?',
                  isRequired: true,
                  isDark: isDark,
                  minLength: 3,
                ),
                const SizedBox(height: 16),
                SmartTypeSelector<TradeCategory>(
                  selectedValue: _selectedCategory,
                  options: TradeCategory.values
                      .map(
                        (cat) => TypeOption(
                          value: cat,
                          label: _categoryLabel(cat),
                          icon: _categoryIcon(cat),
                        ),
                      )
                      .toList(),
                  onSelected: (c) => setState(() => _selectedCategory = c),
                  isDark: isDark,
                  primaryColor: accent,
                  title: 'Category',
                  layout: SmartTypeSelectorLayout.chips,
                ),
                const EditFormDivider(),
                EnhancedFormField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Condition, history, what is included…',
                  isRequired: true,
                  maxLines: 5,
                  isDark: isDark,
                  minLength: 10,
                ),
              ],
            ),
          ),
          EditFormCard(
            title: 'Exchange options',
            subtitle: 'How buyers connect with you',
            icon: Icons.swap_horiz_rounded,
            accentColor: accent,
            child: Column(
              children: [
                PreferenceRadioGroup<DeliveryPreference>(
                  selectedValue: _deliveryPreference,
                  options: [
                    PreferenceOption(
                      value: DeliveryPreference.pickupOnly,
                      label: 'Pickup only',
                      description: 'Meet locally to exchange',
                      icon: Icons.location_on_rounded,
                    ),
                    PreferenceOption(
                      value: DeliveryPreference.mixed,
                      label: 'Flexible',
                      description: 'Pickup or delivery',
                      icon: Icons.local_shipping_rounded,
                    ),
                  ],
                  onChanged: (v) => setState(() => _deliveryPreference = v),
                  isDark: isDark,
                  primaryColor: accent,
                  title: 'Handoff',
                ),
                const EditFormDivider(),
                ListingEditToggleCard(
                  isDark: isDark,
                  accent: accent,
                  embedded: true,
                  icon: Icons.handshake_rounded,
                  title: 'Open to negotiation',
                  subtitle: 'Allow counter-offers',
                  value: _isNegotiable,
                  onChanged: (v) => setState(() => _isNegotiable = v),
                ),
                ListingEditToggleCard(
                  isDark: isDark,
                  accent: accent,
                  embedded: true,
                  icon: Icons.star_rounded,
                  title: 'Promote with BYC',
                  subtitle: 'Boost visibility in the feed',
                  value: _enableBYCPromotion,
                  onChanged: (v) => setState(() => _enableBYCPromotion = v),
                ),
              ],
            ),
          ),
          if (widget.trade.location.isNotEmpty)
            EditFormFootnote(
              text: 'Location is set to ${widget.trade.location}. Contact support to change it.',
              accentColor: accent,
            ),
        ],
      ),
    );
  }

  static String _categoryLabel(TradeCategory cat) {
    return cat.name
        .replaceAll('homeGarden', 'home & garden')
        .split(RegExp(r'(?=[A-Z])'))
        .join(' ')
        .trim();
  }

  static IconData _categoryIcon(TradeCategory cat) {
    switch (cat) {
      case TradeCategory.electronics:
        return Icons.devices_rounded;
      case TradeCategory.fashion:
      case TradeCategory.clothing:
        return Icons.checkroom_rounded;
      case TradeCategory.homeGarden:
        return Icons.home_rounded;
      case TradeCategory.sports:
        return Icons.sports_soccer_rounded;
      case TradeCategory.books:
        return Icons.menu_book_rounded;
      case TradeCategory.tools:
        return Icons.build_rounded;
      case TradeCategory.automotive:
        return Icons.directions_car_rounded;
      case TradeCategory.collectibles:
        return Icons.star_rounded;
      case TradeCategory.others:
        return Icons.category_rounded;
    }
  }
}
