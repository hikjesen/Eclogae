enum NotificationMenuActionType { hide }

class NotificationMenuAction {
  const NotificationMenuAction({required this.text, this.iconType, this.type});

  final String text;
  final String? iconType;
  final NotificationMenuActionType? type;
}
