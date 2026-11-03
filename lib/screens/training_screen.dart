import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../models/set_model.dart';
import '../models/workout_model.dart';
import '../services/calendar_service.dart';
import '../services/progression_service.dart';
import '../services/user_service.dart';
import '../widgets/body_weight_progress_dialog.dart';
import '../widgets/exercise_progress_dialog.dart';
import 'stopwatch_screen.dart';

class TrainingScreen extends StatefulWidget {
  final WorkoutModel workout;

  const TrainingScreen({super.key, required this.workout});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final Map<String, List<Map<String, dynamic>>> _results = {};
  final Map<String, TextEditingController> _weights = {};
  final Map<String, TextEditingController> _reps = {};
  final Map<String, double> _rmRecords = {};
  final Map<String, Map<int, _LastSetRecord>> _lastSetRecords = {};
  final Map<String, Map<int, ProgressionTarget>> _progressionTargets = {};
  final Map<String, Map<int, int>> _selectedRir = {};
  final Map<String, bool> _reduceNextLoad = {};
  final Map<String, List<_LastSetRecord>> _latestSessionSets = {};
  final Map<String, bool> _latestDeloadFlags = {};
  final TextEditingController _observations = TextEditingController();
  final TextEditingController _bodyWeight = TextEditingController();
  List<CompletedWorkoutEntry> _workoutHistory = [];
  Timer? _timer;
  StreamSubscription<List<CompletedWorkoutEntry>>? _historySubscription;
  int _secondsLeft = 0;
  bool _saving = false;
  bool _automaticTrainingEnabled = false;
  double? _previousBodyWeight;

  int get _completedSets =>
      _results.values.fold(0, (total, sets) => total + sets.length);

  int get _completedCardio => widget.workout.exercises
      .where(_isCardio)
      .where((exercise) => _results[exercise.id]!.isNotEmpty)
      .length;

  bool _isCardio(ExerciseModel exercise) =>
      exercise.muscleGroup == 'Cardio' || exercise.type == 'cardio';

  @override
  void initState() {
    super.initState();
    for (final exercise in widget.workout.exercises) {
      _weights[exercise.id] = TextEditingController();
      _reps[exercise.id] = TextEditingController();
      _results[exercise.id] = [];
      _selectedRir[exercise.id] = {};
      _reduceNextLoad[exercise.id] = false;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _historySubscription = CalendarService()
          .watchAllCompletedWorkouts(uid)
          .listen(_loadRmRecords);
      _loadAutomaticTrainingSetting(uid);
    }
  }

