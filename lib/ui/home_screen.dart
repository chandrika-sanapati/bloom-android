import 'package:flutter/material.dart';

import '../data/garden_repository.dart';
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

enum _Tab { upcoming, past }

class _HomeScreenState extends State<HomeScreen> {
  _Tab _tab = _Tab.upcoming;
  bool _showHint = false;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChanged);
    _loadHint();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _selectTab(_Tab tab) => setState(() => _tab = tab);

  Future<void> _loadHint() async {
    final seen = await widget.flags.hasSeenAddPlantHint();
    if (!mounted) return;
    setState(() => _showHint = !seen && widget.store.garden.plants.isEmpty);
  }

  Future<void> _openCatalog() async {
    await widget.flags.markAddPlantHintSeen();
    if (!mounted) return;
    setState(() => _showHint = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CatalogScreen(store: widget.store)),
    );
  }

  void _openPhotoIdentification() {
    setState(() => _fabOpen = false);
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

  @override
  Widget build(BuildContext context) {
    final garden = widget.store.garden;
    final isEmpty = garden.plants.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const BloomTitle(),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: _openProfile,
          ),
        ],
      ),
      floatingActionButton: _AddPlantFabMenu(
        open: _fabOpen,
        showHint: isEmpty && _showHint,
        onToggle: () => setState(() => _fabOpen = !_fabOpen),
        onSearch: _openCatalog,
        onIdentify: _openPhotoIdentification,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fabOpen ? () => setState(() => _fabOpen = false) : null,
        child: isEmpty ? const _EmptyHome() : _PopulatedHome(this),
      ),
    );
  }
}

class _AddPlantFabMenu extends StatelessWidget {
  const _AddPlantFabMenu({
    required this.open,
    required this.showHint,
    required this.onToggle,
    required this.onSearch,
    required this.onIdentify,
  });

  final bool open;
  final bool showHint;
  final VoidCallback onToggle;
  final VoidCallback onSearch;
  final VoidCallback onIdentify;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open) ...[
          _FabMenuAction(
            icon: Icons.camera_alt_outlined,
            label: 'Identify from a photo',
            onTap: onIdentify,
          ),
          const SizedBox(height: 12),
          _FabMenuAction(
            icon: Icons.search,
            label: 'Search by name',
            onTap: onSearch,
          ),
          const SizedBox(height: 16),
        ] else if (showHint)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Chip(label: Text('Tap to add a plant')),
          ),
        Semantics(
          button: true,
          label: open ? 'Close add plant menu' : 'Add plant',
          hint: open ? null : 'Choose how to add a plant',
          child: FloatingActionButton(
            tooltip: open ? 'Close add plant menu' : 'Add plant',
            onPressed: onToggle,
            child: AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

class _FabMenuAction extends StatelessWidget {
  const _FabMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon), const SizedBox(width: 12), Text(label)],
          ),
        ),
      ),
    ),
  );
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/area-whole.png',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your first plant',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap + to choose a supported plant and start its watering check-ins.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final plants = store.garden.plants;

    final scheduled = <(Plant, WateringSchedule)>[];
    for (final plant in plants) {
      final schedule = store.scheduleFor(plant.id);
      if (schedule != null) scheduled.add((plant, schedule));
    }
    scheduled.sort((a, b) => a.$2.nextCheckAt.compareTo(b.$2.nextCheckAt));

    final past = PlantActivity.forGarden(store.garden);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        Text('My plants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: plants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final plant = plants[index];
              return PlantCard(
                plant: plant,
                schedule: store.scheduleFor(plant.id),
                onTap: () => state._openPlant(plant),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<_Tab>(
          segments: const [
            ButtonSegment(value: _Tab.upcoming, label: Text('Upcoming')),
            ButtonSegment(value: _Tab.past, label: Text('Past')),
          ],
          selected: {state._tab},
          onSelectionChanged: (selection) => state._selectTab(selection.first),
        ),
        const SizedBox(height: 16),
        if (state._tab == _Tab.upcoming)
          ..._upcoming(context, scheduled)
        else
          ..._pastRows(context, past.take(5).toList()),
      ],
    );
  }

  List<Widget> _upcoming(
    BuildContext context,
    List<(Plant, WateringSchedule)> scheduled,
  ) {
    if (scheduled.isEmpty) {
      return const [
        EmptyActivityCard(
          title: 'Nothing scheduled',
          detail: 'Add a supported plant to start watering check-ins.',
        ),
      ];
    }
    final widgets = <Widget>[];
    for (final timing in CareTaskTiming.values) {
      final items = scheduled
          .where(
            (item) => CareTaskTiming.classify(item.$2.nextCheckAt) == timing,
          )
          .toList();
      if (items.isEmpty) continue;
      if (timing != CareTaskTiming.upcoming) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              timing.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      for (final item in items) {
        widgets.add(
          TaskRow(
            plant: item.$1,
            schedule: item.$2,
            timing: timing,
            onTap: () => state._openCheck(item.$1),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  List<Widget> _pastRows(BuildContext context, List<PlantActivity> entries) {
    if (entries.isEmpty) {
      return const [
        EmptyActivityCard(
          title: 'No care history yet',
          detail: 'Your completed checks will appear here.',
        ),
      ];
    }
    final store = state.widget.store;
    final rows = <Widget>[];
    for (final entry in entries) {
      final plant = store.plant(entry.plantId);
      if (plant == null) continue;
      rows.add(HistoryRow(plant: plant, entry: entry));
      rows.add(const Divider(height: 1));
    }
    return rows;
  }
}
