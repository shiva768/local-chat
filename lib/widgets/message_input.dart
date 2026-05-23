import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final String channelName;
  final List<String> participants;
  final void Function(String message) onSend;

  const MessageInput({
    super.key,
    required this.channelName,
    required this.participants,
    required this.onSend,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      setState(() => _suggestions = []);
      return;
    }

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex < 0) {
      setState(() => _suggestions = []);
      return;
    }

    final partial = before.substring(atIndex + 1);
    if (partial.contains(' ')) {
      setState(() => _suggestions = []);
      return;
    }

    final filtered = widget.participants
        .where((p) => p.toLowerCase().startsWith(partial.toLowerCase()))
        .toList();
    setState(() => _suggestions = filtered);
  }

  void _insertMention(String name) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');

    final newText = text.substring(0, atIndex) + '@$name ' + text.substring(cursor);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + name.length + 2),
    );
    setState(() => _suggestions = []);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final name = _suggestions[i];
                  return InkWell(
                    onTap: () => _insertMention(name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF3F0E40),
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('@$name', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '#${widget.channelName}',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF3F0E40)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF3F0E40)),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
