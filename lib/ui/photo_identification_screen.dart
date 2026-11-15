import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/plant_identifier.dart';
import '../domain/garden_store.dart';
import '../domain/plant_identification.dart';
import '../domain/models.dart';
import 'catalog_screen.dart';

class PhotoIdentificationScreen extends StatefulWidget {
  const PhotoIdentificationScreen({
    super.key,
    required this.store,
    this.identifier,
  });

  final PlantIdentifier? identifier;
  final GardenStore store;

  @override
  State<PhotoIdentificationScreen> createState() =>
      _PhotoIdentificationScreenState();
}

class _PhotoIdentificationScreenState extends State<PhotoIdentificationScreen> {
  final _picker = ImagePicker();
  XFile? _photo;
  PlantIdentificationResult? _result;
  PlantCandidate? _selected;
  bool _identifying = false;
  String? _message;

  Future<void> _pick(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 88,
      );
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _result = null;
        _selected = null;
        _message = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'The photo could not be opened. You can try again or choose a different image.',
      );
    }
  }

  Future<void> _identify() async {
    final photo = _photo;
    final identifier = widget.identifier;
    if (photo == null || identifier == null || _identifying) return;
    setState(() {
      _identifying = true;
      _message = null;
    });
    try {
      final result = await identifier.identify([photo]);
      if (!mounted) return;
      setState(() {
        _result = result;
        _identifying = false;
      });
    } on PlantIdentificationException catch (error) {
      if (!mounted) return;
      setState(() {
        _identifying = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identifying = false;
        _message = 'Plant identification is unavailable right now.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identify from a photo'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Photo-assisted plant identification',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear photo of the plant. Bloom will use it to suggest '
            'possible matches; you will always confirm the plant before adding it.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_photo case final photo?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(
                File(photo.path),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _identifying
                  ? null
                  : () => setState(() {
                      _photo = null;
                      _result = null;
                    }),
              icon: const Icon(Icons.close),
              label: const Text('Remove photo'),
            ),
            const SizedBox(height: 20),
            if (widget.identifier == null && _result == null)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Identification is not configured in this build yet. '
                    'This photo stays on this screen and no plant or watering '
                    'schedule has been added.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else if (_result == null)
              FilledButton.icon(
                onPressed: _identifying ? null : _identify,
                icon: _identifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _identifying
                      ? 'Finding possible matches…'
                      : 'Find possible matches',
                ),
              ),
            if (_identifying) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Text(
                'Comparing your photo with plant references…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_result case final result?) ...[
              const SizedBox(height: 20),
              Text('Possible matches', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.candidates.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No likely plant matches were found. Try a clearer photo.',
                    ),
                  ),
                )
              else
                for (final candidate in result.candidates)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      selected: identical(candidate, _selected),
                      onTap: () => setState(() => _selected = candidate),
                      title: Text(candidate.displayName),
                      subtitle: Text(candidate.scientificName),
                      trailing: Text('${(candidate.score * 100).round()}%'),
                    ),
                  ),
              if (_selected case final selected?) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _useCandidate(context, selected),
                  child: const Text('Use this plant'),
                ),
              ],
              Text(
                'These are possible matches, not a diagnosis. Confirm a plant before adding it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            _PhotoAction(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              detail: 'Use the camera to capture the plant.',
              onTap: () => _pick(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _PhotoAction(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              detail: 'Select an existing plant photo.',
              onTap: () => _pick(ImageSource.gallery),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          Text(
            'Bloom does not diagnose disease, moisture, or plant health from a photo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _useCandidate(BuildContext context, PlantCandidate candidate) {
    final species = PlantSpecies.forScientificName(candidate.scientificName);
    if (species == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile not reviewed yet'),
          content: Text(
            '${candidate.displayName} can be saved as an identity, but Bloom '
            'does not have reviewed watering guidance for it yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantSetupScreen(
          store: widget.store,
          species: species,
        ),
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
