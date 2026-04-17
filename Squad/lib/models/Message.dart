class Message {
  final int id;
  final int chatId;
  final int senderId;
  final String content;
  final String? createdAt;
  final String? senderName;
  final String? senderProfilePhoto;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.createdAt,
    this.senderName,
    this.senderProfilePhoto,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? 0,
      chatId: json['chat_id'] ?? json['chatId'] ?? 0,
      senderId: json['sender_id'] ?? json['senderId'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'],
      senderName: json['sender_name'] ?? json['senderName'],
      senderProfilePhoto: json['sender_profile_photo'] ?? json['senderProfilePhoto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt,
      'sender_name': senderName,
      'sender_profile_photo': senderProfilePhoto,
    };
  }
}

class Chat {
  final int id;
  final int userId1;
  final int userId2;
  final String? createdAt;
  final String? otherUserName;
  final String? otherUserProfilePhoto;
  final String? lastMessage;
  final String? lastMessageTime;

  Chat({
    required this.id,
    required this.userId1,
    required this.userId2,
    this.createdAt,
    this.otherUserName,
    this.otherUserProfilePhoto,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] ?? 0,
      userId1: json['user_id_1'] ?? json['userId1'] ?? 0,
      userId2: json['user_id_2'] ?? json['userId2'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'],
      otherUserName: json['other_user_name'] ?? json['otherUserName'],
      otherUserProfilePhoto: json['other_user_profile_photo'] ?? json['otherUserProfilePhoto'],
      lastMessage: json['last_message'] ?? json['lastMessage'],
      lastMessageTime: json['last_message_time'] ?? json['lastMessageTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id_1': userId1,
      'user_id_2': userId2,
      'created_at': createdAt,
      'other_user_name': otherUserName,
      'other_user_profile_photo': otherUserProfilePhoto,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
    };
  }
}
