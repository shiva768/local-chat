class Message {
  final String id;
  final String channelId;
  final String from;
  final String? to;
  final String content;
  final DateTime timestamp;
  final String? threadId;

  Message({
    required this.id,
    required this.channelId,
    required this.from,
    this.to,
    required this.content,
    required this.timestamp,
    this.threadId,
  });

  Message copyWith({
    String? id,
    String? channelId,
    String? from,
    String? to,
    String? content,
    DateTime? timestamp,
    String? threadId,
  }) {
    return Message(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      from: from ?? this.from,
      to: to ?? this.to,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      threadId: threadId ?? this.threadId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'from': from,
        'to': to,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'threadId': threadId,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        channelId: json['channelId'] as String,
        from: json['from'] as String,
        to: json['to'] as String?,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        threadId: json['threadId'] as String?,
      );
}
