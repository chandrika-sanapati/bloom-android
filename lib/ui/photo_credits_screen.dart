import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attribution for the bundled catalog photos (Wikimedia Commons).
class PhotoCreditsScreen extends StatelessWidget {
  const PhotoCreditsScreen({super.key});

  static Future<List<Map<String, dynamic>>> _load() async {
    final raw = await rootBundle.loadString('assets/data/image_credits.json');
    final list = (jsonDecode(raw) as Map<String, dynamic>)['credits'] as List;
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Photo credits')),
      body: FutureBuilder(
        future: _load(),
        builder: (context, snapshot) {
          final credits = snapshot.data;
          if (credits == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Plant photos come from Wikimedia Commons and are used '
                'under the licenses below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final credit in credits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(credit['plant'] as String),
                  subtitle: Text('${credit['author']} · ${credit['license']}'),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () => launchUrl(
                    Uri.parse(credit['source'] as String),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
