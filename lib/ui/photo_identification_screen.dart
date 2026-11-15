import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoIdentificationScreen extends StatefulWidget {
  const PhotoIdentificationScreen({super.key});

  @override
  State<PhotoIdentificationScreen> createState() =>
      _PhotoIdentificationScreenState();
}

class _PhotoIdentificationScreenState extends State<PhotoIdentificationScreen> {
  final _picker = ImagePicker();
  XFile? _photo;
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
              onPressed: () => setState(() => _photo = null),
              icon: const Icon(Icons.close),
              label: const Text('Remove photo'),
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Identification results are coming next. This photo stays '
                  'on this screen and no plant or watering schedule has been added.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
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
