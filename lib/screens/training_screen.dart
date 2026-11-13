
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
  final Map<String, bool> _reduceNextLoad = {};
  final Map<String, List<_LastSetRecord>> _latestSessionSets = {};
  final Map<String, bool> _latestDeloadFlags = {};

  final TextEditingController _observations = TextEditingController();
  final TextEditingController _bodyWeight = TextEditingController();

  List<CompletedWorkoutEntry> _workoutHistory = [];

  Timer? _timer;
  Timer? _autosaveTimer;

  StreamSubscription<List<CompletedWorkoutEntry>>? _historySubscription;

  Future<void> _saveQueue = Future<void>.value();

  int _secondsLeft = 0;
  String? _restExerciseId;

  bool _saving = false;
  bool _automaticTrainingEnabled = false;

  bool _loadingSession = true;
  bool _sessionLoaded = false;
  bool _hasExistingSession = false;
  bool _allowPop = false;
  bool _leaving = false;

  String _sessionStatus = 'inProgress';

  double? _previousBodyWeight;

  late final DateTime _sessionDate;

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

    _sessionDate = DateTime.now();

    for (final exercise in widget.workout.exercises) {
      _weights[exercise.id] = TextEditingController();
      _reps[exercise.id] = TextEditingController();
      _results[exercise.id] = [];
      _reduceNextLoad[exercise.id] = false;

      _weights[exercise.id]!.addListener(_scheduleAutosave);
      _reps[exercise.id]!.addListener(_scheduleAutosave);
    }

    _observations.addListener(_scheduleAutosave);
    _bodyWeight.addListener(_scheduleAutosave);

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      _historySubscription = CalendarService()
          .watchAllCompletedWorkouts(uid)
          .listen(_loadRmRecords);

      _initializeSession(uid);
      _loadAutomaticTrainingSetting(uid);
    } else {
      _loadingSession = false;
      _sessionLoaded = true;
    }
  }

  Future<void> _initializeSession(String uid) async {
    try {
      final session = await CalendarService().getWorkoutSession(
        uid: uid,
        workout: widget.workout,
        date: _sessionDate,
      );

      if (!mounted) return;

      setState(() {
        if (session != null) {
          _hasExistingSession = true;
          _sessionStatus = session.status;
          _observations.text = session.notes;

          if (session.bodyWeight != null) {
            _bodyWeight.text = _formatWeight(session.bodyWeight!);
          }

          for (final exercise in widget.workout.exercises) {
            _results[exercise.id] = [];
            _reduceNextLoad[exercise.id] = false;
          }

          for (final savedExercise in session.results) {
            final exerciseId = savedExercise['exerciseId']?.toString();

            ExerciseModel? exercise;

            for (final candidate in widget.workout.exercises) {
              if (candidate.id == exerciseId) {
                exercise = candidate;
                break;
              }
            }

            // Compatibilidad por nombre si el ID no coincide.
            if (exercise == null) {
              final savedName = savedExercise['exerciseName']
                  ?.toString()
                  .trim()
                  .toLowerCase();

              for (final candidate in widget.workout.exercises) {
                if (candidate.name.trim().toLowerCase() == savedName) {
                  exercise = candidate;
                  break;
                }
              }
            }

            if (exercise == null) continue;

            _reduceNextLoad[exercise.id] =
                savedExercise['reduceNextLoad'] == true;

            final savedSets = savedExercise['sets'] as List<dynamic>? ?? [];

            _results[exercise.id] = savedSets
                .whereType<Map>()
                .map((set) => Map<String, dynamic>.from(set))
                .toList();

            _results[exercise.id]!.sort((a, b) {
              final aNumber = (a['setNumber'] as num?)?.toInt() ?? 0;
              final bNumber = (b['setNumber'] as num?)?.toInt() ?? 0;
              return aNumber.compareTo(bNumber);
            });
          }
        }

        _loadingSession = false;
        _sessionLoaded = true;

        _refreshProgressionTargets();

        if (!_hasExistingSession) {
          _prefillLastSetValues(force: _automaticTrainingEnabled);
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingSession = false;
        _sessionLoaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo recuperar la sesión: $error')),
      );
    }
  }

  Future<void> _loadAutomaticTrainingSetting(String uid) async {
    final enabled = await UserService().getAutomaticTrainingEnabled(uid);

    if (!mounted) return;

    setState(() {
      _automaticTrainingEnabled = enabled;
      _refreshProgressionTargets();

      if (_sessionLoaded && !_hasExistingSession) {
        _prefillLastSetValues(force: true);
      }
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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

        deloadFlags.putIfAbsent(
          name,
          () => exercise['reduceNextLoad'] == true,
        );

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

          if (rm > (records[name] ?? 0)) {
            records[name] = rm;
          }
        }

        if (sessionSets.isNotEmpty) {
          latestSets.putIfAbsent(name, () => sessionSets);
        }
      }
    }

    if (!mounted) return;

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

      if (_sessionLoaded && !_hasExistingSession) {
        _prefillLastSetValues(force: _automaticTrainingEnabled);
      }
    });
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

      if (targets != null) {
        _progressionTargets[key] = targets;
      }
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
        _reps[exercise.id]!.text =
            '${target?.reps ?? previous!.reps}';
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

  // ---------------------------------------------------------------------------
  // GUARDADO AUTOMÁTICO
  // ---------------------------------------------------------------------------

  void _scheduleAutosave() {
    if (!_sessionLoaded || _loadingSession || _leaving || !mounted) return;

    _autosaveTimer?.cancel();

    _autosaveTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        await _persistSession();
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar automáticamente: $error')),
        );
      }
    });
  }

  List<Map<String, dynamic>> _buildResults() {
    return [
      for (final exercise in widget.workout.exercises)
        if (_results[exercise.id]!.isNotEmpty ||
            (_reduceNextLoad[exercise.id] ?? false))
          {
            'exerciseId': exercise.id,
            'exerciseName': exercise.name,
            'muscleGroup': exercise.muscleGroup,
            'reduceNextLoad': _reduceNextLoad[exercise.id] ?? false,
            'sets': _results[exercise.id]!
                .map((set) => Map<String, dynamic>.from(set))
                .toList(),
          },
    ];
  }

  Future<void> _persistSession({String? status}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Future.error(Exception('No hay un usuario autenticado.'));
    }

    final enteredBodyWeight = _bodyWeight.text.trim();

    final bodyWeight = enteredBodyWeight.isEmpty
        ? null
        : double.tryParse(enteredBodyWeight.replaceAll(',', '.'));

    final sessionStatus = status ?? _sessionStatus;

    final results = _buildResults();
    final notes = _observations.text.trim();

    final task = _saveQueue.then((_) {
      return CalendarService().saveWorkoutSession(
        uid: uid,
        workout: widget.workout,
        date: _sessionDate,
        status: sessionStatus,
        notes: notes,
        bodyWeight: bodyWeight,
        results: results,
      );
    });

    // Permite que los siguientes guardados continúen aunque uno falle.
    _saveQueue = task.catchError((Object error) {
      // El error se comunica al solicitante del guardado original.
    });

    return task;
  }

  Future<void> _flushAutosave() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;

    await _saveQueue;
    await _persistSession();
  }

  // ---------------------------------------------------------------------------
  // SERIES Y EJERCICIOS
  // ---------------------------------------------------------------------------

  void _removeSet(ExerciseModel exercise, int index) {
    setState(() {
      _results[exercise.id]!.removeAt(index);

      for (var i = 0; i < _results[exercise.id]!.length; i++) {
        _results[exercise.id]![i]['setNumber'] = i + 1;
      }
    });

    _scheduleAutosave();
  }

  // Temporizador asociado al ejercicio que acaba de registrar una serie.
  void _startRest(int seconds, {required String exerciseId}) {
    _timer?.cancel();

    if (seconds <= 0) {
      setState(() {
        _secondsLeft = 0;
        _restExerciseId = null;
      });
      return;
    }

    setState(() {
      _secondsLeft = seconds;
      _restExerciseId = exerciseId;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();

        if (mounted) {
          setState(() {
            _secondsLeft = 0;
            _restExerciseId = null;
          });
        }
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _stopRest() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      _secondsLeft = 0;
      _restExerciseId = null;
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

    const rir = 2;

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
    });

    // IMPORTANTE: se pasa el ID del ejercicio al temporizador.
    _startRest(
      exercise.restSeconds,
      exerciseId: exercise.id,
    );

    _scheduleAutosave();
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

    _scheduleAutosave();
  }

  // ---------------------------------------------------------------------------
  // FINALIZAR Y SALIR
  // ---------------------------------------------------------------------------

  Future<void> _finish() async {
    if (_saving || _leaving) return;

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
      _autosaveTimer?.cancel();

      await _persistSession(status: 'completed');

      _sessionStatus = 'completed';
      _hasExistingSession = true;

      await _closeScreen();
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    }
  }

  Future<void> _leaveScreen() async {
    if (_leaving || _saving) return;

    _leaving = true;

    try {
      if (_sessionLoaded) {
        await _flushAutosave();
      }

      await _closeScreen();
    } catch (error) {
      _leaving = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la sesión: $error')),
      );
    }
  }

  Future<void> _closeScreen() async {
    if (!mounted) return;

    setState(() {
      _allowPop = true;
      _saving = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final exercises = [...widget.workout.exercises]
      ..sort((a, b) => a.order.compareTo(b.order));

    final plannedSets = exercises.fold(0, (total, item) => total + item.sets);

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_allowPop) {
          _leaveScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name.toUpperCase()),
          actions: [
            IconButton(
              tooltip: 'Cronómetro',
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StopwatchScreen(),
                ),
              ),
            ),
          ],
        ),
        body: _loadingSession
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  if (_hasExistingSession && _sessionStatus == 'completed')
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.edit_note),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sesión completada. Puedes editarla y los cambios se guardarán automáticamente.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _bodyWeightSection(),
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
                              hintText:
                                  'Anota sensaciones, molestias o ajustes para la próxima sesión',
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
            onPressed: _saving || _loadingSession ? null : _finish,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              _saving ? 'GUARDANDO' : 'FINALIZAR ENTRENAMIENTO',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
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
              onPressed: () => showBodyWeightProgress(
                context,
                _workoutHistory,
              ),
              icon: const Icon(Icons.show_chart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restTimer() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
            onPressed: _stopRest,
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Añadir 30 segundos',
            onPressed: () => setState(() => _secondsLeft += 30),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
            ),
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
                            : '${sets[index]['weight']} kg × ${sets[index]['reps']}',
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
                                : previousSet == null
                                    ? null
                                    : _formatWeight(previousSet.weight),
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
                                : previousSet?.reps.toString(),
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
                      title: const Text(
                        'Fatiga alta o técnica comprometida',
                      ),
                      subtitle: const Text(
                        'Reducir la carga de la próxima sesión',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _reduceNextLoad[exercise.id] = value ?? false;
                        });

                        _scheduleAutosave();
                      },
                    ),
                ],
              ),

            // El temporizador solo aparece debajo del ejercicio asociado.
            if (_secondsLeft > 0 &&
                _restExerciseId == exercise.id)
              _restTimer(),
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
