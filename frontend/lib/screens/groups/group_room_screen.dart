import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/api_config.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'group_call_screen.dart';

class GroupRoomScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupRoomScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen> {
  socket_io.Socket? socket;

  List messages = [];
  Map<int, String> nicknames = {};
  List<_EmojiEffect> emojiEffects = [];

  bool loading = true;
  bool connected = false;
  bool someoneTyping = false;

  final messageController = TextEditingController();
  Timer? typingTimer;

  final emojis = const ['❤️', '😂', '🔥', '🎉', '🌟', '👏', '😮', '😡', '🤝', '🥰'];

  int get groupId => widget.group['id'];
  Map<String, dynamic> get me => AppSession.currentUser ?? {};

  @override
  void initState() {
    super.initState();
    connectSocket();
    loadMessages();
    loadNicknames();
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    messageController.dispose();
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  void connectSocket() {
    socket = socket_io.io(
      ApiConfig.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({
            'userId': '${me['id']}',
            'token': AppSession.authToken ?? '',
          })
          .build(),
    );

    socket!.onConnect((_) {
      setState(() => connected = true);

      socket!.emit('join_group', {
        'groupId': groupId,
        'userId': me['id'],
      });
    });

    socket!.onDisconnect((_) {
      if (mounted) setState(() => connected = false);
    });

    socket!.on('new_group_message', (data) {
      if (data == null) return;

      final msg = Map<String, dynamic>.from(data as Map);

      if (msg['groupId'] != groupId) return;

      final exists = messages.any((item) => item['id'] == msg['id']);

      if (!exists && mounted) {
        setState(() {
          messages.add(msg);
        });

        final content = msg['content']?.toString() ?? '';
        if (emojis.any((e) => content.contains(e))) {
          addEmojiEffect(content.characters.first);
        }
      }
    });

    socket!.on('group_typing_status', (data) {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['groupId'] != groupId) return;
      if (payload['userId'] == me['id']) return;

      if (mounted) {
        setState(() => someoneTyping = payload['isTyping'] == true);
      }
    });

    socket!.on('incoming_group_call', (data) {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['groupId'] != groupId) return;
      if (payload['callerId'] == me['id']) return;

      showIncomingGroupCall(payload);
    });

