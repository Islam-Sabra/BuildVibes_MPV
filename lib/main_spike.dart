// Review 120: the throwaway call test ("BV call test"). Never merged: the
// findings go in docs/reviews/2026-11-04-120-report.md, the code is thrown
// away. Build with -t lib/main_spike.dart and AGORA_APP_ID from env/dev.json.
//
// One screen: a channel, Join voice / Join video (HD 720p), mute, speaker,
// camera switch, Leave, and the live stats. Ringing: an FCM high-priority
// data message {type: call, channel, sent} shows the full-screen incoming
// call (flutter_callkit_incoming), also with the app swiped away.
//
// Logcat lines start with "SPIKE" and carry numbers and codes only.
import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const _appId = String.fromEnvironment('AGORA_APP_ID');
// Secured mode: the console's temporary token, for the channel "bvtest".
const _token = String.fromEnvironment('AGORA_TEMP_TOKEN');

// Also kept in a file (Android/data/<app>/files/spike.log): on mobile data
// wireless debugging is off, so the numbers are collected afterwards.
String? _logPath;

Future<void> _logInit() async {
  final dir = await getExternalStorageDirectory();
  if (dir != null) _logPath = '${dir.path}/spike.log';
}

void _log(String line) {
  final s = 'SPIKE ${DateTime.now().millisecondsSinceEpoch} $line';
  // ignore: avoid_print
  print(s);
  final p = _logPath;
  if (p != null) File(p).writeAsStringSync('$s\n', mode: FileMode.append);
}

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage m) async {
  await Firebase.initializeApp();
  await _logInit();
  await _ring(m, 'background');
}

