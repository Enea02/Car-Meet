import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/auto_providers.dart';

class RegisterAutoScreen extends ConsumerStatefulWidget {
  const RegisterAutoScreen({super.key});

  @override
  ConsumerState<RegisterAutoScreen> createState() => _RegisterAutoScreenState();
}

class _RegisterAutoScreenState extends ConsumerState<RegisterAutoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<XFile> _photos = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(limit: 8);
    if (files.isNotEmpty) setState(() => _photos.addAll(files));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(autoRepositoryProvider);
      final urls = <String>[];
      for (final f in _photos) {
        final compressed = await FlutterImageCompress.compressWithFile(
          f.path,
          minWidth: 1600,
          minHeight: 1600,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) {
          urls.add(await repo.uploadPhoto(userId: userId, bytes: compressed));
        }
      }
      await repo.create(
        ownerId: userId,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoUrls: urls,
      );
      if (mounted) {
        ref.invalidate(myGarageProvider);
        context.go('/home/garage');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi auto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home/garage'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    GestureDetector(
                      onTap: _addPhotos,
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_a_photo_outlined, size: 32),
                        ),
                      ),
                    ),
                    for (int i = 0; i < _photos.length; i++)
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(File(_photos[i].path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 10,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photos.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _makeCtrl,
                decoration: const InputDecoration(labelText: 'Marca'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Modello'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Anno'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Descrizione (opzionale)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Salvo…' : 'Salva auto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
