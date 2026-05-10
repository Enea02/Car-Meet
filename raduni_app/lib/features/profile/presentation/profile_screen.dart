import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
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
      if (mounted) setState(() => _info = 'Avatar aggiornato');
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
      _info = null;
    });
    try {
      await ref.read(profileRepositoryProvider).update(
            userId: userId,
            username: _usernameCtrl.text.trim(),
            displayName: _displayNameCtrl.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) setState(() => _info = 'Profilo aggiornato');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(error: e),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profilo non trovato'));
          }
          if (!_initialized) {
            _usernameCtrl.text = profile.username;
            _displayNameCtrl.text = profile.displayName;
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _changeAvatar,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundImage: profile.avatarUrl != null
                        ? CachedNetworkImageProvider(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? const Icon(Icons.person, size: 56)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _changeAvatar,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Cambia avatar'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome mostrato',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Salva profilo'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Account: ${profile.id}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
