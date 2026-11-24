
import 'package:flutter/material.dart';

import '../services/steps_service.dart';

class DailyActivityCard extends StatefulWidget {
  const DailyActivityCard({super.key});

  @override
  State<DailyActivityCard> createState() => _DailyActivityCardState();
}

class _DailyActivityCardState extends State<DailyActivityCard> {
  final StepsService _service = StepsService();

  DailyActivity? _activity;
  bool _loading = false;
  bool _authorized = false;
  String? _error;

  static const int _stepGoal = 10000;
  static const Color _blue = Color(0xFF0755A6);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final authorized = await _service.hasPermissions();

      if (!mounted) return;

      setState(() => _authorized = authorized);

      if (authorized) {
        await _refresh();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo comprobar Health Connect.');
    }
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authorized = await _service.requestPermissions();

      if (!mounted) return;

      if (!authorized) {
        setState(() {
          _loading = false;
          _error = 'No se han concedido los permisos necesarios.';
        });
        return;
      }

      setState(() => _authorized = true);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error al solicitar permisos.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activity = await _service.getTodayActivity();

      if (!mounted) return;

      setState(() {
        _activity = activity;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No se han podido leer los datos de actividad.';
      });
    }
  }

  String _formatNumber(double? value, {int decimals = 0}) {
    if (value == null) return '--';

    return value.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = _activity?.steps ?? 0;
    final progress = (steps / _stepGoal).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, color: _blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ACTIVIDAD DE HOY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (_authorized)
                  IconButton(
                    tooltip: 'Actualizar actividad',
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),

            if (!_authorized) ...[
              const SizedBox(height: 8),
              const Text(
                'Conecta Health Connect para consultar tus pasos, '
                'calorías y distancia.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _connect,
                  icon: const Icon(Icons.sync),
                  label: const Text('CONECTAR HEALTH CONNECT'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    steps.toString(),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'pasos',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: _blue,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Objetivo: $_stepGoal pasos',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)} %',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _metric(
                      icon: Icons.local_fire_department_outlined,
                      label: 'CALORÍAS',
                      value: _formatNumber(_activity?.calories),
                      unit: 'kcal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(
                      icon: Icons.route_outlined,
                      label: 'DISTANCIA',
                      value: _activity?.distanceMeters == null
                          ? '--'
                          : (_activity!.distanceMeters! / 1000)
                              .toStringAsFixed(2),
                      unit: 'km',
                    ),
                  ),
                ],
              ),

              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _blue),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
