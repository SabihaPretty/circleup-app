import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/app_session.dart';
import '../screens/calls/call_screen.dart';

class CallWatcher extends StatefulWidget {
  final Widget child;

  const CallWatcher({
    super.key,
    required this.child,
  });

  @override
  State<CallWatcher> createState() => _CallWatcherState();
}

class _CallWatcherState extends State<CallWatcher> {
  Timer? timer;
  bool dialogOpen = false;
  int? lastCallId;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => checkIncoming(),
    );

    Future.delayed(
      const Duration(seconds: 2),
      checkIncoming,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> checkIncoming() async {
    if (dialogOpen) return;

    final user = AppSession.currentUser;
    final userId = user?['id'];

    if (userId == null) return;

    try {
      final result = await ApiService.get('/real-calls/incoming/$userId');
      final data = result['data'];

      if (data is! Map) return;

      final callId = int.tryParse(data['id'].toString());

      if (callId == null || callId == lastCallId) return;

      lastCallId = callId;

      if (!mounted) return;

      showIncomingDialog(Map<String, dynamic>.from(data));
    } catch (_) {}
  }

  Future<void> showIncomingDialog(Map<String, dynamic> session) async {
    dialogOpen = true;

    final callType = session['callType']?.toString() ?? 'audio';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Incoming ${callType == 'video' ? 'Video' : 'Audio'} Call',
          ),
          content: const Text(
            'Someone is calling you on CircleUp.',
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await ApiService.post('/real-calls/reject', {
                  'callId': session['id'],
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              icon: const Icon(
                Icons.call_end,
                color: Colors.red,
              ),
              label: const Text('Decline'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final user = AppSession.currentUser;

                final result = await ApiService.post('/real-calls/accept', {
                  'callId': session['id'],
                  'userId': user?['id'],
                });

                final responseData = Map<String, dynamic>.from(result['data']);

                final updatedSession =
                    Map<String, dynamic>.from(responseData['session']);

                final rtc = Map<String, dynamic>.from(responseData['rtc']);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      existingSession: updatedSession,
                      existingRtc: rtc,
                      isCaller: false,
                      isIncoming: true,
                      isVideo: callType == 'video',
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

    dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
