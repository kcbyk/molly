import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'vinyl_disc.dart';

class SongMenuSheet extends StatelessWidget {
  final Song song;
  final bool isLiked;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onShare;
  final VoidCallback onDownload;   // İndir / Sil
  final VoidCallback onToggleLike;

  const SongMenuSheet({
    super.key,
    required this.song,
    required this.isLiked,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onShare,
    required this.onDownload,
    required this.onToggleLike,
  });

  static Future<void> show({
    required BuildContext context,
    required Song song,
    required bool isLiked,
    required bool isDownloaded,
    required bool isDownloading,
    required VoidCallback onShare,
    required VoidCallback onDownload,
    required VoidCallback onToggleLike,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SongMenuSheet(
        song: song,
        isLiked: isLiked,
        isDownloaded: isDownloaded,
        isDownloading: isDownloading,
        onShare: onShare,
        onDownload: onDownload,
        onToggleLike: onToggleLike,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: AppColors.playerBorder, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.sheetHandle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Song Info
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
            child: Row(
              children: [
                VinylDisc(
                  song: song,
                  size: 52,
                  holeSize: 14,
                  holeBg: AppColors.cardBg,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 6),

          // 1. Paylaş
          _buildActionItem(
            context: context,
            icon: AppIcons.share(size: 22, color: AppColors.textPrimary),
            title: 'Paylaş',
            color: AppColors.textPrimary,
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),

          // 2. İndir / İndiriliyor... / Sil
          _buildActionItem(
            context: context,
            icon: isDownloading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.textMuted,
                      backgroundColor:
                          AppColors.textMuted.withValues(alpha: 0.18),
                    ),
                  )
                : isDownloaded
                    ? AppIcons.trash(size: 22, color: AppColors.heartPink)
                    : AppIcons.download(size: 22, color: AppColors.textPrimary),
            title: isDownloading
                ? 'İndiriliyor...'
                : isDownloaded
                    ? 'Kütüphaneden sil'
                    : 'İndir',
            color: isDownloaded ? AppColors.heartPink : AppColors.textPrimary,
            onTap: isDownloading
                ? () {} // indirme sürerken dokunmayı engelle
                : () {
                    Navigator.pop(context);
                    onDownload();
                  },
          ),

          // 3. Beğen / Beğenmekten vazgeç
          _buildActionItem(
            context: context,
            icon: AppIcons.heart(size: 22, isLiked: isLiked),
            title: isLiked ? 'Beğenmekten vazgeç' : 'Beğen',
            color: AppColors.textPrimary,
            onTap: () {
              Navigator.pop(context);
              onToggleLike();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required Widget icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.playerBg,
        highlightColor: AppColors.playerBg,
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
