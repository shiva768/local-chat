enum AgentStatus { active, idle, sleeping }

class Agent {
  final String id;
  final String name;
  final String channelId;
  final AgentStatus status;

  Agent({
    required this.id,
    required this.name,
    required this.channelId,
    required this.status,
  });

  Agent copyWith({
    String? id,
    String? name,
    String? channelId,
    AgentStatus? status,
  }) {
    return Agent(
      id: id ?? this.id,
      name: name ?? this.name,
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channelId': channelId,
        'status': status.name,
      };

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
        id: json['id'] as String,
        name: json['name'] as String,
        channelId: json['channelId'] as String,
        status: AgentStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AgentStatus.idle,
        ),
      );
}