    socket!.connect();
  }

  Future<void> loadMessages() async {
    setState(() => loading = true);

    try {
      final result = await ApiService.get('/groups/$groupId/messages');
      messages = result['data'] ?? [];
    } catch (e) {
      showMessage('Messages load failed: $e');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> loadNicknames() async {
    try {
      final result = await ApiService.get('/nicknames/user/${me['id']}');
      final list = result['data'] ?? [];

      final map = <int, String>{};

      for (final item in list) {
        final row = Map<String, dynamic>.from(item);
        map[row['targetId']] = row['nickname'];
      }

      if (mounted) {
        setState(() => nicknames = map);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  String displayName(Map<String, dynamic> user) {
    final id = user['id'];

    if (id is int && nicknames[id] != null) {
      return nicknames[id]!;
    }

    return user['nickname'] ?? user['name'] ?? 'User';
  }

  Future<void> sendMessage({String? fixedText}) async {
    final text = fixedText ?? messageController.text.trim();

    if (text.isEmpty) return;

    socket?.emit('send_group_message', {
      'groupId': groupId,
      'senderId': me['id'],
      'content': text,
      'mediaType': 'text',
    });

    messageController.clear();
    sendTyping(false);

    if (emojis.contains(text)) {
      addEmojiEffect(text);
    }
  }

  void sendTyping(bool isTyping) {
    socket?.emit('group_typing', {
      'groupId': groupId,
      'userId': me['id'],
      'user': me,
      'isTyping': isTyping,
    });
  }

  void onTypingChanged(String value) {
    sendTyping(value.trim().isNotEmpty);

    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 800), () {
      sendTyping(false);
    });
  }

  void addEmojiEffect(String emoji) {
    final random = Random();
    final id = DateTime.now().microsecondsSinceEpoch;

    setState(() {
      emojiEffects.add(
        _EmojiEffect(
          id: id,
          emoji: emoji,
          leftFactor: random.nextDouble(),
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;

      setState(() {
        emojiEffects.removeWhere((item) => item.id == id);
      });
    });
  }

  void showEmojiPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: emojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    sendMessage(fixedText: emoji);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void showMembersSheet() {
    final members = widget.group['members'] ?? [];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              Text(
                'Group Members',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...members.map((item) {
                final member = Map<String, dynamic>.from(item);
                final user = Map<String, dynamic>.from(member['user'] ?? {});

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      displayName(user).substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(displayName(user)),
                  subtitle: Text('${user['ageGroup'] ?? ''} • ${member['role'] ?? 'member'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => showNicknameDialog(user),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void showNicknameDialog(Map<String, dynamic> targetUser) {
    final controller = TextEditingController(
      text: nicknames[targetUser['id']] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Nickname for ${targetUser['name'] ?? 'User'}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Custom nickname',
              hintText: 'Example: Best Friend, Sir, Doctor, Cousin',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final nickname = controller.text.trim();

                  await ApiService.post('/nicknames/set', {
                    'ownerId': me['id'],
                    'targetId': targetUser['id'],
                    'nickname': nickname,
                  });

                  controller.dispose();

                  if (!mounted) return;

                  Navigator.pop(context);
                  await loadNicknames();
                  showMessage('Nickname saved.');
                } catch (e) {
                  showMessage('Nickname save failed: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void startGroupCall(String callType) {
    final callId = 'group_${groupId}_${DateTime.now().microsecondsSinceEpoch}';

    socket?.emit('group_call_invite', {
      'callId': callId,
      'groupId': groupId,
      'callType': callType,
      'callerId': me['id'],
      'caller': me,
      'group': widget.group,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          group: widget.group,
          callType: callType,
          callId: callId,
        ),
      ),
    );
  }

  void showIncomingGroupCall(Map<String, dynamic> payload) {
    final caller = Map<String, dynamic>.from(payload['caller'] ?? {});

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(payload['callType'] == 'video'
              ? 'Incoming group video call'
              : 'Incoming group audio call'),
          content: Text('${caller['nickname'] ?? caller['name'] ?? 'Someone'} started a group call.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ignore'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupCallScreen(
                      group: widget.group,
                      callType: payload['callType'] ?? 'audio',
                      callId: payload['callId'],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget messageBubble(Map<String, dynamic> message) {
    final sender = Map<String, dynamic>.from(message['sender'] ?? {});
    final isMine = message['senderId'] == me['id'];

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isMine ? AppTheme.mainGradient : null,
          color: isMine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                displayName(sender),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              message['content'] ?? '',
              style: TextStyle(
                color: isMine ? Colors.white : AppTheme.dark,
                fontSize: emojis.contains(message['content']) ? 34 : 15,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effects = emojiEffects;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group['name'] ?? 'Group'),
        actions: [
          IconButton(
            onPressed: () => startGroupCall('audio'),
            icon: const Icon(Icons.call),
          ),
          IconButton(
            onPressed: () => startGroupCall('video'),
            icon: const Icon(Icons.videocam),
          ),
          IconButton(
            onPressed: showMembersSheet,
            icon: const Icon(Icons.groups),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: connected
                    ? AppTheme.success.withOpacity(.08)
                    : AppTheme.warning.withOpacity(.08),
                child: Row(
                  children: [
                    Icon(
                      connected ? Icons.wifi : Icons.wifi_off,
                      color: connected ? AppTheme.success : AppTheme.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        someoneTyping
                            ? 'Someone is typing...'
                            : connected
                                ? 'Group realtime chat active'
                                : 'Connecting group chat...',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: showMembersSheet,
                      icon: const Icon(Icons.edit),
                      label: const Text('Nicknames'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.forum,
                            title: 'No group messages yet',
                            subtitle: 'Send your first message or emoji effect.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = Map<String, dynamic>.from(messages[index]);
                              return messageBubble(msg);
                            },
                          ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: showEmojiPanel,
                        icon: const Icon(Icons.emoji_emotions),
                      ),
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          onChanged: onTypingChanged,
                          decoration: InputDecoration(
                            hintText: 'Message group...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: sendMessage,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ...effects.map((effect) {
            return _FloatingEmoji(effect: effect);
          }),
        ],
      ),
    );
  }
}

class _EmojiEffect {
  final int id;
  final String emoji;
  final double leftFactor;

  _EmojiEffect({
    required this.id,
    required this.emoji,
    required this.leftFactor,
  });
}

class _FloatingEmoji extends StatefulWidget {
  final _EmojiEffect effect;

  const _FloatingEmoji({
    required this.effect,
  });

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> y;
  late Animation<double> opacity;
  late Animation<double> scale;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    y = Tween<double>(begin: 0, end: -260).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    scale = Tween<double>(begin: .7, end: 1.8).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final left = (width - 80) * widget.effect.leftFactor;

    return Positioned(
      left: left,
      bottom: 80,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Opacity(
            opacity: opacity.value,
            child: Transform.translate(
              offset: Offset(0, y.value),
              child: Transform.scale(
                scale: scale.value,
                child: Text(
                  widget.effect.emoji,
                  style: const TextStyle(fontSize: 42),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
