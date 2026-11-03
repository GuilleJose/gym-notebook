import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../models/workout_model.dart';
import '../services/exercise_service.dart';
import '../services/user_service.dart';
import '../services/workout_service.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function(bool isDark) onDarkModeChanged;

  const SettingsScreen({super.key, required this.onDarkModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  static const groups = [
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Pierna',
    'Core',
    'Antebrazo',
    'Cardio',
    'Otros',
  ];
  static const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  final _exerciseService = ExerciseService();
  final _workoutService = WorkoutService();
  late TabController _tabs;
  late Future<_SettingsData> _data;
  bool? _automaticTrainingOverride;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _data = _load();
  }

  Future<_SettingsData> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final exercises = await _exerciseService.getCatalog(uid);
    final workouts = await _workoutService.getAllWorkouts(uid);
    final automaticTrainingEnabled = await UserService()
        .getAutomaticTrainingEnabled(uid);
    _automaticTrainingOverride ??= automaticTrainingEnabled;
    return _SettingsData(
      exercises,
      workouts,
      _automaticTrainingOverride ?? automaticTrainingEnabled,
    );
  }

  void _refresh() => setState(() => _data = _load());

  Future<void> _setAutomaticTraining(bool enabled) async {
    final previous = _automaticTrainingOverride ?? false;
    setState(() => _automaticTrainingOverride = enabled);
    try {
      await UserService().saveAutomaticTrainingEnabled(
        FirebaseAuth.instance.currentUser!.uid,
        enabled,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _automaticTrainingOverride = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la opción: $error')),
      );
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _exerciseCatalog(List<ExerciseModel> exercises) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final grouped = <String, List<ExerciseModel>>{};
    for (final exercise in exercises) {
      grouped.putIfAbsent(exercise.muscleGroup, () => []).add(exercise);
    }
    final orderedGroups = [
      ...groups,
      ...grouped.keys.where((e) => !groups.contains(e)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        for (final group in orderedGroups)
          if ((grouped[group] ?? []).isNotEmpty)
            ExpansionTile(
              initiallyExpanded: group == 'Pecho' || group == 'Pierna',
              title: Text(
                group,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Text(
                '${grouped[group]!.length}',
                style: TextStyle(color: mutedColor),
              ),
              children: [
                for (final exercise in grouped[group]!)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _editExercise(exercise),
                    child: ListTile(
                      title: Text(exercise.name),
                      subtitle: Text(_exerciseSummary(exercise)),
                      leading: const Icon(Icons.fitness_center, size: 20),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Editar ejercicio',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editExercise(exercise),
                          ),
                          IconButton(
                            tooltip: 'Eliminar ejercicio',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(exercise),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        if (exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text('Todavía no hay ejercicios en el catálogo.'),
            ),
          ),
      ],
    );
  }

  Widget _routineList(
    List<ExerciseModel> catalog,
    List<WorkoutModel> workouts,
    bool automaticTrainingEnabled,
  ) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final plannedDays = workouts.map((workout) => workout.dayOfWeek).toSet();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: const Icon(Icons.auto_graph_outlined),
          title: const Text('Calcular entrenamiento automáticamente'),
          subtitle: const Text(
            'Sugiere peso y reps para la siguiente sesión según resultados y RIR.',
          ),
          value: _automaticTrainingOverride ?? automaticTrainingEnabled,
          onChanged: _setAutomaticTraining,
        ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'PLAN SEMANAL',
                  style: TextStyle(
                    color: Color(0xFF4DD0A1),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${plannedDays.length}/7 días',
                style: TextStyle(color: mutedColor),
              ),
            ],
          ),
        ),
        for (var index = 0; index < days.length; index++)
          _weekDayTile(index + 1, catalog, workouts),
      ],
    );
  }

  Widget _weekDayTile(
    int day,
    List<ExerciseModel> catalog,
    List<WorkoutModel> workouts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final workout = workouts.where((item) => item.dayOfWeek == day).firstOrNull;
    final isToday = DateTime.now().weekday == day;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: CircleAvatar(
          backgroundColor: isToday
              ? const Color(0xFF4DD0A1)
              : const Color(0xFF303837),
          foregroundColor: isToday
              ? const Color(0xFF10201C)
              : colorScheme.onSurface,
          child: Text('$day'),
        ),
        title: Text(
          days[day - 1],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          workout == null
              ? 'Sin entrenamiento asignado'
              : workout.isRestDay
              ? 'Descanso'
              : '${workout.name} · ${workout.exercises.length} ejercicios',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          workout == null ? Icons.add_circle_outline : Icons.edit_outlined,
          color: workout == null ? const Color(0xFF4DD0A1) : null,
        ),
        onTap: () =>
            _editRoutine(catalog, workouts, workout: workout, initialDay: day),
      ),
    );
  }

  Future<void> _addExercise() async {
    await _editExercise();
  }

  String _exerciseSummary(ExerciseModel exercise) {
    if (exercise.muscleGroup == 'Cardio' || exercise.type == 'cardio') {
      final minutes = ((exercise.durationSeconds ?? 0) / 60).ceil();
      return 'Cardio · $minutes min · doble clic para editar';
    }
    return '${exercise.sets} series · ${exercise.minReps}-${exercise.maxReps} reps · doble clic para editar';
  }

  Future<void> _editExercise([ExerciseModel? exercise]) async {
    final formKey = GlobalKey<FormState>();
    var group = exercise?.muscleGroup ?? groups.first;
    final configuredIncrement = exercise?.progressionIncrementKg ?? 0;
    final name = TextEditingController(text: exercise?.name ?? '');
    final sets = TextEditingController(text: '${exercise?.sets ?? 3}');
    final minReps = TextEditingController(text: '${exercise?.minReps ?? 8}');
    final maxReps = TextEditingController(text: '${exercise?.maxReps ?? 12}');
    final rest = TextEditingController(text: '${exercise?.restSeconds ?? 90}');
    final durationMinutes = TextEditingController(
      text: '${((exercise?.durationSeconds ?? 1200) / 60).ceil()}',
    );
    final increment = TextEditingController(
      text:
          '${configuredIncrement > 0 ? configuredIncrement : _defaultProgressionIncrement(group)}',
    );
    var rangeInvalid = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            exercise == null ? 'Nuevo ejercicio' : 'Editar ejercicio',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Escribe un nombre'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      decoration: const InputDecoration(
                        labelText: 'Grupo muscular',
                      ),
                      items: groups
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => group = value ?? group),
                    ),
                    const SizedBox(height: 12),
                    if (group == 'Cardio')
                      _integerField(
                        durationMinutes,
                        'Duración',
                        minimum: 1,
                        suffix: 'min',
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _integerField(sets, 'Series', minimum: 0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _integerField(
                              minReps,
                              'Reps mín.',
                              minimum: 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _integerField(
                              maxReps,
                              'Reps máx.',
                              minimum: 0,
                            ),
                          ),
                        ],
                      ),
                      if (rangeInvalid)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Las repeticiones mínimas no pueden superar las máximas.',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _integerField(rest, 'Descanso', minimum: 0, suffix: 's'),
                      const SizedBox(height: 12),
                      _decimalField(
                        increment,
                        'Incremento mínimo',
                        suffix: 'kg',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (group != 'Cardio' &&
                    (int.tryParse(minReps.text) ?? 0) >
                        (int.tryParse(maxReps.text) ?? 0)) {
                  setDialogState(() => rangeInvalid = true);
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(exercise == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (saved != true) {
      for (final controller in [
        name,
        sets,
        minReps,
        maxReps,
        rest,
        durationMinutes,
        increment,
      ]) {
        controller.dispose();
      }
      return;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _exerciseService.saveExercise(
      uid,
      ExerciseModel(
        id: exercise?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        muscleGroup: group,
        order: exercise?.order ?? 0,
        sets: group == 'Cardio' ? 0 : int.parse(sets.text),
        minReps: group == 'Cardio' ? 0 : int.parse(minReps.text),
        maxReps: group == 'Cardio' ? 0 : int.parse(maxReps.text),
        restSeconds: group == 'Cardio' ? 0 : int.parse(rest.text),
        progressionIncrementKg: group == 'Cardio'
            ? 0
            : double.parse(increment.text.replaceAll(',', '.')),
        type: group == 'Cardio'
            ? 'cardio'
            : exercise?.type == 'cardio'
            ? 'normal'
            : exercise?.type ?? 'normal',
        notes: exercise?.notes,
        isTimed: group == 'Cardio'
            ? true
            : exercise?.type == 'cardio'
            ? false
            : exercise?.isTimed ?? false,
        durationSeconds: group == 'Cardio'
            ? int.parse(durationMinutes.text) * 60
            : exercise?.type == 'cardio'
            ? null
            : exercise?.durationSeconds,
      ),
    );
    for (final controller in [
      name,
      sets,
      minReps,
      maxReps,
      rest,
      durationMinutes,
      increment,
    ]) {
      controller.dispose();
    }
    _refresh();
  }

  Widget _integerField(
    TextEditingController controller,
    String label, {
    required int minimum,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number < minimum) return 'Valor no válido';
        return null;
      },
    );
  }

  Widget _decimalField(
    TextEditingController controller,
    String label, {
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final number = double.tryParse((value ?? '').replaceAll(',', '.'));
        if (number == null || number <= 0) return 'Valor no válido';
        return null;
      },
    );
  }

  double _defaultProgressionIncrement(String muscleGroup) =>
      ['Hombros', 'Bíceps', 'Tríceps'].contains(muscleGroup) ? 1 : 2.5;

  Future<void> _confirmDelete(ExerciseModel exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text(
          '¿Eliminar ${exercise.name} del catálogo? Las rutinas guardadas no se modificarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _exerciseService.deleteExercise(
        FirebaseAuth.instance.currentUser!.uid,
        exercise.id,
      );
      _refresh();
    }
  }

  Future<void> _editRoutine(
    List<ExerciseModel> catalog,
    List<WorkoutModel> workouts, {
    WorkoutModel? workout,
    int? initialDay,
  }) async {
    if (catalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade ejercicios al catálogo primero.')),
      );
      _tabs.animateTo(0);
      return;
    }
    final name = TextEditingController(text: workout?.name ?? '');
    var day = workout?.dayOfWeek ?? initialDay ?? 1;
    final selected = <String>{
      ...?workout?.exercises.map((exercise) => exercise.name.toLowerCase()),
    };
    final exerciseConfigs = <String, _RoutineExerciseConfig>{};
    for (final exercise in catalog) {
      final key = exercise.name.toLowerCase();
      final configured = workout?.exercises
          .where((item) => item.name.toLowerCase() == key)
          .firstOrNull;
      exerciseConfigs[key] = _RoutineExerciseConfig(
        sets: _positiveOrDefault(configured?.sets, exercise.sets, 3),
        minReps: _positiveOrDefault(configured?.minReps, exercise.minReps, 8),
        maxReps: _positiveOrDefault(configured?.maxReps, exercise.maxReps, 12),
        durationMinutes: _positiveOrDefault(
          configured?.durationSeconds != null
              ? (configured!.durationSeconds! / 60).ceil()
              : exercise.durationSeconds != null
              ? (exercise.durationSeconds! / 60).ceil()
              : null,
          0,
          20,
        ),
      );
    }
    String? exerciseValidation;
    final result = await showDialog<_RoutineDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(workout == null ? 'Crear rutina' : 'Editar rutina'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de rutina',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(
                    labelText: 'Día de entrenamiento',
                  ),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(days[index]),
                    ),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => day = value ?? day),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final exercise in catalog) ...[
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(exercise.name),
                          subtitle: Text(exercise.muscleGroup),
                          value: selected.contains(exercise.name.toLowerCase()),
                          onChanged: (value) => setDialogState(() {
                            exerciseValidation = null;
                            if (value == true) {
                              selected.add(exercise.name.toLowerCase());
                            } else {
                              selected.remove(exercise.name.toLowerCase());
                            }
                          }),
                        ),
                        if (selected.contains(exercise.name.toLowerCase()))
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 8,
                              bottom: 12,
                            ),
                            child: exercise.muscleGroup == 'Cardio'
                                ? _routineNumberField(
                                    exerciseConfigs[exercise.name
                                            .toLowerCase()]!
                                        .durationMinutes,
                                    'Duración',
                                    suffix: 'min',
                                    onChanged: () => setDialogState(
                                      () => exerciseValidation = null,
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _routineNumberField(
                                          exerciseConfigs[exercise.name
                                                  .toLowerCase()]!
                                              .sets,
                                          'Series',
                                          onChanged: () => setDialogState(
                                            () => exerciseValidation = null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _routineNumberField(
                                          exerciseConfigs[exercise.name
                                                  .toLowerCase()]!
                                              .minReps,
                                          'Reps mín.',
                                          onChanged: () => setDialogState(
                                            () => exerciseValidation = null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _routineNumberField(
                                          exerciseConfigs[exercise.name
                                                  .toLowerCase()]!
                                              .maxReps,
                                          'Reps máx.',
                                          onChanged: () => setDialogState(
                                            () => exerciseValidation = null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                      ],
                      if (exerciseValidation != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            exerciseValidation!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final invalid = selected.any((key) {
                  final config = exerciseConfigs[key]!;
                  final exercise = catalog.firstWhere(
                    (item) => item.name.toLowerCase() == key,
                  );
                  if (exercise.muscleGroup == 'Cardio') {
                    final duration = int.tryParse(config.durationMinutes.text);
                    return duration == null || duration < 1;
                  }
                  final sets = int.tryParse(config.sets.text);
                  final minReps = int.tryParse(config.minReps.text);
                  final maxReps = int.tryParse(config.maxReps.text);
                  return sets == null ||
                      sets < 1 ||
                      minReps == null ||
                      minReps < 1 ||
                      maxReps == null ||
                      maxReps < minReps;
                });
                if (name.text.trim().isEmpty || selected.isEmpty || invalid) {
                  setDialogState(() {
                    exerciseValidation = name.text.trim().isEmpty
                        ? 'Escribe un nombre y selecciona ejercicios.'
                        : selected.isEmpty
                        ? 'Selecciona al menos un ejercicio.'
                        : 'Revisa series, reps y duración de cada ejercicio.';
                  });
                  return;
                }
                Navigator.pop(
                  context,
                  _RoutineDraft(name.text.trim(), day, selected, {
                    for (final key in selected)
                      key: _RoutineExerciseValues(
                        sets:
                            catalog
                                    .firstWhere(
                                      (exercise) =>
                                          exercise.name.toLowerCase() == key,
                                    )
                                    .muscleGroup ==
                                'Cardio'
                            ? 0
                            : int.parse(exerciseConfigs[key]!.sets.text),
                        minReps:
                            catalog
                                    .firstWhere(
                                      (exercise) =>
                                          exercise.name.toLowerCase() == key,
                                    )
                                    .muscleGroup ==
                                'Cardio'
                            ? 0
                            : int.parse(exerciseConfigs[key]!.minReps.text),
                        maxReps:
                            catalog
                                    .firstWhere(
                                      (exercise) =>
                                          exercise.name.toLowerCase() == key,
                                    )
                                    .muscleGroup ==
                                'Cardio'
                            ? 0
                            : int.parse(exerciseConfigs[key]!.maxReps.text),
                        durationSeconds:
                            catalog
                                    .firstWhere(
                                      (exercise) =>
                                          exercise.name.toLowerCase() == key,
                                    )
                                    .muscleGroup ==
                                'Cardio'
                            ? int.parse(
                                    exerciseConfigs[key]!.durationMinutes.text,
                                  ) *
                                  60
                            : null,
                        progressionIncrementKg: catalog
                            .firstWhere(
                              (exercise) => exercise.name.toLowerCase() == key,
                            )
                            .progressionIncrementKg,
                      ),
                  }),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    for (final config in exerciseConfigs.values) {
      config.dispose();
    }
    if (!mounted) return;
    if (result == null || result.name.isEmpty || result.exerciseNames.isEmpty) {
      return;
    }
    final exercises = catalog
        .where(
          (exercise) =>
              result.exerciseNames.contains(exercise.name.toLowerCase()),
        )
        .toList()
        .asMap()
        .entries
        .map((entry) {
          final config = result.exerciseValues[entry.value.name.toLowerCase()]!;
          final isCardio = entry.value.muscleGroup == 'Cardio';
          return ExerciseModel(
            id: entry.value.id,
            name: entry.value.name,
            muscleGroup: entry.value.muscleGroup,
            order: entry.key + 1,
            sets: config.sets,
            minReps: config.minReps,
            maxReps: config.maxReps,
            restSeconds: isCardio ? 0 : entry.value.restSeconds,
            progressionIncrementKg: entry.value.progressionIncrementKg,
            type: isCardio ? 'cardio' : entry.value.type,
            notes: entry.value.notes,
            isTimed: isCardio || entry.value.isTimed,
            durationSeconds:
                config.durationSeconds ?? entry.value.durationSeconds,
          );
        })
        .toList();
    final sameDay = workouts
        .where((item) => item.dayOfWeek == result.day)
        .firstOrNull;
    if (sameDay != null && sameDay.id != workout?.id) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Día con rutina asignada'),
          content: Text(
            'Ya existe "${sameDay.name}" el ${days[result.day - 1]}. ¿Quieres reemplazarla?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    final id =
        workout?.id ??
        sameDay?.id ??
        'routine_${DateTime.now().microsecondsSinceEpoch}';
    await _workoutService.updateWorkout(
      FirebaseAuth.instance.currentUser!.uid,
      WorkoutModel(
        id: id,
        name: result.name,
        dayOfWeek: result.day,
        exercises: exercises,
        cardioMinutes: workout?.cardioMinutes ?? 0,
        targetDurationMinutes: workout?.targetDurationMinutes,
        circuitRounds: workout?.circuitRounds,
      ),
    );
    _refresh();
  }

  int _positiveOrDefault(int? configured, int catalogValue, int fallback) {
    if (configured != null && configured > 0) return configured;
    if (catalogValue > 0) return catalogValue;
    return fallback;
  }

  Widget _routineNumberField(
    TextEditingController controller,
    String label, {
    String? suffix,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildWithFab();

  Widget _buildWithFab() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CONFIGURACIÓN',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Ejercicios'),
            Tab(text: 'Rutinas'),
            Tab(text: 'Apariencia'),
          ],
        ),
      ),
      body: FutureBuilder<_SettingsData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('No se pudo cargar: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return TabBarView(
            controller: _tabs,
            children: [
              _exerciseCatalog(data.exercises),
              _routineList(
                data.exercises,
                data.workouts,
                data.automaticTrainingEnabled,
              ),
              _appearanceSettings(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final data = await _data;
          if (!mounted) return;
          if (_tabs.index == 0) {
            await _addExercise();
          } else {
            final plannedDays = data.workouts
                .map((workout) => workout.dayOfWeek)
                .toSet();
            final nextDay = List.generate(
              7,
              (index) => index + 1,
            ).where((day) => !plannedDays.contains(day)).firstOrNull;
            if (nextDay == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La semana ya tiene los siete días asignados.'),
                ),
              );
              return;
            }
            await _editRoutine(
              data.exercises,
              data.workouts,
              initialDay: nextDay,
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Ejercicio' : 'Rutina'),
      ),
    );
  }

  Widget _appearanceSettings() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          ),
          title: const Text('Entorno oscuro'),
          subtitle: Text(isDark ? 'Activado' : 'Desactivado · entorno claro'),
          value: isDark,
          onChanged: (value) async {
            try {
              await widget.onDarkModeChanged(value);
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No se pudo guardar el tema: $error')),
              );
            }
          },
        ),
      ],
    );
  }
}

