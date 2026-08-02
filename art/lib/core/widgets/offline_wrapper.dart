import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum AppConnectionState { online, offline, restored }

class OfflineWrapper extends StatefulWidget {
  final Widget child;

  const OfflineWrapper({super.key, required this.child});

  @override
  State<OfflineWrapper> createState() => _OfflineWrapperState();
}

class _OfflineWrapperState extends State<OfflineWrapper> {
  AppConnectionState _connectionState = AppConnectionState.online;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  Timer? _restoredTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionState(!results.contains(ConnectivityResult.none));
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _connectionState = !results.contains(ConnectivityResult.none)
            ? AppConnectionState.online
            : AppConnectionState.offline;
      });
    }
  }

  void _updateConnectionState(bool isNowConnected) {
    if (!mounted) return;

    if (isNowConnected && _connectionState == AppConnectionState.offline) {
      setState(() {
        _connectionState = AppConnectionState.restored;
      });
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _connectionState = AppConnectionState.online;
          });
        }
      });
    } else if (!isNowConnected) {
      _restoredTimer?.cancel();
      setState(() {
        _connectionState = AppConnectionState.offline;
      });
    }
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showOverlay = _connectionState != AppConnectionState.online;
    final isOffline = _connectionState == AppConnectionState.offline;

    return Stack(
      children: [
        widget.child,
        if (showOverlay)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PulseIcon(
                          icon: isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          color: isOffline ? Colors.redAccent : Colors.greenAccent,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isOffline ? 'You are offline' : 'Back online!',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isOffline 
                              ? 'Please check your internet connection\nto continue using the app.'
                              : 'Connection restored successfully.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                        if (isOffline) ...[
                          const SizedBox(height: 32),
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Waiting for connection...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulseIcon({required this.icon, required this.color});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      // Re-trigger animation or just let it continue pulsing with new color
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.2),
        ),
        child: Icon(widget.icon, color: widget.color, size: 80),
      ),
    );
  }
}
