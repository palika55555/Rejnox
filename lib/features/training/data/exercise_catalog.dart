import '../domain/training_models.dart';

/// Katalóg cvikov zabudovaný v appke, aby sa dalo zapisovať aj bez internetu.
/// ID musia sedieť s db/migrations/008_exercise_catalog.sql.
const exerciseCatalog = <Exercise>[
  Exercise(
    id: '00000000-0000-4000-8000-000000000001',
    name: 'Drep s činkou',
    group: MuscleGroup.legs,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000002',
    name: 'Rumunský mŕtvy ťah',
    group: MuscleGroup.legs,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000003',
    name: 'Mŕtvy ťah',
    group: MuscleGroup.back,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000004',
    name: 'Bench press',
    group: MuscleGroup.chest,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000005',
    name: 'Tlaky s jednoručkami na šikmej lavici',
    group: MuscleGroup.chest,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000006',
    name: 'Príťahy v predklone',
    group: MuscleGroup.back,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000007',
    name: 'Zhyby',
    group: MuscleGroup.back,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000008',
    name: 'Tlak nad hlavu',
    group: MuscleGroup.shoulders,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-000000000009',
    name: 'Bulharské výpady',
    group: MuscleGroup.legs,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-00000000000a',
    name: 'Hip thrust',
    group: MuscleGroup.legs,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-00000000000b',
    name: 'Bicepsový zdvih',
    group: MuscleGroup.arms,
  ),
  Exercise(
    id: '00000000-0000-4000-8000-00000000000c',
    name: 'Francúzsky tlak',
    group: MuscleGroup.arms,
  ),
];

Exercise? exerciseById(String id) {
  for (final e in exerciseCatalog) {
    if (e.id == id) return e;
  }
  return null;
}
