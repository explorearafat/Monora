import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../settings/settings_screen.dart';

/// Profile & stats: identity, library counters, listening time, and top
/// genres — all derived from real library data and persisted usage.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final stats = ref.watch(profileStatsProvider);
    final name = ref.watch(profileNameProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: palette.accent,
        backgroundColor: palette.surface,
        onRefresh: () => ref.read(libraryProvider.notifier).rescan(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Your Profile', style: text.screenTitle),
                  ),
                  Pressable(
                    onTap: () => pushDetail(context, const SettingsScreen()),
                    semanticLabel: 'Open settings',
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [palette.accentSoft, palette.surfaceAlt],
                      ),
                      border: Border.all(color: palette.outline),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: FontWeight.w600,
                        fontSize: 26,
                        color: palette.accentDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Playfair',
                            fontWeight: FontWeight.w600,
                            fontSize: 21,
                            color: palette.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('Music Lover', style: text.trackSubtitle),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () => _editName(context, ref, name),
                    borderRadius: BorderRadius.circular(20),
                    semanticLabel: 'Edit display name',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.outline),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatCell(
                    value: '${stats.totalSongs}',
                    label: 'Total Songs',
                    flex: 3,
                  ),
                  _StatCell(
                    value: '${stats.totalArtists}',
                    label: 'Artists',
                    flex: 2,
                  ),
                  _StatCell(
                    value: '${stats.totalPlaylists}',
                    label: 'Playlists',
                    flex: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Listening Stats', style: text.sectionTitle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ListeningCard(
                      icon: Icons.schedule_rounded,
                      value: formatDurationLong(stats.listeningTime),
                      label: 'Listening Time',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ListeningCard(
                      icon: Icons.favorite_rounded,
                      value: '${stats.favoriteArtistCount}',
                      label: 'Favorite Artists',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Top Genres', style: text.sectionTitle),
            ),
            if (stats.topGenres.isEmpty)
              const _SideHint(
                icon: Icons.category_rounded,
                text: 'Genre tags will appear once your files carry them.',
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final genre in stats.topGenres)
                      _GenreBar(
                        name: genre.name,
                        share: genre.share ?? 0,
                        percent: (genre.share ?? 0) * 100,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.monora;
        return AlertDialog(
          title: const Text('Your name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            style: TextStyle(color: palette.ink, fontFamily: 'Inter'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: palette.inkSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text('Save', style: TextStyle(color: palette.accent)),
            ),
          ],
        );
      },
    );
    if (name != null) {
      await ref.read(profileNameProvider.notifier).set(name);
    }
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.flex,
  });

  final String value;
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.outline),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                color: palette.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: palette.accentDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: palette.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                    color: palette.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  const _GenreBar({
    required this.name,
    required this.share,
    required this.percent,
  });

  final String name;
  final double share;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: palette.ink,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: share.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: palette.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SideHint extends StatelessWidget {
  const _SideHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.inkTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: palette.inkTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
