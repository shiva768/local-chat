class Channel {
  final String id;
  final String name;
  final String? description;
  final List<String> agentIds;
  final String chatDir;
  final DateTime createdAt;

  Channel({
    required this.id,
    required this.name,
    this.description,
    required this.agentIds,
    required this.chatDir,
    required this.createdAt,
  });

  Channel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? agentIds,
    String? chatDir,
    DateTime? createdAt,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      agentIds: agentIds ?? this.agentIds,
      chatDir: chatDir ?? this.chatDir,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'agentIds': agentIds,
        'chatDir': chatDir,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        agentIds: (json['agentIds'] as List<dynamic>).cast<String>(),
        chatDir: json['chatDir'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