Future<void> _ring(RemoteMessage m, String where) async {
  if (m.data['type'] != 'call') return;
  final sent = int.tryParse('${m.data['sent']}') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  _log('ring where=$where sent=$sent recv=$now');
  await FlutterCallkitIncoming.showCallkitIncoming(
    CallKitParams(
      id: '${m.data['id'] ?? now}',
      nameCaller: 'BV call test',
      appName: 'BV call test',
      handle: '${m.data['channel'] ?? 'bvtest'}',
      type: 0,
      duration: 45000,
      extra: {'channel': '${m.data['channel'] ?? 'bvtest'}'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowCallID: false,
        isShowFullLockedScreen: true,
        isFullScreen: true,
        isImportant: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1B2A41',
        actionColor: '#2E7D32',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming call',
        missedCallNotificationChannelName: 'Missed call',
        textAccept: 'Answer',
        textDecline: 'Decline',
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _logInit();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  FirebaseMessaging.onMessage.listen((m) => _ring(m, 'foreground'));
  runApp(const MaterialApp(title: 'BV call test', home: SpikeScreen()));
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final _channel = TextEditingController(text: 'bvtest');
  RtcEngine? _engine;
  StreamSubscription<CallEvent?>? _events;
  bool _joined = false;
  bool _video = false;
  bool _muted = false;
  bool _speaker = true;
  int? _remote;
  String? _push;
  final _clock = Stopwatch();
  int? _joinMs;
  int? _firstAudioMs;
  RtcStats? _rtc;
  RemoteAudioStats? _audio;
  RemoteVideoStats? _rVideo;
  LocalVideoStats? _lVideo;
  QualityType? _tx;
  QualityType? _rx;
  String _state = 'idle';

  @override
  void initState() {
    super.initState();
    _setUp();
  }

  Future<void> _setUp() async {
    await [Permission.microphone, Permission.camera, Permission.notification]
        .request();
    if (!await FlutterCallkitIncoming.canUseFullScreenIntent()) {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    }
    final token = await FirebaseMessaging.instance.getToken();
    // The token goes to logcat only, for sending the test ring from the PC.
    _log('token $token');
    _events = FlutterCallkitIncoming.onEvent.listen((e) {
      if (e is CallEventActionCallAccept) {
        _log('accept');
        final channel = e.callKitParams.extra?['channel'];
        if (channel is String) _channel.text = channel;
        _join(video: false);
      }
    });
    // Answered from the full-screen call while the app was closed.
    final active = await FlutterCallkitIncoming.activeCalls();
    if (active.isNotEmpty && active.first.isAccepted) {
      _log('accepted-cold');
      _join(video: false);
    }
    if (mounted) setState(() => _push = token);
  }

  Future<RtcEngine> _engineReady() async {
    if (_engine != null) return _engine!;
    final e = createAgoraRtcEngine();
    await e.initialize(
      const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    e.registerEventHandler(
      RtcEngineEventHandler(
        onError: (err, msg) => _log('error code=${err.value()}'),
        onJoinChannelSuccess: (c, elapsed) {
          _joinMs = _clock.elapsedMilliseconds;
          _log('joined ms=$_joinMs sdk=$elapsed');
          setState(() => _joined = true);
        },
        onUserJoined: (c, uid, elapsed) {
          _log('remote-joined ms=${_clock.elapsedMilliseconds}');
          setState(() => _remote = uid);
        },
        onUserOffline: (c, uid, reason) {
          _log('remote-left reason=${reason.value()}');
          setState(() => _remote = null);
        },
        onFirstRemoteAudioFrame: (c, uid, elapsed) {
          _firstAudioMs ??= _clock.elapsedMilliseconds;
          _log('first-audio ms=$_firstAudioMs sdk=$elapsed');
          setState(() {});
        },
        onConnectionStateChanged: (c, state, reason) {
          _log('state=${state.value()} reason=${reason.value()}');
          setState(() => _state = state.name);
        },
        onRtcStats: (c, s) {
          _log(
            'rtc rtt=${s.gatewayRtt} last=${s.lastmileDelay} '
            'txloss=${s.txPacketLossRate} rxloss=${s.rxPacketLossRate} '
            'tx=${s.txKBitRate} rx=${s.rxKBitRate} cpu=${s.cpuAppUsage}',
          );
          setState(() => _rtc = s);
        },
        onNetworkQuality: (c, uid, tx, rx) {
          if (uid != 0) return;
          _log('quality tx=${tx.value()} rx=${rx.value()}');
          setState(() {
            _tx = tx;
            _rx = rx;
          });
        },
        onRemoteAudioStats: (c, s) {
          _log(
            'raudio q=${s.quality} delay=${s.networkTransportDelay} '
            'e2e=${s.e2eDelay} loss=${s.audioLossRate} '
            'frozen=${s.frozenRate} mos=${s.mosValue} kbps=${s.receivedBitrate}',
          );
          setState(() => _audio = s);
        },
        onRemoteVideoStats: (c, s) {
          _log(
            'rvideo ${s.width}x${s.height} fps=${s.decoderOutputFrameRate} '
            'kbps=${s.receivedBitrate} loss=${s.packetLossRate} '
            'frozen=${s.frozenRate} delay=${s.delay}',
          );
          setState(() => _rVideo = s);
        },
        onLocalVideoStats: (c, type, s) {
          _log(
            'lvideo ${s.encodedFrameWidth}x${s.encodedFrameHeight} '
            'fps=${s.sentFrameRate} kbps=${s.sentBitrate}',
          );
          setState(() => _lVideo = s);
        },
      ),
    );
    _engine = e;
    return e;
  }

  Future<void> _join({required bool video}) async {
    if (_joined) return;
    final e = await _engineReady();
    _clock
      ..reset()
      ..start();
    _joinMs = null;
    _firstAudioMs = null;
    _log('join video=$video');
    await e.enableAudio();
    if (video) {
      await e.enableVideo();
      await e.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 30,
        ),
      );
      await e.startPreview();
    } else {
      await e.disableVideo();
    }
    await e.setDefaultAudioRouteToSpeakerphone(_speaker);
    await e.joinChannel(
      token: _token,
      channelId: _channel.text.trim(),
      uid: 0,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );
    setState(() => _video = video);
  }

  Future<void> _leave() async {
    final e = _engine;
    if (e == null) return;
    await e.leaveChannel();
    if (_video) await e.stopPreview();
    await FlutterCallkitIncoming.endAllCalls();
    _log('leave ms=${_clock.elapsedMilliseconds}');
    setState(() {
      _joined = false;
      _remote = null;
      _rtc = null;
      _audio = null;
      _rVideo = null;
      _lVideo = null;
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _engine?.release();
    _channel.dispose();
    super.dispose();
  }

  String _ms(int? v) => v == null ? '-' : '${(v / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    final r = _rtc;
    final a = _audio;
    final rows = <(String, String)>[
      ('App ID set', _appId.isEmpty ? 'NO' : 'yes'),
      ('Push token', _push == null ? 'no' : 'yes'),
      ('Agora token set', _token.isEmpty ? 'NO' : 'yes'),
      ('State', _state),
      ('Join → joined', _ms(_joinMs)),
      ('Join → first audio', _ms(_firstAudioMs)),
      ('Round trip (gateway)', r == null ? '-' : '${r.gatewayRtt} ms'),
      ('Last mile delay', r == null ? '-' : '${r.lastmileDelay} ms'),
      (
        'Packet loss up / down',
        r == null ? '-' : '${r.txPacketLossRate}% / ${r.rxPacketLossRate}%',
      ),
      (
        'Quality up / down (1 best, 6 down)',
        _tx == null ? '-' : '${_tx!.value()} / ${_rx!.value()}',
      ),
      (
        'Bitrate up / down',
        r == null ? '-' : '${r.txKBitRate} / ${r.rxKBitRate} kbps',
      ),
      (
        'Remote audio',
        a == null
            ? '-'
            : 'q ${a.quality}, ${a.e2eDelay} ms e2e, loss ${a.audioLossRate}%, '
                  'frozen ${a.frozenRate}%',
      ),
      if (_video)
        (
          'Video sent',
          _lVideo == null
              ? '-'
              : '${_lVideo!.encodedFrameWidth}x${_lVideo!.encodedFrameHeight} '
                    '${_lVideo!.sentFrameRate} fps ${_lVideo!.sentBitrate} kbps',
        ),
      if (_video)
        (
          'Video received',
          _rVideo == null
              ? '-'
              : '${_rVideo!.width}x${_rVideo!.height} '
                    '${_rVideo!.decoderOutputFrameRate} fps '
                    '${_rVideo!.receivedBitrate} kbps',
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('BV call test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _channel,
            decoration: const InputDecoration(labelText: 'Channel'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _joined ? null : () => _join(video: false),
                child: const Text('Join voice'),
              ),
              FilledButton(
                onPressed: _joined ? null : () => _join(video: true),
                child: const Text('Join video (HD 720p)'),
              ),
              OutlinedButton(
                onPressed: e == null || !_joined
                    ? null
                    : () async {
                        await e.muteLocalAudioStream(!_muted);
                        setState(() => _muted = !_muted);
                      },
                child: Text(_muted ? 'Unmute' : 'Mute'),
              ),
              OutlinedButton(
                onPressed: e == null || !_joined
                    ? null
                    : () async {
                        await e.setEnableSpeakerphone(!_speaker);
                        setState(() => _speaker = !_speaker);
                      },
                child: Text(_speaker ? 'Speaker: on' : 'Speaker: off'),
              ),
              OutlinedButton(
                onPressed: e == null || !_joined || !_video
                    ? null
                    : () => e.switchCamera(),
                child: const Text('Switch camera'),
              ),
              OutlinedButton(
                onPressed: _joined ? _leave : null,
                child: const Text('Leave'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(k)),
                  Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (_video && e != null && _joined) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: Row(
                children: [
                  Expanded(
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: e,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _remote == null
                        ? const Center(child: Text('Waiting for the other phone'))
                        : AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: e,
                              canvas: VideoCanvas(uid: _remote),
                              connection: RtcConnection(
                                channelId: _channel.text.trim(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
