import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import '../../app/theme/app_colors.dart';
import '../../providers/app_providers.dart';

/// Album artwork tile backed by the cached-artwork repository.
///
/// Falls back to a warm gradient + glyph when the entity has no embedded art,
/// which also keeps list layouts stable while art loads asynchronously.
class ArtworkTile extends ConsumerStatefulWidget {
  const ArtworkTile({
    super.key,
    required this.entityId,
    required this.target,
    required this.size,
    this.radius = 12,
    this.icon,
    this.heroTag,
  });

  final int entityId;
  final ArtworkTarget target;
  final double size;
  final double radius;
  final IconData? icon;
  final Object? heroTag;

  @override
  ConsumerState<ArtworkTile> createState() => _ArtworkTileState();
}

class _ArtworkTileState extends ConsumerState<ArtworkTile> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ArtworkTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityId != widget.entityId ||
        oldWidget.target != widget.target) {
      _path = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.entityId;
    final target = widget.target;
    final path = await ref
        .read(artworkRepositoryProvider)
        .artworkPath(id, target);
    if (!mounted || id != widget.entityId || target != widget.target) return;
    if (path != null && path.isNotEmpty) {
      setState(() => _path = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final image = _path == null
        ? _fallback(palette)
        : ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Image.file(
              File(_path!),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              cacheWidth: (widget.size * 2).round(),
              errorBuilder: (_, _, _) => _fallback(palette),
            ),
          );

    final tile = SizedBox.square(dimension: widget.size, child: image);

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: tile);
    }
    return tile;
  }

  Widget _fallback(MonoraPalette palette) {
    final isTrack = widget.target == ArtworkTarget.track;
    final hueSeed = (widget.entityId * 37) % 100;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surfaceAlt,
            Color.lerp(
              palette.surfaceAlt,
              palette.accentSoft,
              0.35 + hueSeed / 300,
            )!,
          ],
        ),
      ),
      child: Icon(
        widget.icon ??
            (isTrack ? Icons.music_note_rounded : Icons.album_rounded),
        size: widget.size * 0.32,
        color: palette.inkTertiary,
      ),
    );
  }
}

/// Circular avatar variant for artists.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    required this.name,
    this.size = 64,
    this.imageBytes,
  });

  final String name;
  final double size;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accentSoft, palette.surfaceAlt],
        ),
      ),
      alignment: Alignment.center,
      child: imageBytes != null
          ? ClipOval(
              child: Image.memory(
                imageBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * 2).round(),
                errorBuilder: (_, _, _) => _initial(palette, initial),
              ),
            )
          : _initial(palette, initial),
    );
  }

  Widget _initial(MonoraPalette palette, String initial) {
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'Playfair',
        fontWeight: FontWeight.w600,
        fontSize: size * 0.36,
        color: palette.accentDeep,
      ),
    );
  }
}
