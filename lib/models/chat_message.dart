class ChatMessage {
  const ChatMessage({required this.id, required this.roomId, required this.senderId,
    required this.senderName, required this.body, required this.createdAt,
    this.attachmentName, this.attachmentPath});
  final int? id;
  final String roomId, senderId, senderName, body;
  final DateTime createdAt;
  final String? attachmentName, attachmentPath;
  Map<String, Object?> toMap() => {'id':id,'room_id':roomId,'sender_id':senderId,
    'sender_name':senderName,'body':body,'created_at':createdAt.toIso8601String(),
    'attachment_name':attachmentName,'attachment_path':attachmentPath};
}
