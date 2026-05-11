import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auto/providers/auto_providers.dart';
import '../../raduni/providers/raduni_providers.dart';
import '../data/profile_model.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(error: e),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profilo non trovato'));
          }
          return _ProfileView(profile: profile);
        },
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  final Profile profile;
  const _ProfileView({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAsync = ref.watch(myGarageProvider);
    final attendedAsync = ref.watch(myAttendedCountProvider);

    final autoCount = autoAsync.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final attendedCount =
        attendedAsync.maybeWhen(data: (n) => n, orElse: () => 0);

    return CustomScrollView(
      slivers: [
        // ── Header (safe area + avatar + name + edit)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    _Avatar(avatarUrl: profile.avatarUrl),
                    const Spacer(),
                    // Edit button
                    OutlinedButton(
                      onPressed: () =>
                          _showEditSheet(context, ref, profile),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Modifica'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  _StatCell(
                      value: attendedCount, label: 'Raduni'),
                  _Vr(),
                  _StatCell(value: autoCount, label: 'Auto'),
                  _Vr(),
                  _StatCell(value: 0, label: 'Seguaci'),
                ],
              ),
            ),
          ),
        ),

        // ── Settings list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.event_outlined,
                    label: 'I miei raduni',
                    onTap: () => context.push('/home/profile/raduni'),
                  ),
                  const Divider(height: 0, indent: 52),
                  _SettingsTile(
                    icon: Icons.settings_outlined,
                    label: 'Impostazioni',
                    onTap: () => context.push('/home/profile/impostazioni'),
                  ),
                  const Divider(height: 0, indent: 52),
                  _SettingsTile(
                    icon: Icons.logout,
                    label: 'Esci',
                    labelColor: AppColors.danger,
                    iconColor: AppColors.danger,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Profile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditSheet(profile: profile),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Esci dall\'account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref.read(authRepositoryProvider).signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
  }
}

// ── Edit bottom sheet ─────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  final Profile profile;
  const _EditSheet({required this.profile});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _displayNameCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile.username);
    _displayNameCtrl =
        TextEditingController(text: widget.profile.displayName);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return;
      final repo = ref.read(profileRepositoryProvider);
      final url = await repo.uploadAvatar(
        userId: userId,
        bytes: compressed,
        contentType: 'image/jpeg',
      );
      await repo.update(
        userId: userId,
        username: _usernameCtrl.text.trim(),
        displayName: _displayNameCtrl.text.trim(),
        avatarUrl: url,
      );
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).update(
            userId: userId,
            username: _usernameCtrl.text.trim(),
            displayName: _displayNameCtrl.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Modifica profilo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          // Avatar change
          Center(
            child: GestureDetector(
              onTap: _saving ? null : _changeAvatar,
              child: Stack(
                children: [
                  _Avatar(
                      avatarUrl: widget.profile.avatarUrl, radius: 40),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _displayNameCtrl,
            decoration:
                const InputDecoration(hintText: 'Nome mostrato'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(hintText: 'Username'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  const _Avatar({required this.avatarUrl, this.radius = 36});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceMuted,
      backgroundImage: avatarUrl != null
          ? CachedNetworkImageProvider(avatarUrl!)
          : null,
      child: avatarUrl == null
          ? Icon(Icons.person_outline,
              color: AppColors.inkMuted, size: radius * 0.8)
          : null,
    );
  }
}

class _StatCell extends StatelessWidget {
  final int value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: AppTheme.displayNumber(size: 36, color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vr extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: AppColors.divider,
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: iconColor ?? AppColors.inkMuted, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: labelColor ?? AppColors.ink,
        ),
      ),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.inkSubtle, size: 18),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
