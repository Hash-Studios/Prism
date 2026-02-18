enum DeepLinkActionType { share, user, setup, refer, unknown }

class DeepLinkActionEntity {
  const DeepLinkActionEntity({required this.type, required this.route, required this.arguments, required this.rawUri});

  final DeepLinkActionType type;
  final String route;
  final List<dynamic> arguments;
  final String rawUri;
}
