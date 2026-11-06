import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/faq_item.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class FAQExpansionTile extends StatefulWidget {
  final FAQItem faqItem;
  final bool initiallyExpanded;

  const FAQExpansionTile({
    super.key,
    required this.faqItem,
    this.initiallyExpanded = false,
  });

  @override
  State<FAQExpansionTile> createState() => _FAQExpansionTileState();
}

class _FAQExpansionTileState extends State<FAQExpansionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpansion,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.faqItem.question,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.faqItem.category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.faqItem.category,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.faqItem.answer,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.faqItem.relatedQuestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Related Questions:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.faqItem.relatedQuestions.map(
                          (question) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: InkWell(
                              onTap: () => _showRelatedQuestion(context, question),
                              child: Text(
                                '• $question',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Was this helpful?',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _provideFeedback(context, true),
                            icon: const Icon(Icons.thumb_up_outlined, size: 16),
                            label: const Text('Yes'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(60, 30),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _provideFeedback(context, false),
                            icon: const Icon(Icons.thumb_down_outlined, size: 16),
                            label: const Text('No'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(60, 30),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _copyToClipboard(context),
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copy answer',
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
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
        ],
      ),
    );
  }

  void _showRelatedQuestion(BuildContext context, String question) {
    AppToast.show(context, 'Navigate to: $question');
  }

  void _provideFeedback(BuildContext context, bool isHelpful) {
    HapticFeedback.lightImpact();
    
    AppToast.error(context, isHelpful
              ? 'Thanks for your feedback!'
              : 'Sorry this wasn\'t helpful. We\'ll improve this answer.',);
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(
      ClipboardData(
        text: '${widget.faqItem.question}\n\n${widget.faqItem.answer}',
      ),
    );
    
    HapticFeedback.lightImpact();
    
    AppToast.show(context, 'FAQ copied to clipboard');
  }
}