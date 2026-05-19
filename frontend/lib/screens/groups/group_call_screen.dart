import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../../core/api_config.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';

class GroupCallScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final String callType;
  final String callId;

  const GroupCallScreen({
    super.key,
    required this.group,
    required this.callType,
    required this.callId,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  socket_io.Socket? socket;
  MediaStream? localStream;

  final Map<int, RTCPeerConnection> peers = {};
  final Map<int, RTCVideoRenderer> remoteRenderers = {};
  final Map<int, Map<String, dynamic>> remoteUsers = {};

  bool muted = false;
  bool cameraOff = false;
  bool connecting = true;

  String beautyMode = 'natural';

  Map<String, dynamic> get me => AppSession.currentUser ?? {};
  int get myId => me['id'] ?? 0;
  int get groupId => widget.group['id'];
  bool get isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    startCall();
  }

  @override
  void dispose() {
    cleanup(sendLeave: true);
    super.dispose();
  }

  Future<void> startCall() async {
    await localRenderer.initialize();
    await openMedia();
    connectSocket();
  }

  Future<void> openMedia() async {
    final constraints = {
      'audio': true,
      'video': isVideo
          ? {
              'facingMode': 'user',
              'width': 640,
              'height': 480,
            }
          : false,
    };

    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = localStream;

    setState(() => connecting = false);
  }

  void connectSocket() {
    socket = socket_io.io(
      ApiConfig.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({
            'userId': '$myId',
            'token': AppSession.authToken ?? '',
          })
          .build(),
    );

    socket!.onConnect((_) {
      socket!.emit('join_group_call', {
        'callId': widget.callId,
        'groupId': groupId,
        'userId': myId,
        'user': me,
      });
    });

    socket!.on('group_existing_users', (data) async {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;

      final users = payload['users'] ?? [];

      for (final item in users) {
        final row = Map<String, dynamic>.from(item);
        final targetId = NumberParser.toInt(row['userId']);

        if (targetId != null && targetId != myId) {
          remoteUsers[targetId] = Map<String, dynamic>.from(row['user'] ?? {});
          await createOffer(targetId);
        }
      }
    });

    socket!.on('group_call_user_joined', (data) {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;

      final userId = NumberParser.toInt(payload['userId']);

      if (userId == null || userId == myId) return;

      remoteUsers[userId] = Map<String, dynamic>.from(payload['user'] ?? {});

      if (mounted) setState(() {});
    });

    socket!.on('group_call_user_left', (data) async {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;

      final userId = NumberParser.toInt(payload['userId']);

      if (userId == null) return;

      await removePeer(userId);
    });

    socket!.on('group_webrtc_offer', (data) async {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;
      if (payload['targetId'] != myId) return;

      await handleOffer(payload);
    });

    socket!.on('group_webrtc_answer', (data) async {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;
      if (payload['targetId'] != myId) return;

      await handleAnswer(payload);
    });

    socket!.on('group_webrtc_ice_candidate', (data) async {
      if (data == null) return;

      final payload = Map<String, dynamic>.from(data as Map);

      if (payload['callId'] != widget.callId) return;
      if (payload['targetId'] != myId) return;

      await handleIceCandidate(payload);
    });

    socket!.connect();
  }

  Future<RTCPeerConnection> getPeer(int remoteUserId) async {
    if (peers[remoteUserId] != null) {
      return peers[remoteUserId]!;
    }

    final peer = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    peer.onIceCandidate = (candidate) {
      socket?.emit('group_webrtc_ice_candidate', {
        'callId': widget.callId,
        'fromId': myId,
        'targetId': remoteUserId,
        'candidate': candidate.toMap(),
      });
    };

    peer.onTrack = (event) async {
      if (event.streams.isEmpty) return;

      final renderer = remoteRenderers[remoteUserId] ?? RTCVideoRenderer();

      if (remoteRenderers[remoteUserId] == null) {
        await renderer.initialize();
        remoteRenderers[remoteUserId] = renderer;
      }

      renderer.srcObject = event.streams.first;

      if (mounted) setState(() {});
    };

    for (final track in localStream?.getTracks() ?? []) {
      await peer.addTrack(track, localStream!);
    }

    peers[remoteUserId] = peer;

    return peer;
  }

  Future<void> createOffer(int targetId) async {
    final peer = await getPeer(targetId);

    final offer = await peer.createOffer();
    await peer.setLocalDescription(offer);

    socket?.emit('group_webrtc_offer', {
      'callId': widget.callId,
      'fromId': myId,
      'targetId': targetId,
      'sdp': offer.sdp,
      'type': offer.type,
      'user': me,
    });
  }

  Future<void> handleOffer(Map<String, dynamic> data) async {
    final fromId = NumberParser.toInt(data['fromId']);

    if (fromId == null || fromId == myId) return;

    remoteUsers[fromId] = Map<String, dynamic>.from(data['user'] ?? {});

    final peer = await getPeer(fromId);

    await peer.setRemoteDescription(
      RTCSessionDescription(
        data['sdp'],
        data['type'],
      ),
    );

    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);

    socket?.emit('group_webrtc_answer', {
      'callId': widget.callId,
      'fromId': myId,
      'targetId': fromId,
      'sdp': answer.sdp,
      'type': answer.type,
      'user': me,
    });
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    final fromId = NumberParser.toInt(data['fromId']);

    if (fromId == null || fromId == myId) return;

    final peer = peers[fromId];

    if (peer == null) return;

    await peer.setRemoteDescription(
      RTCSessionDescription(
        data['sdp'],
        data['type'],
      ),
    );
  }

  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    final fromId = NumberParser.toInt(data['fromId']);

    if (fromId == null || fromId == myId) return;

    final peer = peers[fromId];

    if (peer == null) return;

    final candidateData = Map<String, dynamic>.from(data['candidate']);

    await peer.addCandidate(
      RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      ),
    );
  }

  Future<void> removePeer(int userId) async {
    await peers[userId]?.close();
    await remoteRenderers[userId]?.dispose();

    peers.remove(userId);
    remoteRenderers.remove(userId);
    remoteUsers.remove(userId);

    if (mounted) setState(() {});
  }

  Future<void> cleanup({required bool sendLeave}) async {
    if (sendLeave) {
      socket?.emit('leave_group_call', {
        'callId': widget.callId,
        'groupId': groupId,
        'userId': myId,
      });
    }

    for (final peer in peers.values) {
      await peer.close();
    }

    for (final renderer in remoteRenderers.values) {
      await renderer.dispose();
    }

    await localStream?.dispose();
    await localRenderer.dispose();

    socket?.disconnect();
    socket?.dispose();
  }

  void toggleMute() {
    muted = !muted;

    for (final track in localStream?.getAudioTracks() ?? []) {
      track.enabled = !muted;
    }

    setState(() {});
  }

  void toggleCamera() {
    if (!isVideo) return;

    cameraOff = !cameraOff;

    for (final track in localStream?.getVideoTracks() ?? []) {
      track.enabled = !cameraOff;
    }

    setState(() {});
  }

  Future<void> endCall() async {
    await cleanup(sendLeave: true);

    if (mounted) Navigator.pop(context);
  }

  Color beautyColor() {
    if (beautyMode == 'bright') return Colors.white.withOpacity(.15);
    if (beautyMode == 'warm') return Colors.orange.withOpacity(.10);
    if (beautyMode == 'soft') return Colors.pink.withOpacity(.10);

    return Colors.transparent;
  }

  Widget beautyVideo({
    required RTCVideoRenderer renderer,
    bool mirror = false,
    bool small = false,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RTCVideoView(
          renderer,
          mirror: mirror,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
        if (beautyMode == 'soft')
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: .45, sigmaY: .45),
            child: Container(color: Colors.transparent),
          ),
        if (beautyMode != 'natural')
          Container(color: beautyColor()),
        if (!small && beautyMode != 'natural')
          Positioned(
            left: 10,
            top: 10,
            child: Chip(
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: Text('Beauty: $beautyMode'),
            ),
          ),
      ],
    );
  }

  Widget audioAvatar(Map<String, dynamic> user, {bool mine = false}) {
    final name = mine
        ? 'You'
        : user['nickname'] ?? user['name'] ?? 'Member';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: Text(
                name.toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget participantGrid() {
    final remoteIds = remoteRenderers.keys.toList();

    final total = 1 + remoteIds.length;

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(12, 80, 12, 150),
      crossAxisCount: total <= 2 ? 1 : 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            color: Colors.black,
            child: isVideo && !cameraOff
                ? beautyVideo(
                    renderer: localRenderer,
                    mirror: true,
                  )
                : audioAvatar(me, mine: true),
          ),
        ),
        ...remoteIds.map((id) {
          final renderer = remoteRenderers[id];
          final user = remoteUsers[id] ?? {};

          return ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              color: Colors.black,
              child: isVideo && renderer != null
                  ? beautyVideo(
                      renderer: renderer,
                      small: true,
                    )
                  : audioAvatar(user),
            ),
          );
        }),
      ],
    );
  }

  Widget beautyPanel() {
    if (!isVideo) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      top: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            beautyChip('natural', 'Natural'),
            beautyChip('bright', 'Bright'),
            beautyChip('soft', 'Soft Skin'),
            beautyChip('warm', 'Warm'),
          ],
        ),
      ),
    );
  }

  Widget beautyChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: beautyMode == value,
        label: Text(label),
        avatar: const Icon(Icons.auto_awesome, size: 16),
        onSelected: (_) {
          setState(() => beautyMode = value);
        },
      ),
    );
  }

  Widget controlBar() {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 34,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.35),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            controlButton(
              icon: muted ? Icons.mic_off : Icons.mic,
              label: muted ? 'Unmute' : 'Mute',
              color: muted ? Colors.red : Colors.white.withOpacity(.22),
              onTap: toggleMute,
            ),
            if (isVideo)
              controlButton(
                icon: cameraOff ? Icons.videocam_off : Icons.videocam,
                label: cameraOff ? 'Camera' : 'Video',
                color: cameraOff ? Colors.red : Colors.white.withOpacity(.22),
                onTap: toggleCamera,
              ),
            controlButton(
              icon: Icons.call_end,
              label: 'End',
              color: Colors.red,
              onTap: endCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name'] ?? 'Group';

    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: connecting
                ? const Center(child: CircularProgressIndicator())
                : participantGrid(),
          ),
          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  onPressed: endCall,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    '$groupName • ${widget.callType.toUpperCase()} CALL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          beautyPanel(),
          controlBar(),
        ],
      ),
    );
  }
}

class NumberParser {
  static int? toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
