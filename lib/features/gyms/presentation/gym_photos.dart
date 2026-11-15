import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../application/gym_photo_picker.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import 'gym_detail_widgets.dart';

/// Fotka na zobrazenie: odkaz zvonku alebo nahratá cez appku.
class ShownPhoto {
  const ShownPhoto(this.url, {this.uploaded});

  final String url;

  /// Nahratá cez appku (načíta sa s tokenom); null = odkaz zvonku.
  final GymPhoto? uploaded;
}

/// Všetky fotky fitka: najprv odkazy zvonku, potom nahraté cez appku.
List<ShownPhoto> shownPhotos(Gym gym) => [
  for (final url in gym.photoUrls) ShownPhoto(url),
  for (final photo in gym.photos)
    ShownPhoto(gymPhotoUrl(photo), uploaded: photo),
];

/// Obrázok fitka; fotky z nášho servera sa načítajú s prihlasovacím tokenom.
class GymPhotoImage extends ConsumerWidget {
  const GymPhotoImage(this.photo, {super.key, this.fit = BoxFit.cover});

  final ShownPhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(gymSessionTokenProvider);
    return Image.network(
      photo.url,
      fit: fit,
      headers: photo.uploaded != null && token != null
          ? {'authorization': 'Bearer $token'}
          : null,
      errorBuilder: (_, _, _) => const GymPhotoPlaceholder(),
    );
  }
}

/// Pás fotiek s dlaždicou „Pridať fotku“ na začiatku.
class GymPhotoStrip extends ConsumerStatefulWidget {
  const GymPhotoStrip({super.key, required this.gym});

  final Gym gym;

  @override
  ConsumerState<GymPhotoStrip> createState() => _GymPhotoStripState();
}

class _GymPhotoStripState extends ConsumerState<GymPhotoStrip> {
  bool _uploading = false;

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: AppColors.sheet,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Odfotiť'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Vybrať z galérie'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final List<int>? bytes;
    try {
      bytes = await ref.read(gymPhotoPickerProvider).pick(source);
    } on PhotoPickFailed {
      _say('Fotku sa nepodarilo načítať. Skontroluj povolenia.');
      return;
    }
    if (bytes == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(gymsProvider.notifier).addPhoto(widget.gym.id, bytes);
      _say('Fotka je pridaná. Ďakujeme!');
    } on ApiError catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(ShownPhoto photo) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => _PhotoViewer(photo: photo),
    );
    final uploaded = photo.uploaded;
    if (delete != true || uploaded == null || !mounted) return;
    try {
      await ref.read(gymsProvider.notifier).deletePhoto(uploaded.id);
      _say('Fotka je zmazaná.');
    } on ApiError catch (e) {
      _say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = shownPhotos(widget.gym);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotky', style: text.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddPhotoTile(busy: _uploading, onTap: _add);
              }
              final photo = photos[index - 1];
              return Semantics(
                button: true,
                label: 'Fotka $index z ${photos.length}',
                child: GestureDetector(
                  onTap: () => _open(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(width: 120, child: GymPhotoImage(photo)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: AppColors.sheet.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                const Icon(Icons.add_a_photo_outlined, color: AppColors.accent),
              const SizedBox(height: 6),
              Text(
                busy ? 'Nahrávam…' : 'Pridať fotku',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fotka na celú obrazovku. Vráti true, ak ju používateľ chce zmazať.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final ShownPhoto photo;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(child: GymPhotoImage(photo, fit: BoxFit.contain)),
        SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Zavrieť',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              if (photo.uploaded?.mine ?? false)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Zmazať moju fotku'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
