import 'dart:async';
import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  final dynamic contact;
  final dynamic receiver;
  final dynamic user;
  final dynamic peer;
  final dynamic caller;
  final dynamic callee;
  final dynamic remoteUser;
  final dynamic localUser;

  final String? peerName;
  final String? receiverName;
  final String? name;
  final String? title;
  final String? callType;
  final String? roomId;
  final String? callId;

  final bool callIsVideo;
  final bool callIsIncoming;
  final bool callIsGroup;
  final bool isCaller;

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
  bool connected = false;
  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = true;

  int seconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    if (widget.isCaller || !widget.callIsIncoming) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        connectCall();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
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
      } else if (item != null) {
        final text = item.toString();
        if (text.trim().isNotEmpty && text != 'null') {
          return text;
        }
      }
    }

    return widget.callIsGroup ? 'Group Call' : 'CircleUp Call';
  }

  void connectCall() {
    if (connected) return;

    setState(() {
      connected = true;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        seconds++;
      });
    });
  }

  void endCall() {
    timer?.cancel();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String get durationText {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
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
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(.85),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget avatarCircle() {
    final letter = displayName.trim().isEmpty
        ? 'C'
        : displayName.trim()[0].toUpperCase();

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xff5b4bff),
            Color(0xffb026ff),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget videoPanel() {
    if (!widget.callIsVideo) {
      return avatarCircle();
    }

    return Container(
      height: 310,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff111827),
            Color(0xff312e81),
            Color(0xff6d28d9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.35),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: cameraOff
                ? const Icon(
                    Icons.videocam_off,
                    color: Colors.white,
                    size: 72,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 72,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Container(
              width: 96,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.30),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(.25)),
              ),
              child: const Center(
                child: Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'Beauty filter ready',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget incomingActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        roundButton(
          icon: Icons.call_end,
          label: 'Decline',
          background: Colors.red,
          color: Colors.white,
          onTap: endCall,
        ),
        const SizedBox(width: 42),
        roundButton(
          icon: widget.callIsVideo ? Icons.videocam : Icons.call,
          label: 'Accept',
          background: Colors.green,
          color: Colors.white,
          onTap: connectCall,
        ),
      ],
    );
  }

  Widget connectedActions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 18,
      children: [
        roundButton(
          icon: muted ? Icons.mic_off : Icons.mic,
          label: muted ? 'Muted' : 'Mute',
          onTap: () => setState(() => muted = !muted),
        ),
        if (widget.callIsVideo)
          roundButton(
            icon: cameraOff ? Icons.videocam_off : Icons.videocam,
            label: cameraOff ? 'Camera Off' : 'Camera',
            onTap: () => setState(() => cameraOff = !cameraOff),
          ),
        roundButton(
          icon: speakerOn ? Icons.volume_up : Icons.volume_off,
          label: speakerOn ? 'Speaker' : 'Silent',
          onTap: () => setState(() => speakerOn = !speakerOn),
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
    final statusText = connected
        ? 'Connected • $durationText'
        : widget.callIsIncoming
            ? 'Incoming ${widget.callIsVideo ? 'video' : 'audio'} call'
            : 'Calling...';

    return Scaffold(
      backgroundColor: const Color(0xff070b1f),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      widget.callIsVideo ? 'Video Call' : 'Audio Call',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              videoPanel(),
              const SizedBox(height: 28),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                statusText,
                style: TextStyle(
                  color: Colors.white.withOpacity(.75),
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              connected ? connectedActions() : incomingActions(),
            ],
          ),
        ),
      ),
    );
  }
}
