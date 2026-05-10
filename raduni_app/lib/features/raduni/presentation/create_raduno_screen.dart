import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/raduni_providers.dart';

class CreateRadunoScreen extends ConsumerStatefulWidget {
  const CreateRadunoScreen({super.key});

  @override
  ConsumerState<CreateRadunoScreen> createState() => _CreateRadunoScreenState();
}

class _CreateRadunoScreenState extends ConsumerState<CreateRadunoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _maxAttendeesCtrl = TextEditingController();

  DateTime? _startAt;
  LatLng _pin = const LatLng(45.4642, 9.1900);
  XFile? _coverFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationNameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _startAt ?? now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _startAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _coverFile = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startAt == null) {
      setState(() => _error = 'Seleziona data e ora');
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(raduniRepositoryProvider);
      String? coverUrl;
      if (_coverFile != null) {
        final compressed = await FlutterImageCompress.compressWithFile(
          _coverFile!.path,
          minWidth: 1600,
          minHeight: 1600,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) {
          coverUrl = await repo.uploadCover(userId: userId, bytes: compressed);
        }
      }
      final priceEuro = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final maxAtt = int.tryParse(_maxAttendeesCtrl.text);
      await repo.create(
        organizerId: userId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startAt: _startAt!,
        locationName: _locationNameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        lat: _pin.latitude,
        lng: _pin.longitude,
        entryPriceCents: (priceEuro * 100).round(),
        maxAttendees: maxAtt,
        coverImageUrl: coverUrl,
      );
      if (mounted) {
        ref.invalidate(raduniNearbyProvider);
        context.go('/home/raduni');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM y • HH:mm', 'it_IT');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea raduno'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home/raduni'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GestureDetector(
                onTap: _pickCover,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      image: _coverFile != null
                          ? DecorationImage(
                              image: FileImage(File(_coverFile!.path)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _coverFile == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 40),
                                SizedBox(height: 6),
                                Text('Foto copertina (opzionale)'),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titolo'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_startAt == null
                    ? 'Data e ora inizio'
                    : dateFmt.format(_startAt!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStart,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Luogo (es. Autodromo Monza)'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Indirizzo (opzionale)'),
              ),
              const SizedBox(height: 16),
              Text('Posizione sulla mappa',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Tocca o trascina per posizionare il pin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _pin,
                      initialZoom: 11,
                      onTap: (_, p) => setState(() => _pin = p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.eneafrontera.raduni_app',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: _pin,
                          width: 40,
                          height: 40,
                          child: Icon(Icons.place,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Lat: ${_pin.latitude.toStringAsFixed(5)}, Lng: ${_pin.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Prezzo (€)', helperText: '0 = gratuito'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxAttendeesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max iscritti',
                          helperText: 'Vuoto = illimitato'),
                    ),
                  ),
                ],
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
                label: Text(_saving ? 'Salvo…' : 'Pubblica raduno'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

