import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../services/app_lock.dart';
import '../../services/temp_files.dart';

/// Huzunguka MainShell kwa Stack ili fomu isipotee wakati skrini imefungwa.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child, this.refresh});
  final Widget child;

  /// Inaweza kubadilishwa kwenye tests (hakuna plugin ya hifadhi salama).
  final Future<bool> Function()? refresh;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 45);
  bool _ready = false;
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    (widget.refresh ?? AppLock.refresh)().then((enabled) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _locked = enabled;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      TempFiles.cleanup(olderThan: const Duration(minutes: 10));
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (AppLock.enabled.value &&
          since != null &&
          DateTime.now().difference(since) > _grace) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(onUnlocked: () => setState(() => _locked = false)),
          ),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen({required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await AppLock.verify(_controller.text);
    if (!mounted) return;
    if (result.ok) {
      widget.onUnlocked();
      return;
    }
    _controller.clear();
    setState(() {
      _busy = false;
      _error = result.storageError
          ? tr(context, 'Hifadhi salama ya simu imeshindwa kusomwa. App inabaki imefungwa; jaribu tena au anzisha upya simu.',
              'Secure storage could not be read. The app stays locked; retry or restart the phone.')
          : result.lockedSeconds > 0
          ? tr(context, 'Umefungiwa kwa sekunde ${result.lockedSeconds}. Jaribu tena baadaye.',
              'Locked for ${result.lockedSeconds} seconds. Try again later.')
          : tr(context, 'PIN si sahihi.', 'Incorrect PIN.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text('MADINI', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Weka PIN ya tarakimu 6', 'Enter 6-digit PIN'),
                    errorText: _error,
                    counterText: '',
                  ),
                  onChanged: (v) {
                    if (v.length == 6) _submit();
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(tr(context, 'Fungua', 'Unlock')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
