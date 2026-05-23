import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api_service.dart';
import '../../core/app_session.dart';

class CallScreen extends StatefulWidget {
  final dynamic contact;
  final dynamic receiver;
  final dynamic user;
  final dynamic peer;
  final dynamic caller;
  final dynamic callee;
  final dynamic remoteUser;
  final dynamic localUser;
  final dynamic existingSession;
  final dynamic existingRtc;

  final String? peerName;
  final String? receiverName;
  final String? name;
  final String? title;
  final String? callType;
  final String? roomId;
  final String? callId;

  final bool isCaller;
  final bool callIsVideo;
  final bool callIsIncoming;
  final bool callIsGroup;

  const CallScreen({
    super.key,
    this.contact,
    this.receiver,
    this.user,
    this.peer,
    this.caller,
    this.callee,
    this.remoteUser,
    this.localUser,
    this.existingSession,
    this.existingRtc,
    this.peerName,
    this.receiverName,
    this.name,
    this.title,
    this.callType,
    this.roomId,
    this.callId,
    this.isCaller = false,
    bool? isVideo,
    bool? videoCall,
    bool? isVideoCall,
    bool? videoEnabled,
    bool? incomingCall,
    bool? isIncoming,
    bool? incoming,
    bool? groupCall,
    bool? isGroup,
    bool? group,
  })  : callIsVideo =
            videoEnabled ?? isVideo ?? videoCall ?? isVideoCall ?? callType == 'video',
        callIsIncoming = incomingCall ?? isIncoming ?? incoming ?? false,
        callIsGroup = groupCall ?? isGroup ?? group ?? false;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? engine;

  bool loading = true;
  bool joined = false;
  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = true;

  int? remoteUid;
  int seconds = 0;

  Timer? timer;

  Map<String, dynamic>? session;
  Map<String, dynamic>? rtc;

  @override
  void initState() {
    super.initState();
    prepareCall();
  }

  @override
  void dispose() {
    timer?.cancel();
    leaveAgora();
    super.dispose();
  }

  int get currentUid {
    final user = AppSession.currentUser;
    final id = user?['id'];

    return int.tryParse(id.toString()) ?? 0;
  }

  int get remoteUserId {
    final sources = [
      widget.remoteUser,
      widget.receiver,
      widget.contact,
      widget.peer,
      widget.user,
      widget.callee,
      widget.caller,
    ];

    for (final item in sources) {
      if (item is Map && item['id'] != null) {
        final id = int.tryParse(item['id'].toString());

        if (id != null && id > 0 && id != currentUid) {
          return id;
        }
      }
    }

    return 0;
  }

  String get displayName {
    final directName =
        widget.peerName ?? widget.receiverName ?? widget.name ?? widget.title;

    if (directName != null && directName.trim().isNotEmpty) {
      return directName;
    }

    final sources = [
      widget.remoteUser,
      widget.receiver,
      widget.contact,
      widget.peer,
      widget.user,
      widget.localUser,
      widget.caller,
      widget.callee,
    ];

    for (final item in sources) {
      if (item is Map) {
        final possible = item['nickname'] ??
            item['name'] ??
            item['fullName'] ??
            item['email'] ??
            item['phone'];

        if (possible != null && possible.toString().trim().isNotEmpty) {
          return possible.toString();
        }
      }
    }

    return widget.callIsGroup ? 'Group Call' : 'CircleUp Call';
  }

