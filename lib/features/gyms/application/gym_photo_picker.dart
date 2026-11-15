import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Výber fotky z galérie alebo fotoaparátu (v testoch sa nahradí).
abstract interface class GymPhotoPicker {
  /// Bajty zmenšenej fotky, null = používateľ nič nevybral.
  /// Pri chybe (napr. bez povolenia) vyhodí [PhotoPickFailed].
  Future<List<int>?> pick(PhotoSource source);
}

class PhotoPickFailed implements Exception {
  const PhotoPickFailed();
}

class SystemGymPhotoPicker implements GymPhotoPicker {
  const SystemGymPhotoPicker();

  /// Dlhšia strana fotky po zmenšení; stačí na displej a má pár stoviek kB.
  static const _maxSide = 1600.0;
  static const _quality = 80;

  @override
  Future<List<int>?> pick(PhotoSource source) async {
    try {
      // S kvalitou pod 100 vráti image_picker JPEG (aj z HEIC na iPhone).
      final file = await ImagePicker().pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      return file == null ? null : await file.readAsBytes();
    } on PlatformException {
      throw const PhotoPickFailed();
    }
  }
}

final gymPhotoPickerProvider = Provider<GymPhotoPicker>(
  (ref) => const SystemGymPhotoPicker(),
);
