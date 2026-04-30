import 'package:flutter/material.dart';
import '../models/channel.dart';

class ChannelList extends StatelessWidget {
  final List<Channel> channels;
  final String? selectedChannelId;
  final void Function(Channel) onChannelSelected;
  final VoidCallback onAddChannel;

  const ChannelList({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    required this.onAddChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Text(
                'Channels',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                onPressed: onAddChannel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        ...channels.map((channel) => _ChannelItem(
              channel: channel,
              isSelected: channel.id == selectedChannelId,
              onTap: () => onChannelSelected(channel),
            )),
      ],
    );
  }
}

class _ChannelItem extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelItem({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.white10 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Text(
              '# ',
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 14),
            ),
            Expanded(
              child: Text(
                channel.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