  Future<void> prepareCall() async {
    setState(() => loading = true);

    try {
      if (widget.existingSession is Map && widget.existingRtc is Map) {
        session = Map<String, dynamic>.from(widget.existingSession);
        rtc = Map<String, dynamic>.from(widget.existingRtc);
      } else if (widget.isCaller) {
        final receiverId = remoteUserId;

        if (currentUid == 0 || receiverId == 0) {
          throw Exception('User ID missing. Please login again.');
        }

        final result = await ApiService.post('/real-calls/start', {
          'callerId': currentUid,
          'receiverId': receiverId,
          'callType': widget.callIsVideo ? 'video' : 'audio',
        });

        final data = Map<String, dynamic>.from(result['data']);

        session = Map<String, dynamic>.from(data['session']);
        rtc = Map<String, dynamic>.from(data['rtc']);
      } else {
        throw Exception('Incoming call session missing.');
      }

      await initAgora();
    } catch (e) {
      showMessage('Call failed: ${cleanError(e)}');

      if (mounted) {
        Navigator.pop(context);
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> initAgora() async {
    final micStatus = await Permission.microphone.request();

    if (!micStatus.isGranted) {
      throw Exception('Microphone permission denied.');
    }

    if (widget.callIsVideo) {
      final camStatus = await Permission.camera.request();

      if (!camStatus.isGranted) {
        throw Exception('Camera permission denied.');
      }
    }

    final rtcData = rtc;

    if (rtcData == null) {
      throw Exception('RTC data missing.');
    }

    final appId = rtcData['appId']?.toString();
    final token = rtcData['token']?.toString();
    final channelName = rtcData['channelName']?.toString();
    final uid = int.tryParse(rtcData['uid'].toString()) ?? currentUid;

    if (appId == null || appId.isEmpty) {
      throw Exception('Agora App ID missing.');
    }

    if (token == null || token.isEmpty) {
      throw Exception('Agora token missing.');
    }

    if (channelName == null || channelName.isEmpty) {
      throw Exception('Agora channel missing.');
    }

    if (uid <= 0) {
      throw Exception('Agora uid missing.');
    }

    engine = createAgoraRtcEngine();

    await engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;

          setState(() => joined = true);

          startTimer();
        },
        onUserJoined: (connection, remoteUidValue, elapsed) {
          if (!mounted) return;

          setState(() => remoteUid = remoteUidValue);
        },
        onUserOffline: (connection, remoteUidValue, reason) {
          if (!mounted) return;

          setState(() => remoteUid = null);
        },
        onError: (errorCode, message) {
          showMessage('Agora error: $errorCode ${message ?? ''}');
        },
      ),
    );

    await engine!.enableAudio();
    await engine!.setEnableSpeakerphone(speakerOn);

    if (widget.callIsVideo) {
      await engine!.enableVideo();
      await engine!.startPreview();
    } else {
      await engine!.disableVideo();
    }

    await engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
  }

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() => seconds++);
    });
  }

  Future<void> leaveAgora() async {
    try {
      final id = session?['id'];

      if (id != null) {
        await ApiService.post('/real-calls/end', {
          'callId': id,
        });
      }
    } catch (_) {}

    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }

  Future<void> endCall() async {
    timer?.cancel();

    await leaveAgora();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> toggleMute() async {
    muted = !muted;

    await engine?.muteLocalAudioStream(muted);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;

    await engine?.muteLocalVideoStream(cameraOff);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;

    await engine?.setEnableSpeakerphone(speakerOn);

    if (mounted) {
      setState(() {});
    }
  }

  String get durationText {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');

    return '$min:$sec';
  }

  String cleanError(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget roundButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color background = const Color(0xfff1f3f8),
    Color color = const Color(0xff111827),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget avatarCircle() {
    final letter =
        displayName.trim().isEmpty ? 'C' : displayName.trim()[0].toUpperCase();

    return Center(
      child: CircleAvatar(
        radius: 72,
        backgroundColor: const Color(0xff6759ff),
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 48,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget localVideo() {
    final e = engine;

    if (e == null || !widget.callIsVideo || cameraOff) {
      return avatarCircle();
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: e,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget remoteVideo() {
    final e = engine;
    final uid = remoteUid;
    final channelName = rtc?['channelName']?.toString();

    if (e == null || !widget.callIsVideo || uid == null || channelName == null) {
      return Center(
        child: Text(
          widget.callIsVideo ? 'Waiting for remote video...' : 'Connected',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: e,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(
          channelId: channelName,
        ),
      ),
    );
  }

  Widget videoArea() {
    if (!widget.callIsVideo) return avatarCircle();

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Container(
            height: 330,
            width: double.infinity,
            color: Colors.black,
            child: remoteVideo(),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: localVideo(),
            ),
          ),
        ],
      ),
    );
  }

  Widget callControls() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 16,
      children: [
        roundButton(
          icon: muted ? Icons.mic_off : Icons.mic,
          label: muted ? 'Muted' : 'Mute',
          onTap: toggleMute,
        ),
        if (widget.callIsVideo)
          roundButton(
            icon: cameraOff ? Icons.videocam_off : Icons.videocam,
            label: cameraOff ? 'Camera Off' : 'Camera',
            onTap: toggleCamera,
          ),
        roundButton(
          icon: speakerOn ? Icons.volume_up : Icons.volume_off,
          label: speakerOn ? 'Speaker' : 'Silent',
          onTap: toggleSpeaker,
        ),
        roundButton(
          icon: Icons.call_end,
          label: 'End',
          background: Colors.red,
          color: Colors.white,
          onTap: endCall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = loading
        ? 'Connecting...'
        : joined
            ? 'Connected • $durationText'
            : 'Joining call...';

    return Scaffold(
      backgroundColor: const Color(0xff070b1f),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: endCall,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    color: Colors.white,
                  ),
                  const Spacer(),
                  Text(
                    widget.callIsVideo ? 'Real Video Call' : 'Real Audio Call',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              videoArea(),
              const SizedBox(height: 24),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              callControls(),
            ],
          ),
        ),
      ),
    );
  }
}
