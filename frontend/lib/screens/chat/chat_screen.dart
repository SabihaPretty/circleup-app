import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/access_control.dart';
import '../../core/api_config.dart';
import '../../core/api_service.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_card.dart';
import '../calls/call_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  IO.Socket? socket;

  List users = [];
  List messages = [];
  List<int> onlineUserIds = [];

  Map<String, dynamic>? selectedUser;

  bool loadingUsers = true;
  bool loadingMessages = false;
  bool connected = false;
  bool receiverTyping = false;
  bool guardianActionLoading = false;

  final messageController = TextEditingController();
  Timer? typingTimer;

  @override
  void initState() {
    super.initState();
    connectSocket();
    loadConnectedUsers();
  }

  @override
  void dispose() {
    typingTimer?.cancel();
    messageController.dispose();
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  String conversationId(int myId, int otherId) {
    final ids = [myId, otherId]..sort();
    return 'private_${ids[0]}_${ids[1]}';
  }

  String? currentConversation() {
    final me = AppSession.currentUser;
    final other = selectedUser;

    if (me == null || other == null) return null;

    return conversationId(me['id'], other['id']);
  }

  void connectSocket() {
    final user = AppSession.currentUser;
    if (user == null) return;

    socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({
            'token': AppSession.authToken ?? '',
            'userId': '${user['id']}',
          })
          .build(),
    );

    socket!.onConnect((_) {
      setState(() => connected = true);

      socket!.emit('join_user', {
        'userId': user['id'],
      });

      final conversation = currentConversation();

      if (conversation != null) {
        socket!.emit('join_conversation', {
          'conversation': conversation,
        });
      }
    });

    socket!.onDisconnect((_) {
      if (mounted) {
        setState(() => connected = false);
      }
    });

    socket!.on('incoming_call', (data) {
      if (!mounted || data == null) return;
      showIncomingCall(Map<String, dynamic>.from(data as Map));
    });

    socket!.on('message_error', (data) {
      if (!mounted) return;

      final payload = data is Map ? Map<String, dynamic>.from(data) : {};
      final message = payload['message'] ?? 'Message failed';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    socket!.on('online_users', (data) {
      final list = <int>[];

      if (data is List) {
        for (final item in data) {
          final id = int.tryParse(item.toString());
          if (id != null) list.add(id);
        }
      }

      if (mounted) {
        setState(() => onlineUserIds = list);
      }
    });

    socket!.on('new_message', (data) {
      if (data == null) return;

      final msg = Map<String, dynamic>.from(data as Map);
      final activeConversation = currentConversation();

      if (activeConversation == null) return;
      if (msg['conversation'] != activeConversation) return;

      final exists = messages.any((m) => m['id'] == msg['id']);

      if (!exists && mounted) {
        setState(() {
          messages.add(msg);
        });
      }
    });

    socket!.on('typing_status', (data) {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);
      final me = AppSession.currentUser;
      final other = selectedUser;
      final activeConversation = currentConversation();

      if (me == null || other == null || activeConversation == null) return;
      if (payload['conversation'] != activeConversation) return;
      if (payload['senderId'] != other['id']) return;

      if (mounted) {
        setState(() {
          receiverTyping = payload['isTyping'] == true;
        });
      }
    });

    socket!.connect();
  }

  void showIncomingCall(Map<String, dynamic> data) {
    final me = AppSession.currentUser;
    if (me == null) return;

    final caller = Map<String, dynamic>.from(data['caller'] ?? {});
    final callerId = data['callerId'];
    final callId = data['callId'];
    final callType = data['callType'] ?? 'audio';

    if (callerId == me['id']) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text(callType == 'video' ? 'Incoming video call' : 'Incoming audio call'),
          content: Text('${caller['nickname'] ?? caller['name'] ?? 'Someone'} is calling you.'),
          actions: [
            TextButton.icon(
              onPressed: () {
                socket?.emit('reject_call', {
                  'callId': callId,
                  'callerId': callerId,
                  'receiverId': me['id'],
                  'reason': 'Rejected',
                });
                Navigator.pop(context);
              },
              icon: const Icon(Icons.call_end),
              label: const Text('Reject'),
            ),
            FilledButton.icon(
              onPressed: () {
                socket?.emit('accept_call', {
                  'callId': callId,
                  'callerId': callerId,
                  'receiverId': me['id'],
                  'callType': callType,
                });

                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      remoteUser: caller,
                      callType: callType,
                      isCaller: false,
                      callId: callId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> loadConnectedUsers() async {
    final me = AppSession.currentUser;
    if (me == null) return;

    setState(() => loadingUsers = true);

    try {
      final connectionsResult = await ApiService.get('/connections/user/${me['id']}');
      final accepted = connectionsResult['accepted'] ?? [];

      final normalUsers = accepted.map((item) {
        final connection = Map<String, dynamic>.from(item);
        return Map<String, dynamic>.from(connection['otherUser'] ?? {});
      }).toList();

      final guardianResult = await ApiService.get('/guardian/user/${me['id']}');
      final guardianUsers = (guardianResult['safeChatUsers'] ?? []).map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();

      final combined = <Map<String, dynamic>>[];
      final seenIds = <int>{};

      for (final user in [...normalUsers, ...guardianUsers]) {
        final id = user['id'];

        if (id is int && !seenIds.contains(id)) {
          seenIds.add(id);
          combined.add(user);
        }
      }

      users = combined;

      if (users.isNotEmpty && selectedUser == null) {
        selectedUser = Map<String, dynamic>.from(users.first);
        await loadMessages();
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loadingUsers = false);
  }

  Future<void> loadMessages() async {
    final conversation = currentConversation();

    if (conversation == null) return;

    setState(() => loadingMessages = true);

    try {
      final result = await ApiService.get('/messages?conversation=$conversation');
      messages = result ?? [];

      socket?.emit('join_conversation', {
        'conversation': conversation,
      });
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => loadingMessages = false);
  }

  Future<void> selectUser(Map<String, dynamic> user) async {
    setState(() {
      selectedUser = user;
      messages = [];
      receiverTyping = false;
    });

    await loadMessages();
  }

  void startCall(String callType) {
    final other = selectedUser;

    if (other == null) {
      showMessage('Select a chat contact first.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          remoteUser: other,
          callType: callType,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> createGuardianCode() async {
    final me = AppSession.currentUser;
    if (me == null) return;

    setState(() => guardianActionLoading = true);

    try {
      final result = await ApiService.post('/guardian/invite/create', {
        'guardianId': me['id'],
        'relationType': 'parent',
      });

      final data = Map<String, dynamic>.from(result['data'] ?? {});
      final code = data['code'] ?? '';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Guardian Code'),
            content: SelectableText(
              'Share this code only with your child:\n\n$code\n\nThis code expires in 24 hours.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showMessage('Guardian code failed: $e');
    }

    if (mounted) {
      setState(() => guardianActionLoading = false);
    }
  }

  Future<void> enterGuardianCode() async {
    final me = AppSession.currentUser;
    if (me == null) return;

    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        bool dialogLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitCode() async {
              final code = codeController.text.trim();

              if (code.isEmpty) {
                showMessage('Enter guardian code first.');
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final result = await ApiService.post('/guardian/connect-by-code', {
                  'childId': me['id'],
                  'code': code,
                });

                if (!mounted) return;

                Navigator.pop(context);
                await loadConnectedUsers();
                showMessage(result['message'] ?? 'Guardian connected.');
              } catch (e) {
                showMessage('Guardian connect failed: $e');
              }

              setDialogState(() => dialogLoading = false);
            }

            return AlertDialog(
              title: const Text('Connect Parent / Guardian'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ask your parent/guardian to create a Guardian Code from their account.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Guardian Code',
                      hintText: 'CU-ABC123',
                      filled: true,
                      fillColor: const Color(0xfff8fafc),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogLoading ? null : submitCode,
                  child: dialogLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
  }

  void sendTypingStatus(bool isTyping) {
    final me = AppSession.currentUser;
    final other = selectedUser;
    final conversation = currentConversation();

    if (me == null || other == null || conversation == null) return;

    socket?.emit('typing', {
      'senderId': me['id'],
      'receiverId': other['id'],
      'conversation': conversation,
      'isTyping': isTyping,
    });
  }

  void onTypingChanged(String value) {
    sendTypingStatus(value.trim().isNotEmpty);

    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 900), () {
      sendTypingStatus(false);
    });
  }

  Future<void> sendMessage() async {
    final me = AppSession.currentUser;
    final other = selectedUser;
    final conversation = currentConversation();
    final text = messageController.text.trim();

    if (me == null || other == null || conversation == null || text.isEmpty) {
      return;
    }

    socket?.emit('send_message', {
      'senderId': me['id'],
      'receiverId': other['id'],
      'conversation': conversation,
      'content': text,
    });

    messageController.clear();
    sendTypingStatus(false);
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget userAvatar(Map<String, dynamic> user) {
    final isOnline = onlineUserIds.contains(user['id']);

    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primary.withOpacity(.12),
          child: Text(
            (user['nickname'] ?? user['name'] ?? 'U')
                .toString()
                .substring(0, 1)
                .toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget guardianPanel() {
    final me = AppSession.currentUser;
    final age = me?['ageGroup'] ?? 'adult';
    final isChild = age == 'kids' || age == 'teen';
    final isGuardian = age == 'adult' || age == 'senior';

    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.warning.withOpacity(.14),
            child: const Icon(Icons.family_restroom, color: AppTheme.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isChild
                  ? 'Family Gate: connect parent/guardian by code only.'
                  : 'Guardian Bridge: create one-time code for your child.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isChild)
            FilledButton(
              onPressed: guardianActionLoading ? null : enterGuardianCode,
              child: const Text('Enter Code'),
            ),
          if (isGuardian)
            FilledButton(
              onPressed: guardianActionLoading ? null : createGuardianCode,
              child: const Text('Create Code'),
            ),
        ],
      ),
    );
  }

  Widget buildUserList() {
    if (loadingUsers) {
      return const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (users.isEmpty) {
      return const EmptyState(
        icon: Icons.family_restroom,
        title: 'No safe chat contact yet',
        subtitle: 'Connect with safe people first. Kids should connect using Guardian Code.',
      );
    }

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: users.map((item) {
          final user = Map<String, dynamic>.from(item);
          final selected = selectedUser?['id'] == user['id'];

          return InkWell(
            onTap: () => selectUser(user),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 86,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xffeef2ff) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? AppTheme.primary.withOpacity(.35)
                      : Colors.black.withOpacity(.06),
                ),
              ),
              child: Column(
                children: [
                  userAvatar(user),
                  const SizedBox(height: 6),
                  Text(
                    user['nickname'] ?? user['name'] ?? 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildMessageBubble(Map<String, dynamic> msg) {
    final me = AppSession.currentUser;
    final isMine = me != null && msg['senderId'] == me['id'];
    final sender = Map<String, dynamic>.from(msg['sender'] ?? {});

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
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
                sender['nickname'] ?? sender['name'] ?? 'User',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                color: isMine ? Colors.white : AppTheme.dark,
                fontSize: 15,
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
    final me = AppSession.currentUser;
    final myAge = me?['ageGroup'] ?? 'adult';
    final other = selectedUser;
    final otherOnline = other != null && onlineUserIds.contains(other['id']);

    return Column(
      children: [
        PremiumCard(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.mainGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_user, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Safe Realtime Chat Active' : 'Connecting...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${AccessControl.ageGroupLabel(myAge)} • audio/video call ready',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        guardianPanel(),
        buildUserList(),
        if (other != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.indigo.withOpacity(.06),
            child: Row(
              children: [
                userAvatar(other),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other['nickname'] ?? other['name'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        receiverTyping
                            ? 'typing...'
                            : otherOnline
                                ? 'online'
                                : 'offline',
                        style: TextStyle(
                          color: receiverTyping || otherOnline
                              ? Colors.green
                              : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => startCall('audio'),
                  icon: const Icon(Icons.call, color: AppTheme.success),
                ),
                IconButton(
                  onPressed: () => startCall('video'),
                  icon: const Icon(Icons.videocam, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        Expanded(
          child: other == null
              ? const EmptyState(
                  icon: Icons.chat,
                  title: 'No chat selected',
                  subtitle: 'Connect with a safe person first.',
                )
              : loadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const EmptyState(
                          icon: Icons.mark_chat_unread,
                          title: 'No messages yet',
                          subtitle: 'Send your first safe realtime message.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = Map<String, dynamic>.from(messages[index]);
                            return buildMessageBubble(msg);
                          },
                        ),
        ),
        if (other != null)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => startCall('audio'),
                    icon: const Icon(Icons.call),
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      onChanged: onTypingChanged,
                      decoration: InputDecoration(
                        hintText: 'Type safe realtime message...',
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
    );
  }
}
