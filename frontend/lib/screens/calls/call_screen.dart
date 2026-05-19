import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/api_config.dart';
import '../../core/app_session.dart';
import '../../core/app_theme.dart';

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> remoteUser;
  final String callType;
  final bool isCaller;
  final String? callId;

  const CallScreen({
    super.key,
    required this.remoteUser,
    required this.callType,
    required this.isCaller,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;

  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = true;
  bool remoteConnected = false;
  bool offerCreated = false;
  bool closing = false;

  late String callId;
  String statusText = 'Preparing call...';

  Map<String, dynamic> get me => AppSession.currentUser ?? {};
  int get myId => me['id'] ?? 0;
  int get remoteId => widget.remoteUser['id'] ?? 0;
  bool get isVideoCall => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    callId = widget.callId ?? 'call_${DateTime.now().microsecondsSinceEpoch}';
    start();
  }

  @override
  void dispose() {
    cleanup(sendEnd: false);
    super.dispose();
  }

  Future<void> start() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    await openMedia();
    connectSocket();
  }

  Future<void> openMedia() async {
    try {
      final constraints = {
        'audio': true,
        'video': isVideoCall
            ? {
                'facingMode': 'user',
              }
            : false,
      };

      localStream = await navigator.mediaDevices.getUserMedia(constraints);

      localRenderer.srcObject = localStream;

      peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });

      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        socket?.emit('webrtc_ice_candidate', {
          'callId': callId,
          'fromId': myId,
          'targetId': remoteId,
          'candidate': candidate.toMap(),
        });
      };

      peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
          if (mounted) {
            setState(() {
              remoteConnected = true;
              statusText = 'Connected';
            });
          }
        }
      };

      for (final track in localStream!.getTracks()) {
        await peerConnection!.addTrack(track, localStream!);
      }

      if (mounted) {
        setState(() {
          statusText = widget.isCaller ? 'Calling...' : 'Waiting for call...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          statusText = 'Camera/Microphone permission failed';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call media failed: $e')),
        );
      }
    }
  }

  void connectSocket() {
    socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
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
      socket!.emit('join_user', {
        'userId': myId,
      });

      if (widget.isCaller) {
        socket!.emit('call_user', {
          'callId': callId,
          'callerId': myId,
          'receiverId': remoteId,
          'callType': widget.callType,
          'caller': me,
        });
      } else {
        socket!.emit('call_ready', {
          'callId': callId,
          'callerId': remoteId,
          'receiverId': myId,
        });
      }
    });

    socket!.on('call_accepted', (data) {
      if (!sameCall(data)) return;

      if (mounted) {
        setState(() {
          statusText = 'Call accepted. Connecting...';
        });
      }
    });

    socket!.on('receiver_ready', (data) async {
      if (!sameCall(data)) return;

      if (widget.isCaller && !offerCreated) {
        await createOffer();
      }
    });

    socket!.on('call_rejected', (data) {
      if (!sameCall(data)) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call rejected')),
        );
        Navigator.pop(context);
      }
    });

    socket!.on('call_ended', (data) {
      if (!sameCall(data)) return;

      if (!closing && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call ended')),
        );
        Navigator.pop(context);
      }
    });

    socket!.on('webrtc_offer', (data) async {
      if (!sameCall(data)) return;
      await handleOffer(Map<String, dynamic>.from(data));
    });

    socket!.on('webrtc_answer', (data) async {
      if (!sameCall(data)) return;
      await handleAnswer(Map<String, dynamic>.from(data));
    });

    socket!.on('webrtc_ice_candidate', (data) async {
      if (!sameCall(data)) return;
      await handleIceCandidate(Map<String, dynamic>.from(data));
    });

    socket!.connect();
  }

  bool sameCall(dynamic data) {
    if (data == null) return false;

    final map = Map<String, dynamic>.from(data as Map);
    return map['callId'] == callId;
  }

  Future<void> createOffer() async {
    if (peerConnection == null) return;

    offerCreated = true;

    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    socket?.emit('webrtc_offer', {
      'callId': callId,
      'fromId': myId,
      'targetId': remoteId,
      'sdp': offer.sdp,
      'type': offer.type,
    });

    if (mounted) {
      setState(() {
        statusText = 'Connecting peer...';
      });
    }
  }

  Future<void> handleOffer(Map<String, dynamic> data) async {
    if (peerConnection == null) return;

    final offer = RTCSessionDescription(
      data['sdp'],
      data['type'],
    );

    await peerConnection!.setRemoteDescription(offer);

    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    socket?.emit('webrtc_answer', {
      'callId': callId,
      'fromId': myId,
      'targetId': remoteId,
      'sdp': answer.sdp,
      'type': answer.type,
    });

    if (mounted) {
      setState(() {
        statusText = 'Answer sent. Connecting...';
      });
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    if (peerConnection == null) return;

    final answer = RTCSessionDescription(
      data['sdp'],
      data['type'],
    );

    await peerConnection!.setRemoteDescription(answer);

    if (mounted) {
      setState(() {
        statusText = 'Connected';
      });
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    if (peerConnection == null) return;

    try {
      final candidateData = Map<String, dynamic>.from(data['candidate']);

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await peerConnection!.addCandidate(candidate);
    } catch (_) {}
  }

  void toggleMute() {
    muted = !muted;

    for (final track in localStream?.getAudioTracks() ?? []) {
      track.enabled = !muted;
    }

    setState(() {});
  }

  void toggleCamera() {
    if (!isVideoCall) return;

    cameraOff = !cameraOff;

    for (final track in localStream?.getVideoTracks() ?? []) {
      track.enabled = !cameraOff;
    }

    setState(() {});
  }

  Future<void> cleanup({required bool sendEnd}) async {
    closing = true;

    if (sendEnd) {
      socket?.emit('end_call', {
        'callId': callId,
        'fromId': myId,
        'targetId': remoteId,
      });
    }

    try {
      await peerConnection?.close();
      await localStream?.dispose();
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}
  }

  Future<void> endCall() async {
    await cleanup(sendEnd: true);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget avatarCallView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 58,
          backgroundColor: Colors.white,
          child: Text(
            (widget.remoteUser['nickname'] ?? widget.remoteUser['name'] ?? 'U')
                .toString()
                .substring(0, 1)
                .toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.remoteUser['nickname'] ?? widget.remoteUser['name'] ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(
            color: Colors.white.withOpacity(.86),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget videoCallView() {
    return Stack(
      children: [
        Positioned.fill(
          child: remoteConnected
              ? RTCVideoView(
                  remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.darkGradient,
                  ),
                  child: avatarCallView(),
                ),
        ),
        Positioned(
          right: 18,
          top: 70,
          child: Container(
            width: 115,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: cameraOff
                ? const Center(
                    child: Icon(Icons.videocam_off, color: Colors.white),
                  )
                : RTCVideoView(
                    localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
        ),
        Positioned(
          left: 18,
          top: 55,
          right: 150,
          child: Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget callControl({
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
          borderRadius: BorderRadius.circular(26),
          child: CircleAvatar(
            radius: 27,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: Stack(
        children: [
          Positioned.fill(
            child: isVideoCall
                ? videoCallView()
                : Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.darkGradient,
                    ),
                    child: avatarCallView(),
                  ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 38,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.28),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withOpacity(.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  callControl(
                    icon: muted ? Icons.mic_off : Icons.mic,
                    label: muted ? 'Unmute' : 'Mute',
                    color: muted ? Colors.red : Colors.white.withOpacity(.25),
                    onTap: toggleMute,
                  ),
                  if (isVideoCall)
                    callControl(
                      icon: cameraOff ? Icons.videocam_off : Icons.videocam,
                      label: cameraOff ? 'Camera' : 'Video',
                      color: cameraOff ? Colors.red : Colors.white.withOpacity(.25),
                      onTap: toggleCamera,
                    ),
                  callControl(
                    icon: Icons.call_end,
                    label: 'End',
                    color: Colors.red,
                    onTap: endCall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
