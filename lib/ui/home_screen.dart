import 'package:flutter/material.dart';

import '../data/garden_repository.dart';
import '../data/growth_photo_files.dart';
import '../data/auth_service.dart';
import '../data/cloud_garden_sync.dart';
import '../data/plant_identifier.dart';
import '../data/watering_notifications.dart';
import '../domain/garden_store.dart';
import '../domain/models.dart';
import '../domain/plant_activity.dart';
import 'catalog_screen.dart';
import 'check_screen.dart';
import 'check_route.dart';
import 'plant_detail_screen.dart';
import 'preferences_screen.dart';
import 'photo_identification_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.flags,
    required this.notifications,
    this.identifier,
    this.auth,
    required this.cloudSync,
  });

  final GardenStore store;
  final FirstRunFlags flags;
  final WateringNotifications notifications;
  final PlantIdentifier? identifier;
  final AuthService? auth;
  final CloudGardenSync cloudSync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Plant ids chosen for bulk delete; null when not selecting.
  Set<String>? _selection;

  void _startSelection([String? plantId]) =>
      setState(() => _selection = {?plantId});

  void _toggle(String plantId) => setState(() {
    final selection = _selection!;
    if (!selection.remove(plantId)) selection.add(plantId);
  });

  void _endSelection() => setState(() => _selection = null);

  Future<void> _deleteSelected() async {
    final ids = {..._selection!};
    if (ids.isEmpty) return;
    final store = widget.store;
    final count = ids.length;
    final noun = count == 1 ? 'plant' : 'plants';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $count $noun?'),
        content: const Text(
          'Their care history and photos will be deleted too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final photos = store.garden.growthPhotos
        .where((p) => ids.contains(p.plantId))
        .toList();
    final deleted = await store.deletePlants(ids);
    if (!mounted) return;
    if (deleted) {
      await GrowthPhotoFiles.deleteFiles(photos);
      if (!mounted) return;
      _endSelection();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? '$count $noun deleted.' : "Plants couldn't be deleted.",
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {
    // Drop selections for plants removed elsewhere.
    final ids = widget.store.garden.plants.map((p) => p.id).toSet();
    _selection?.removeWhere((id) => !ids.contains(id));
    if (ids.isEmpty) _selection = null;
  });

  Future<void> _openCatalog() async {
    await widget.flags.markAddPlantHintSeen();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CatalogScreen(store: widget.store)),
    );
  }

  void _openPhotoIdentification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoIdentificationScreen(
          store: widget.store,
          identifier: widget.identifier,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreferencesScreen(
          store: widget.store,
          notifications: widget.notifications,
          auth: widget.auth,
          cloudSync: widget.cloudSync,
        ),
      ),
    );
  }

  void _openPlant(Plant plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/plant/${plant.id}'),
        builder: (_) =>
            PlantDetailScreen(store: widget.store, plantId: plant.id),
      ),
    );
  }

  void _openCheck(Plant plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: wateringCheckSettings(widget.store.scheduleFor(plant.id)!),
        builder: (_) => CheckScreen(store: widget.store, plantId: plant.id),
      ),
    );
  }

  Future<void> _addPlant() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search by name'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Identify from a photo'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    choice ? await _openCatalog() : _openPhotoIdentification();
  }

  void _openAllActivity() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _AllActivityScreen(store: widget.store),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final garden = widget.store.garden;
    final selection = _selection;
    final selecting = selection != null;
    final email = widget.auth?.signedIn == true ? widget.auth?.email : null;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) _endSelection();
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: _endSelection,
                ),
                title: Text('${selection.length} selected'),
                actions: [
                  IconButton(
                    tooltip: 'Select all',
                    icon: const Icon(Icons.select_all),
                    onPressed: () => setState(
                      () => selection.addAll(garden.plants.map((p) => p.id)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete selected',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: selection.isEmpty ? null : _deleteSelected,
                  ),
                ],
              )
            : AppBar(
                toolbarHeight: 72,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Text('Your garden'),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Add plant',
                    icon: const Icon(Icons.add),
                    onPressed: _addPlant,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      tooltip: 'Profile',
                      onPressed: _openProfile,
                      icon: _Avatar(email: email, size: 32),
                    ),
                  ),
                ],
              ),
        body: garden.plants.isEmpty
            ? _EmptyHome(onAdd: _addPlant)
            : _PopulatedHome(this),
      ),
    );
  }
}