  Future<void> _loadAutomaticTrainingSetting(String uid) async {
    final enabled = await UserService().getAutomaticTrainingEnabled(uid);
    if (!mounted) return;
    setState(() {
      _automaticTrainingEnabled = enabled;
      _prefillLastSetValues(force: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _historySubscription?.cancel();
    for (final controller in [..._weights.values, ..._reps.values]) {
      controller.dispose();
    }
    _observations.dispose();
    _bodyWeight.dispose();
    super.dispose();
  }

  void _loadRmRecords(List<CompletedWorkoutEntry> workouts) {
    final records = <String, double>{};
    final lastSets = <String, Map<int, _LastSetRecord>>{};
    final latestSets = <String, List<_LastSetRecord>>{};
    final deloadFlags = <String, bool>{};
    double? lastBodyWeight;
    for (final workout in workouts) {
      if (lastBodyWeight == null && (workout.bodyWeight ?? 0) > 0) {
        lastBodyWeight = workout.bodyWeight;
      }
      for (final exercise in workout.results) {
        final name = exercise['exerciseName']?.toString().trim().toLowerCase();
        if (name == null || name.isEmpty) continue;
        deloadFlags.putIfAbsent(name, () => exercise['reduceNextLoad'] == true);
        final exerciseSets = lastSets.putIfAbsent(name, () => {});
        final sessionSets = <_LastSetRecord>[];
        for (final rawSet in exercise['sets'] as List<dynamic>? ?? []) {
          final set = Map<String, dynamic>.from(rawSet as Map);
          final weight = (set['weight'] as num?)?.toDouble() ?? 0;
          final reps = (set['reps'] as num?)?.toInt() ?? 0;
          final recordedRm = (set['rm'] as num?)?.toDouble() ?? 0;
          final rir = (set['rir'] as num?)?.toInt();
          final setNumber =
              (set['setNumber'] as num?)?.toInt() ?? sessionSets.length + 1;
          final recordedSet = _LastSetRecord(weight, reps, rir);
          sessionSets.add(recordedSet);
          if (setNumber > 0 && !exerciseSets.containsKey(setNumber)) {
            exerciseSets[setNumber] = recordedSet;
          }
          final rm = recordedRm > 0
              ? recordedRm
              : SetModel.calculateRM(weight, reps);
          if (rm > (records[name] ?? 0)) records[name] = rm;
        }
        if (sessionSets.isNotEmpty) {
          latestSets.putIfAbsent(name, () => sessionSets);
        }
      }
    }
    if (mounted) {
      setState(() {
        _rmRecords
          ..clear()
          ..addAll(records);
        _lastSetRecords
          ..clear()
          ..addAll(lastSets);
        _latestSessionSets
          ..clear()
          ..addAll(latestSets);
        _latestDeloadFlags
          ..clear()
          ..addAll(deloadFlags);
        _workoutHistory = workouts;
        if (_bodyWeight.text.isEmpty && lastBodyWeight != null) {
          _bodyWeight.text = _formatWeight(lastBodyWeight);
        }
        _previousBodyWeight = lastBodyWeight;
        _refreshProgressionTargets();
        _prefillLastSetValues(force: _automaticTrainingEnabled);
      });
    }
  }

  void _refreshProgressionTargets() {
    final previousTargets = <String, Map<int, ProgressionTarget>>{
      for (final entry in _progressionTargets.entries)
        entry.key: Map<int, ProgressionTarget>.from(entry.value),
    };
    final currentBodyWeight =
        double.tryParse(_bodyWeight.text.replaceAll(',', '.')) ??
        _previousBodyWeight;
    _progressionTargets.clear();
    for (final exercise in widget.workout.exercises) {
      final key = exercise.name.trim().toLowerCase();
      final previous = _latestSessionSets[key];
      if (previous == null) continue;
      final targets = ProgressionService.suggestNextSession(
        exercise: exercise,
        previousSets: previous
            .map(
              (set) => ProgressionSet(
                weight: set.weight,
                reps: set.reps,
                rir: set.rir,
              ),
            )
            .toList(),
        reduceNextLoad: _latestDeloadFlags[key] ?? false,
        previousBodyWeight: _previousBodyWeight,
        currentBodyWeight: currentBodyWeight,
      );
      if (targets != null) _progressionTargets[key] = targets;
    }
    if (!_automaticTrainingEnabled) return;
    for (final exercise in widget.workout.exercises) {
      final setNumber = _results[exercise.id]!.length + 1;
      final key = exercise.name.trim().toLowerCase();
      final oldTarget = previousTargets[key]?[setNumber];
      final newTarget = _progressionTargets[key]?[setNumber];
      if (oldTarget == null || newTarget == null) continue;
      if (_weights[exercise.id]!.text == _formatWeight(oldTarget.weight)) {
        _weights[exercise.id]!.text = _formatWeight(newTarget.weight);
      }
      if (_reps[exercise.id]!.text == '${oldTarget.reps}') {
        _reps[exercise.id]!.text = '${newTarget.reps}';
      }
    }
  }

  void _prefillLastSetValues({bool force = false}) {
    for (final exercise in widget.workout.exercises) {
      final nextSet = _results[exercise.id]!.length + 1;
      final key = exercise.name.trim().toLowerCase();
      final previous = _lastSetRecords[key]?[nextSet];
      ProgressionTarget? target;
      if (_automaticTrainingEnabled) {
        target = _progressionTargets[key]?[nextSet];
      }
      if (target == null && previous == null) continue;
      if (force || _weights[exercise.id]!.text.isEmpty) {
        _weights[exercise.id]!.text = _formatWeight(
          target?.weight ?? previous!.weight,
        );
      }
      if (force || _reps[exercise.id]!.text.isEmpty) {
        _reps[exercise.id]!.text = '${target?.reps ?? previous!.reps}';
      }
    }
  }

  String _formatWeight(double weight) =>
      weight == weight.roundToDouble() ? weight.toInt().toString() : '$weight';

  double _exerciseRmRecord(ExerciseModel exercise) {
    final current = _results[exercise.id] ?? const [];
    final currentBest = current.fold<double>(
      0,
      (best, set) => (set['rm'] as num).toDouble() > best
          ? (set['rm'] as num).toDouble()
          : best,
    );
    final previousBest = _rmRecords[exercise.name.trim().toLowerCase()] ?? 0;
    return currentBest > previousBest ? currentBest : previousBest;
  }

  void _removeSet(ExerciseModel exercise, int index) {
    setState(() {
      _results[exercise.id]!.removeAt(index);
      for (var i = 0; i < _results[exercise.id]!.length; i++) {
        _results[exercise.id]![i]['setNumber'] = i + 1;
      }
    });
  }

  void _startRest(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) return;
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _recordSet(ExerciseModel exercise) {
    final weight = double.tryParse(
      _weights[exercise.id]!.text.replaceAll(',', '.'),
    );
    final reps = int.tryParse(_reps[exercise.id]!.text);
    if (weight == null || weight < 0 || reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Introduce un peso y un número de repeticiones válidos.',
          ),
        ),
      );
      return;
    }
    final previous = _results[exercise.id]!;
    final rm = SetModel.calculateRM(weight, reps);
    final setNumber = previous.length + 1;
    final rir = _selectedRir[exercise.id]?[setNumber] ?? 2;
    setState(() {
      previous.add({
        'setNumber': setNumber,
        'weight': weight,
        'reps': reps,
        'rir': rir,
        'rm': rm,
        'completed': true,
      });
      _weights[exercise.id]!.clear();
      _reps[exercise.id]!.clear();
      _prefillLastSetValues();
      _secondsLeft = exercise.restSeconds;
    });
    _startRest(exercise.restSeconds);
  }

