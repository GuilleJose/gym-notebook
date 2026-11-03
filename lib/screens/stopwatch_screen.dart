import 'dart:async';

import 'package:flutter/material.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  final List<_StopwatchLap> _laps = [];
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _ticker?.cancel();
    } else {
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  void _recordLap() {
    final total = _stopwatch.elapsed;
    final lastTotal = _laps.isEmpty ? Duration.zero : _laps.last.total;
    setState(() {
      _laps.add(_StopwatchLap(total - lastTotal, total));
    });
  }

  void _reset() {
    _ticker?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    setState(_laps.clear);
  }

  String _format(Duration duration, {bool centiseconds = true}) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final fraction = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return centiseconds
        ? '$hours:$minutes:$seconds.$fraction'
        : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _stopwatch.isRunning;
    final elapsed = _stopwatch.elapsed;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CRONÓMETRO',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 34,
                      color: isRunning ? const Color(0xFF4DD0A1) : mutedColor,
                    ),
                    const SizedBox(height: 18),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _format(elapsed),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRunning ? 'EN MARCHA' : 'EN PAUSA',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? _recordLap : _reset,
                      icon: Icon(
                        isRunning ? Icons.flag_outlined : Icons.refresh,
                      ),
                      label: Text(isRunning ? 'VUELTA' : 'REINICIAR'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(isRunning ? 'PAUSAR' : 'INICIAR'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              flex: 3,
              child: _laps.isEmpty
                  ? Center(
                      child: Text(
                        'Las vueltas aparecerán aquí',
                        style: TextStyle(color: mutedColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: _laps.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final lapNumber = index + 1;
                        final lap = _laps[index];
                        final fastest = _laps
                            .map((item) => item.split)
                            .reduce((a, b) => a < b ? a : b);
                        final slowest = _laps
                            .map((item) => item.split)
                            .reduce((a, b) => a > b ? a : b);
                        final color = lap.split == fastest
                            ? const Color(0xFF4DD0A1)
                            : lap.split == slowest
                            ? Colors.redAccent
                            : null;
                        return ListTile(
                          dense: true,
                          leading: Text(
                            'Vuelta $lapNumber',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          title: Text(
                            _format(lap.split),
                            textAlign: TextAlign.end,
                            style: TextStyle(color: color),
                          ),
                          trailing: Text(
                            _format(lap.total, centiseconds: false),
                            style: TextStyle(color: mutedColor),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopwatchLap {
  final Duration split;
  final Duration total;

  const _StopwatchLap(this.split, this.total);
}