class _SettingsData {
  final List<ExerciseModel> exercises;
  final List<WorkoutModel> workouts;
  final bool automaticTrainingEnabled;

  const _SettingsData(
    this.exercises,
    this.workouts,
    this.automaticTrainingEnabled,
  );
}

class _RoutineDraft {
  final String name;
  final int day;
  final Set<String> exerciseNames;
  final Map<String, _RoutineExerciseValues> exerciseValues;

  const _RoutineDraft(
    this.name,
    this.day,
    this.exerciseNames,
    this.exerciseValues,
  );
}

class _RoutineExerciseConfig {
  final TextEditingController sets;
  final TextEditingController minReps;
  final TextEditingController maxReps;
  final TextEditingController durationMinutes;

  _RoutineExerciseConfig({
    required int sets,
    required int minReps,
    required int maxReps,
    required int durationMinutes,
  }) : sets = TextEditingController(text: '$sets'),
       minReps = TextEditingController(text: '$minReps'),
       maxReps = TextEditingController(text: '$maxReps'),
       durationMinutes = TextEditingController(text: '$durationMinutes');

  void dispose() {
    sets.dispose();
    minReps.dispose();
    maxReps.dispose();
    durationMinutes.dispose();
  }
}

class _RoutineExerciseValues {
  final int sets;
  final int minReps;
  final int maxReps;
  final int? durationSeconds;
  final double progressionIncrementKg;

  const _RoutineExerciseValues({
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.progressionIncrementKg,
    this.durationSeconds,
  });
}