  void _completeCardio(ExerciseModel exercise) {
    setState(() {
      _results[exercise.id]!.add({
        'setNumber': 1,
        'weight': 0,
        'reps': 0,
        'rm': 0,
        'durationSeconds': exercise.durationSeconds ?? 0,
        'completed': true,
      });
    });
  }

  Future<void> _finish() async {
    final enteredBodyWeight = _bodyWeight.text.trim();
    final bodyWeight = enteredBodyWeight.isEmpty
        ? null
        : double.tryParse(enteredBodyWeight.replaceAll(',', '.'));
    if (enteredBodyWeight.isNotEmpty &&
        (bodyWeight == null || bodyWeight <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un peso corporal válido.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await CalendarService().saveCompletedWorkout(
        uid: FirebaseAuth.instance.currentUser!.uid,
        workout: widget.workout,
        date: DateTime.now(),
        notes: _observations.text.trim(),
        bodyWeight: bodyWeight,
        results: [
          for (final exercise in widget.workout.exercises)
            if (_results[exercise.id]!.isNotEmpty ||
                (_reduceNextLoad[exercise.id] ?? false))
              {
                'exerciseId': exercise.id,
                'exerciseName': exercise.name,
                'muscleGroup': exercise.muscleGroup,
                'reduceNextLoad': _reduceNextLoad[exercise.id] ?? false,
                'sets': _results[exercise.id],
              },
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    }
  }

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final exercises = [...widget.workout.exercises]
      ..sort((a, b) => a.order.compareTo(b.order));
    final plannedSets = exercises.fold(0, (total, item) => total + item.sets);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name.toUpperCase()),
        actions: [
          IconButton(
            tooltip: 'Cronómetro',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StopwatchScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _bodyWeightSection(),
          if (_secondsLeft > 0) _restTimer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_completedSets series · $_completedCardio cardio completados',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$plannedSets previstas',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final exercise in exercises) _exerciseEntry(exercise),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OBSERVACIONES',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _observations,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Anota sensaciones, molestias o ajustes para la próxima sesión',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _finish,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? 'GUARDANDO' : 'FINALIZAR ENTRENAMIENTO'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
      ),
    );
  }

