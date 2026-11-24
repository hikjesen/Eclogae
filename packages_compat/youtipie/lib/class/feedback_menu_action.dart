enum FeedbackMenuActionType { notInterested, dontRecommendChannel }

class FeedbackMenuAction {
  const FeedbackMenuAction({required this.type, required this.text, this.undoToken});

  final FeedbackMenuActionType type;
  final String text;
  final String? undoToken;
}

class YoutiPieFeedbackUndo {
  const YoutiPieFeedbackUndo();
}
