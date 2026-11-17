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
        _selected = result.candidates.isEmpty ? null : result.candidates.first;
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
    final photo = _photo;
    final result = _result;
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(result == null ? 'Identify plant' : 'Choose a match'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  if (photo == null)
                    ..._startView(theme)
                  else if (result == null)
                    ..._photoView(theme, photo)
                  else
                    ..._resultsView(theme, photo, result),
                  if (_message case final message?) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (photo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: result == null
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: widget.identifier == null || _identifying
                            ? null
                            : _identify,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(_identifying ? 'Identifying…' : 'Identify'),
                      )
                    : result.candidates.isEmpty
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _resetPhoto,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try another photo'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: selected == null
                            ? null
                            : () => _useCandidate(context, selected),
                        child: Text(
                          selected == null
                              ? 'Choose a match'
                              : 'Add ${selected.displayName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _resetPhoto() => setState(() {
    _photo = null;
    _result = null;
    _selected = null;
    _message = null;
  });

  List<Widget> _startView(ThemeData theme) => [
    const SizedBox(height: 8),
    Text('What plant is this?', style: theme.textTheme.headlineSmall),
    const SizedBox(height: 6),
    Text(
      'A clear photo of the leaves works best.',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 24),
    Row(
      children: [
        Expanded(
          child: _SourceTile(
            icon: Icons.photo_camera_outlined,
            label: 'Take a photo',
            primary: true,
            onTap: () => _pick(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SourceTile(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            onTap: () => _pick(ImageSource.gallery),
          ),
        ),
      ],
    ),
    if (widget.identifier == null) ...[
      const SizedBox(height: 16),
      Text(
        'Identification is not available in this build.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ];

  List<Widget> _photoView(ThemeData theme, XFile photo) => [
    ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(photo.path), fit: BoxFit.cover),
            if (_identifying)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ActionChip(
                    avatar: const Icon(Icons.refresh, size: 18),
                    label: const Text('Change photo'),
                    onPressed: _resetPhoto,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    Text(
      _identifying
          ? 'Comparing with plant references…'
          : widget.identifier == null
          ? 'Identification is not available in this build. No plant has been added.'
          : 'A clear photo of the leaves works best.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ];

  List<Widget> _resultsView(
    ThemeData theme,
    XFile photo,
    PlantIdentificationResult result,
  ) {
    final candidates = result.candidates;
    return [
      Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(photo.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidates.isEmpty
                      ? 'No matches found'
                      : candidates.length == 1
                      ? '1 possible match'
                      : '${candidates.length} possible matches',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  candidates.isEmpty
                      ? 'Try a clearer photo of the leaves.'
                      : 'Pick the one that matches your plant.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _resetPhoto, child: const Text('Retake')),
        ],
      ),
      const SizedBox(height: 16),
      for (final (index, candidate) in candidates.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CandidateCard(
            candidate: candidate,
            featured: index == 0,
            selected: identical(candidate, _selected),
            onTap: () => setState(() => _selected = candidate),
          ),
        ),
    ];
  }

  Future<void> _close() async {
    if (_photo == null || !mounted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this photo?'),
        content: const Text(
          'Your selected photo and any identification result will be removed '
          'from this screen. No plant has been added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard photo'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  void _useCandidate(BuildContext context, PlantCandidate candidate) {
    final species = PlantSpecies.forCandidate(
      scientificName: candidate.scientificName,
      commonNames: candidate.commonNames,
    );
    if (species == null || !species.hasCareProfile) {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile not reviewed yet'),
          content: Text(
            '${candidate.displayName} can be added now. Bloom is preparing '
            'reviewed care guidance, so no automatic watering schedule will '
            'be created yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add plant'),
            ),
          ],
        ),
      ).then((confirmed) async {
        if (confirmed != true || !mounted) return;
        final saved = await widget.store.savePlant(
          Plant(
            id: newId(),
            displayName: candidate.displayName,
            legacySpecies: candidate.scientificName,
          ),
        );
        if (!mounted || !saved) return;
        if (!context.mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlantSetupScreen(store: widget.store, species: species),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = primary ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: fg),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Very likely" / "Possible" / "Less likely" instead of raw percentages.
String _likelihood(double score) => score >= 0.6
    ? 'Very likely'
    : score >= 0.25
    ? 'Possible'
    : 'Less likely';

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.featured,
    required this.selected,
    required this.onTap,
  });

  final PlantCandidate candidate;
  final bool featured;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final species = PlantSpecies.forCandidate(
      scientificName: candidate.scientificName,
      commonNames: candidate.commonNames,
    );
    final hasGuide = species?.hasCareProfile == true;
    final likelihood = _likelihood(candidate.score);
    final status = hasGuide ? likelihood : '$likelihood · no care guide yet';
    final image = species == null
        ? Container(
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(
              Icons.eco_outlined,
              color: scheme.onSurfaceVariant,
              size: featured ? 40 : 24,
            ),
          )
        : Image.asset(species.asset, fit: BoxFit.cover);
    final check = Icon(
      selected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: selected ? scheme.primary : scheme.outline,
    );
    final title = Text(
      candidate.displayName,
      style: theme.textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final scientific = Text(
      candidate.scientificName,
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: scheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final statusText = Text(
      status,
      style: theme.textTheme.labelMedium?.copyWith(
        color: likelihood == 'Very likely'
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: featured
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 150, child: image),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                scientific,
                                const SizedBox(height: 6),
                                statusText,
                              ],
                            ),
                          ),
                          check,
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 52, height: 52, child: image),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, statusText],
                        ),
                      ),
                      check,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
