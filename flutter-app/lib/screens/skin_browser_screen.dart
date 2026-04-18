import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/skin_provider.dart';
import '../theme/app_theme.dart';
import '../theme/skin/skin_manager.dart';
import '../theme/skin/skin_tokens.dart';

/// Browser screen for viewing and applying installed skin packs.
class SkinBrowserScreen extends StatefulWidget {
  const SkinBrowserScreen({super.key});

  @override
  State<SkinBrowserScreen> createState() => _SkinBrowserScreenState();
}

class _SkinBrowserScreenState extends State<SkinBrowserScreen> {
  late final SkinManager _manager;
  List<String> _skinNames = [];
  final Map<String, SkinManifest?> _manifests = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _manager = SkinManager();
    _loadSkins();
  }

  Future<void> _loadSkins() async {
    _skinNames = _manager.listAvailableSkins();
    for (final name in _skinNames) {
      _manifests[name] = await _manager.getManifest(name);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final skinProvider = context.watch<SkinProvider>();
    final activeName = skinProvider.skinName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SKIN_PACKS',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skinNames.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _skinNames.length,
                  itemBuilder: (context, index) {
                    final name = _skinNames[index];
                    final manifest = _manifests[name];
                    final isActive = name == activeName;
                    return _SkinCard(
                      name: name,
                      manifest: manifest,
                      isActive: isActive,
                      onApply: () => skinProvider.setSkin(name),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await skinProvider.importSkin();
          await _loadSkins();
        },
        icon: const Icon(Icons.file_download_outlined),
        label: Text(
          'IMPORT',
          style: GoogleFonts.changa(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.palette_outlined, size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            'No skin packs installed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Import an .rkskin file to get started',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final String name;
  final SkinManifest? manifest;
  final bool isActive;
  final VoidCallback onApply;

  const _SkinCard({
    required this.name,
    required this.manifest,
    required this.isActive,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final m = manifest;
    final displayName = m?.name ?? name;
    final author = m?.author ?? 'Unknown';
    final version = m?.version ?? '—';
    final description = m?.description;

    // Preview: show color palette from tokens
    final previewColors = m?.tokens.styles.values
        .take(5)
        .map((s) => s.primary)
        .toList() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive
          ? AppColors.brandOrange.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? AppColors.brandOrange.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Color palette preview
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: previewColors.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          for (final c in previewColors)
                            Expanded(
                              child: Container(color: c),
                            ),
                        ],
                      ),
                    )
                  : const Icon(Icons.palette_outlined, color: Colors.white24),
            ),
            const SizedBox(width: 16),
            // Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName.toUpperCase(),
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.changa(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$author  ·  v$version',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Apply button
            if (!isActive)
              TextButton(
                onPressed: onApply,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandOrange,
                ),
                child: Text(
                  'APPLY',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
