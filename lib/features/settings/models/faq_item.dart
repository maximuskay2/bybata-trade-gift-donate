class FAQItem {
  final String id;
  final String category;
  final String question;
  final String answer;
  final List<String> tags;
  final List<String> relatedQuestions;
  final bool? isHelpful;
  final DateTime? lastUpdated;
  final int viewCount;
  final int helpfulCount;

  const FAQItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.tags = const [],
    this.relatedQuestions = const [],
    this.isHelpful,
    this.lastUpdated,
    this.viewCount = 0,
    this.helpfulCount = 0,
  });

  FAQItem copyWith({
    String? id,
    String? category,
    String? question,
    String? answer,
    List<String>? tags,
    List<String>? relatedQuestions,
    bool? isHelpful,
    DateTime? lastUpdated,
    int? viewCount,
    int? helpfulCount,
  }) {
    return FAQItem(
      id: id ?? this.id,
      category: category ?? this.category,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      tags: tags ?? this.tags,
      relatedQuestions: relatedQuestions ?? this.relatedQuestions,
      isHelpful: isHelpful ?? this.isHelpful,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      viewCount: viewCount ?? this.viewCount,
      helpfulCount: helpfulCount ?? this.helpfulCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'question': question,
      'answer': answer,
      'tags': tags,
      'isHelpful': isHelpful,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'viewCount': viewCount,
      'helpfulCount': helpfulCount,
    };
  }

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      id: json['id'],
      category: json['category'],
      question: json['question'],
      answer: json['answer'],
      tags: List<String>.from(json['tags'] ?? []),
      isHelpful: json['isHelpful'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : null,
      viewCount: json['viewCount'] ?? 0,
      helpfulCount: json['helpfulCount'] ?? 0,
    );
  }
}