String _greeting(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 18
    ? 'Good afternoon'
    : 'Good evening';

class _Avatar extends StatelessWidget {
  const _Avatar({required this.email, required this.size});

  final String? email;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = email == null || email!.isEmpty
        ? null
        : email!.characters.first.toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: initial == null
          ? Icon(Icons.person_outline, size: size * 0.6)
          : Text(initial, style: TextStyle(fontSize: size * 0.45)),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/area-whole.png',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        Text('Add your first plant', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Bloom reminds you when to check its soil.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add plant'),
        ),
      ],
    );
  }
}

class _PopulatedHome extends StatelessWidget {
  const _PopulatedHome(this.state);

  final _HomeScreenState state;

  @override
  Widget build(BuildContext context) {
    final store = state.widget.store;
    final plants = store.garden.plants;
    final selection = state._selection;

    final due = <(Plant, WateringSchedule, CareTaskTiming)>[];
    for (final plant in plants) {
      final schedule = store.scheduleFor(plant.id);
      if (schedule == null) continue;
      final timing = CareTaskTiming.classify(schedule.nextCheckAt);
      if (timing != CareTaskTiming.upcoming) due.add((plant, schedule, timing));
    }
    due.sort((a, b) => a.$2.nextCheckAt.compareTo(b.$2.nextCheckAt));
    final recent = PlantActivity.forGarden(store.garden).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (selection == null) _TodayCard(state: state, due: due),
        const SizedBox(height: 24),
        SectionHeader(
          'My plants · ${plants.length}',
          action: selection == null && plants.length > 1 ? 'Select' : null,
          onAction: state._startSelection,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: [
            for (final plant in plants)
              _PlantTile(
                store: store,
                plant: plant,
                selected: selection?.contains(plant.id),
                onTap: selection == null
                    ? () => state._openPlant(plant)
                    : () => state._toggle(plant.id),
                onLongPress: selection == null
                    ? () => state._startSelection(plant.id)
                    : null,
              ),
            if (selection == null) _AddTile(onTap: state._addPlant),
          ],
        ),
        if (recent.isNotEmpty && selection == null) ...[
          const SizedBox(height: 24),
          SectionHeader(
            'Recent',
            action: 'See all',
            onAction: state._openAllActivity,
          ),
          for (final entry in recent)
            if (store.plant(entry.plantId) case final plant?)
              HistoryRow(plant: plant, entry: entry),
        ],
      ],
    );
  }
}

/// The single place that says what needs doing today.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state, required this.due});

  final _HomeScreenState state;
  final List<(Plant, WateringSchedule, CareTaskTiming)> due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (due.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: scheme.primary),
          title: const Text('Nothing to check today'),
        ),
      );
    }
    final now = DateTime.now();
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
            Text(
              due.length == 1
                  ? '1 plant to check'
                  : '${due.length} plants to check',
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final (plant, schedule, _) in due)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: PlantImage(
                          store: state.widget.store,
                          plant: plant,
                          height: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onPrimary,
                            ),
                          ),
                          Text(
                            relativeCheckLabel(schedule.nextCheckAt, now),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.onPrimary,
                        foregroundColor: scheme.primary,
                      ),
                      onPressed: () => state._openCheck(plant),
                      child: const Text('Check'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({
    required this.store,
    required this.plant,
    required this.onTap,
    this.onLongPress,
    this.selected,
  });

  final GardenStore store;
  final Plant plant;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final schedule = store.scheduleFor(plant.id);
    final status = schedule == null
        ? 'No schedule'
        : relativeCheckLabel(schedule.nextCheckAt, DateTime.now());
    final isSelected = selected == true;
    return Semantics(
      selected: selected == null ? null : isSelected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PlantImage(store: store, plant: plant, height: 160),
                  ),
                  if (isSelected)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.primary, width: 3),
                      ),
                    ),
                  if (selected != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: isSelected
                            ? scheme.primary
                            : scheme.surface.withValues(alpha: 0.9),
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
                          size: 18,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plant.name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: status.startsWith('Overdue')
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Material(
            color: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Icon(Icons.add, size: 32, color: scheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Add plant', style: Theme.of(context).textTheme.titleSmall),
        const Text(''),
      ],
    );
  }
}

class _AllActivityScreen extends StatelessWidget {
  const _AllActivityScreen({required this.store});

  final GardenStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final entries = PlantActivity.forGarden(store.garden);
      return Scaffold(
        appBar: AppBar(title: const Text('Recent activity')),
        body: entries.isEmpty
            ? const Center(child: Text('No activity yet'))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final entry in entries)
                    if (store.plant(entry.plantId) case final plant?)
                      HistoryRow(plant: plant, entry: entry),
                ],
              ),
      );
    },
  );
}
