enum MessageRole { user, assistant }

enum MessageDelivery { pending, sent, failed }

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.text,
    this.delivery = MessageDelivery.sent,
  });
  final int id;
  final MessageRole role;
  final String text;
  final MessageDelivery delivery;

  ChatMessageModel withDelivery(MessageDelivery value) =>
      ChatMessageModel(id: id, role: role, text: text, delivery: value);

  Map<String, String> toTranscript() => {'sender': role.name, 'text': text};
}
