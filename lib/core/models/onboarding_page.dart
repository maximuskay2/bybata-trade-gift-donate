class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;
  final String? iconData;
  final List<String> features;
  final String primaryColor;
  final String secondaryColor;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imagePath,
    this.iconData,
    required this.features,
    required this.primaryColor,
    required this.secondaryColor,
  });
}