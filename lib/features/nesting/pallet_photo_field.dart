import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../design/design.dart';

/// A pallet photo captured against one nesting save.
@immutable
class PalletPhoto {
  const PalletPhoto({
    required this.clientUuid,
    required this.bytes,
    required this.mimeType,
    required this.capturedAt,
  });

  /// Generated at capture, on this device. The entries booked in the same save
  /// carry it, and the server dedupes uploads on it.
  final String clientUuid;
  final Uint8List bytes;
  final String mimeType;
  final DateTime capturedAt;

  int get sizeKb => (bytes.lengthInBytes / 1024).round();
}

/// Capture control for the pallet photo.
///
/// Optional by design, and visibly so. A receipt moves stock; a photograph is
/// evidence about it. An operator with a dead camera, a denied permission or a
/// cracked lens must still be able to record what came off the frame, so
/// nothing here blocks a save and every failure is reported as a message
/// rather than by disabling the flow.
class PalletPhotoField extends StatefulWidget {
  const PalletPhotoField({
    super.key,
    required this.photo,
    required this.onChanged,
    this.enabled = true,
  });

  final PalletPhoto? photo;
  final ValueChanged<PalletPhoto?> onChanged;
  final bool enabled;

  @override
  State<PalletPhotoField> createState() => _PalletPhotoFieldState();
}

class _PalletPhotoFieldState extends State<PalletPhotoField> {
  static const _uuid = Uuid();

  bool _busy = false;
  String? _error;

  /// Windows has no camera through image_picker, and a file dialog is what a
  /// desk terminal wants anyway. Phones and the browser get the camera.
  bool get _cameraAvailable => kIsWeb || Platform.isAndroid || Platform.isIOS;

  Future<void> _capture(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Downscaled at the source. A modern phone produces 4-8 MB per frame,
        // the server caps at 3 MB, and nothing about a pallet needs more than
        // this to be legible. Doing it here also keeps the offline queue small.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 78,
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return; // cancelled — not an error
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      widget.onChanged(PalletPhoto(
        clientUuid: _uuid.v4(),
        bytes: bytes,
        mimeType: picked.mimeType ?? 'image/jpeg',
        capturedAt: DateTime.now(),
      ));
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not attach the photo. The entry can still be saved without it.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    final photo = widget.photo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PALLET PHOTO',
              style: context.text.labelSmall
                  ?.copyWith(color: v.txt3, fontSize: 9.5, letterSpacing: 1.4),
            ),
            const SizedBox(width: VSpace.xs),
            Text(
              '· optional',
              style: context.text.labelSmall?.copyWith(color: v.txt3, fontSize: 9.5),
            ),
          ],
        ),
        const SizedBox(height: VSpace.sm),
        if (photo == null)
          Row(
            children: [
              VButton(
                label: _cameraAvailable ? 'Take photo' : 'Choose photo',
                icon: _cameraAvailable ? Icons.photo_camera_rounded : Icons.image_rounded,
                variant: VButtonVariant.ghost,
                loading: _busy,
                onPressed: widget.enabled && !_busy
                    ? () => _capture(_cameraAvailable ? ImageSource.camera : ImageSource.gallery)
                    : null,
              ),
              if (_cameraAvailable) ...[
                const SizedBox(width: VSpace.sm),
                VIconButton(
                  icon: Icons.image_rounded,
                  tooltip: 'Choose an existing photo',
                  onPressed:
                      widget.enabled && !_busy ? () => _capture(ImageSource.gallery) : null,
                ),
              ],
            ],
          )
        else
          _Preview(
            photo: photo,
            enabled: widget.enabled && !_busy,
            onRetake: () => _capture(_cameraAvailable ? ImageSource.camera : ImageSource.gallery),
            onRemove: () => widget.onChanged(null),
          ),
        if (_error != null) ...[
          const SizedBox(height: VSpace.sm),
          Text(
            _error!,
            style: context.text.bodySmall
                ?.copyWith(color: v.bad, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.photo,
    required this.enabled,
    required this.onRetake,
    required this.onRemove,
  });

  final PalletPhoto photo;
  final bool enabled;
  final VoidCallback onRetake;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final v = context.v;
    return Container(
      padding: const EdgeInsets.all(VSpace.sm),
      decoration: BoxDecoration(
        color: v.surface2,
        borderRadius: VRadius.allSm,
        border: Border.all(color: v.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              photo.bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              // Decoded small as well as drawn small: a full-size decode per
              // thumbnail is how a list of these runs a tablet out of memory.
              cacheWidth: 128,
              errorBuilder: (context, error, stack) => Container(
                width: 64,
                height: 64,
                color: v.surface3,
                child: Icon(Icons.broken_image_rounded, size: 20, color: v.txt3),
              ),
            ),
          ),
          const SizedBox(width: VSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Photo attached',
                  style: context.text.labelMedium
                      ?.copyWith(color: v.txt, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${photo.sizeKb} KB · uploads with the entry',
                  style: context.text.bodySmall?.copyWith(color: v.txt3, fontSize: 11.5),
                ),
              ],
            ),
          ),
          VIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Retake',
            onPressed: enabled ? onRetake : null,
          ),
          const SizedBox(width: VSpace.xxs),
          VIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remove photo',
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}