  Widget _bodyWeightSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bodyWeight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Peso corporal',
                  suffixText: 'kg',
                  border: InputBorder.none,
                ),
                onChanged: _automaticTrainingEnabled
                    ? (_) => setState(_refreshProgressionTargets)
                    : null,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Ver evolución del peso corporal',
              onPressed: () => showBodyWeightProgress(context, _workoutHistory),
              icon: const Icon(Icons.show_chart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restTimer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17352F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF4DD0A1).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF4DD0A1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'DESCANSO  ${_formatTime(_secondsLeft)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Detener descanso',
            onPressed: () {
              _timer?.cancel();
              setState(() => _secondsLeft = 0);
            },
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Añadir 30 segundos',
            onPressed: () => setState(() => _secondsLeft += 30),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _exerciseEntry(ExerciseModel exercise) {
    final sets = _results[exercise.id]!;
    final isCardio = _isCardio(exercise);
    final durationMinutes = ((exercise.durationSeconds ?? 0) / 60).ceil();
    final exerciseKey = exercise.name.trim().toLowerCase();
    final rmRecord = _exerciseRmRecord(exercise);
    final nextSet = sets.length + 1;
    final previousSet = _lastSetRecords[exerciseKey]?[nextSet];
    ProgressionTarget? progressionTarget;
    if (_automaticTrainingEnabled) {
      progressionTarget = _progressionTargets[exerciseKey]?[nextSet];
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => showExerciseProgress(context, exercise),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              exercise.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.show_chart,
                            size: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  isCardio
                      ? sets.isEmpty
                            ? '$durationMinutes min'
                            : 'Completado'
                      : rmRecord > 0
                      ? 'RM PR ${rmRecord.toStringAsFixed(1)} kg'
                      : 'RM PR --',
                  style: const TextStyle(
                    color: Color(0xFF4DD0A1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isCardio) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${sets.length}/${exercise.sets}',
                    style: const TextStyle(
                      color: Color(0xFF4DD0A1),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              isCardio
                  ? 'Cardio · $durationMinutes minutos'
                  : '${exercise.muscleGroup} · ${exercise.minReps}-${exercise.maxReps} reps · descanso ${exercise.restSeconds}s',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (sets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < sets.length; index++)
                    InputChip(
                      label: Text(
                        isCardio
                            ? 'Cardio · $durationMinutes min'
                            : '${sets[index]['weight']} kg × ${sets[index]['reps']} · RIR ${sets[index]['rir'] ?? '--'}',
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeSet(exercise, index),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (isCardio)
              FilledButton.tonalIcon(
                onPressed: sets.isEmpty
                    ? () => _completeCardio(exercise)
                    : () => _removeSet(exercise, 0),
                icon: Icon(
                  sets.isEmpty ? Icons.check_circle_outline : Icons.undo,
                ),
                label: Text(
                  sets.isEmpty ? 'Marcar cardio completado' : 'Deshacer',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weights[exercise.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Peso',
                            suffixText: 'kg',
                            helperText: progressionTarget != null
                                ? 'Sugerido: ${_formatWeight(progressionTarget.weight)} kg'
                                : 'Serie $nextSet anterior: ${previousSet == null ? 'sin registro' : '${_formatWeight(previousSet.weight)} kg'}',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _reps[exercise.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Reps',
                            helperText: progressionTarget != null
                                ? 'Sugeridas: ${progressionTarget.reps}'
                                : previousSet == null
                                ? 'Últimas repeticiones: --'
                                : 'Últimas repeticiones: ${previousSet.reps}',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Registrar serie e iniciar descanso',
                        onPressed: () => _recordSet(exercise),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RIR',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selectedRir[exercise.id]?[nextSet] ?? 2,
                          underline: const SizedBox.shrink(),
                          isDense: true,
                          items: List.generate(
                            4,
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedRir[exercise.id]![nextSet] = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (progressionTarget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          progressionTarget.deload
                              ? 'Reducimos carga para priorizar técnica.'
                              : progressionTarget.increasedLoad
                              ? 'Rango completado. Subimos el incremento mínimo.'
                              : progressionTarget.belowMinimum
                              ? 'Mantenemos carga e intentamos alcanzar el mínimo.'
                              : 'Mantenemos carga. Busca 1 rep más por serie.',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  if (_automaticTrainingEnabled)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _reduceNextLoad[exercise.id] ?? false,
                      title: const Text('Fatiga alta o técnica comprometida'),
                      subtitle: const Text(
                        'Reducir la carga de la próxima sesión',
                      ),
                      onChanged: (value) => setState(
                        () => _reduceNextLoad[exercise.id] = value ?? false,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LastSetRecord {
  final double weight;
  final int reps;
  final int? rir;

  const _LastSetRecord(this.weight, this.reps, this.rir);
}
