import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/user_location.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import 'flat_map_view.dart';
import 'map_style.dart';
import '../../../core/theme/app_spacing.dart';

/// Zameranie, z ktorého sa dá vyberať (k nemu zostanú aj staré štítky fitka).
const gymTagChoices = [
  'Silový tréning',
  'Kardio',
  'Funkčný tréning',
  'CrossFit',
  'Skupinové lekcie',
  'Bojové športy',
  'Joga',
  'Osobný tréner',
  'Sauna',
  'Bazén',
  'Parkovanie',
];

/// Pridanie nového fitka alebo úprava vlastného ([gymId]).
class GymFormScreen extends ConsumerWidget {
  const GymFormScreen({super.key, this.gymId, this.initialLocation});

  /// null = nové fitko.
  final String? gymId;

  /// Kde začať s výberom polohy (napr. dlhé podržanie na mape).
  final GeoPoint? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = gymId;
    final Widget body;
    if (id == null) {
      body = _GymForm(initialLocation: initialLocation);
    } else {
      body = ref
          .watch(gymByIdProvider(id))
          .when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (_, _) => const Center(child: Text('Fitko sme nenašli.')),
            data: (gym) => gym == null || !gym.mine
                ? const Center(child: Text('Toto fitko upraviť nemôžeš.'))
                : _GymForm(gym: gym),
          );
    }
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    id == null ? 'Nové fitko' : 'Upraviť fitko',
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/map'),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GymForm extends ConsumerStatefulWidget {
  const _GymForm({this.gym, this.initialLocation});

  final Gym? gym;
  final GeoPoint? initialLocation;

  @override
  ConsumerState<_GymForm> createState() => _GymFormState();
}

class _GymFormState extends ConsumerState<_GymForm> {
  /// Kým nepoznáme polohu, mapa začne nad Slovenskom.
  static const _fallbackCenter = GeoPoint(48.67, 19.70);

  final _form = GlobalKey<FormState>();
  final _map = MapController();
  late final _name = TextEditingController(text: widget.gym?.name);
  late final _city = TextEditingController(text: widget.gym?.city);
  late final _address = TextEditingController(text: widget.gym?.address);
  late final _hours = TextEditingController(text: widget.gym?.openingHours);
  late final _website = TextEditingController(
    text: widget.gym?.website?.toString(),
  );
  late final Set<String> _tags = {...?widget.gym?.tags};
  late GeoPoint? _location = widget.gym?.location ?? widget.initialLocation;
  bool _saving = false;
  bool _locationMissing = false;

  @override
  void dispose() {
    for (final c in [_name, _city, _address, _hours, _website]) {
      c.dispose();
    }
    _map.dispose();
    super.dispose();
  }

  void _place(GeoPoint point) => setState(() {
    _location = point;
    _locationMissing = false;
  });

  void _useMyLocation() {
    final found = ref.read(userLocationProvider).value;
    if (found case LocationFound(:final point)) {
      _place(point);
      _map.move(toLatLng(point), 17);
    } else {
      ref.invalidate(userLocationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Polohu nepoznáme. Ťukni na mapu na miesto fitka.'),
        ),
      );
    }
  }

  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    final location = _location;
    final valid = _form.currentState!.validate();
    setState(() => _locationMissing = location == null);
    if (!valid || location == null) return;

    final draft = GymDraft(
      name: _name.text.trim(),
      city: _city.text.trim(),
      location: location,
      address: _optional(_address),
      openingHours: _optional(_hours),
      website: _optional(_website),
      tags: _tags.toList(),
    );
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final gyms = ref.read(gymsProvider.notifier);
    setState(() => _saving = true);
    try {
      final gym = widget.gym;
      if (gym == null) {
        final created = await gyms.create(draft);
        messenger.showSnackBar(
          const SnackBar(content: Text('Fitko je na mape. Ďakujeme!')),
        );
        router.pushReplacement('/gym/${created.id}');
      } else {
        await gyms.edit(gym.id, draft);
        router.pop();
      }
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = switch (ref.watch(userLocationProvider).value) {
      LocationFound(:final point) => point,
      _ => null,
    };
    final location = _location;
    final tags = {...gymTagChoices, ...?widget.gym?.tags};

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          TextFormField(
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Názov fitka'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Zadaj názov.' : null,
          ),
          TextFormField(
            controller: _city,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Mesto'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Zadaj mesto.' : null,
          ),
          TextFormField(
            controller: _address,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Ulica a číslo (nepovinné)',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: Text('Poloha na mape', style: text.titleMedium)),
              TextButton.icon(
                onPressed: _useMyLocation,
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Som tu'),
              ),
            ],
          ),
          Text(
            location == null
                ? 'Ťukni na mapu tam, kde je fitko.'
                : 'Špendlík posunieš ťuknutím na iné miesto.',
            style: text.bodySmall!.copyWith(
              color: _locationMissing ? AppColors.error : AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: toLatLng(location ?? user ?? _fallbackCenter),
                  initialZoom: location != null
                      ? 16
                      : user != null
                      ? 14
                      : 6,
                  minZoom: 2,
                  maxZoom: 19,
                  backgroundColor: AppColors.bg,
                  onTap: (_, point) =>
                      _place(GeoPoint(point.latitude, point.longitude)),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  if (ref.watch(mapTilesEnabledProvider))
                    TileLayer(
                      urlTemplate: MapStyle.tileUrl,
                      userAgentPackageName: MapStyle.packageName,
                      tileBuilder: (context, tile, _) => ColorFiltered(
                        colorFilter: MapStyle.darkFilter,
                        child: tile,
                      ),
                    ),
                  if (location != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(location.lat, location.lng),
                          width: 46,
                          height: 58,
                          alignment: Alignment.topCenter,
                          child: const GymPin(selected: true),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _hours,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Otváracie hodiny (nepovinné)',
              hintText: 'Nonstop, Po–Pi 6–22, So–Ne 8–20',
            ),
          ),
          TextFormField(
            controller: _website,
            maxLength: 300,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Web (nepovinné)',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Zameranie', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (on) =>
                      setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Ukladám…'
                  : widget.gym == null
                  ? 'Pridať fitko na mapu'
                  : 'Uložiť zmeny',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Fotky a cenník pridáš v detaile fitka.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
