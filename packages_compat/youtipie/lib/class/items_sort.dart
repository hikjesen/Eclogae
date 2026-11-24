class YoutiPieItemsSort {
  const YoutiPieItemsSort({required this.title, String? token, this.initiallySelected = false}) : token = token ?? title;

  final String title;
  final String token;
  final bool initiallySelected;
}
