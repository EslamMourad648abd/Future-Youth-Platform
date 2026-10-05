import 'package:bbc_api_tool/models/api_preset.dart';
import 'package:bbc_api_tool/models/api_prest_group.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/postman_loader.dart';
import '../../widgets/request_editor.dart';
import '../../router/app_router.dart';
import '../../services/localization_service.dart';
import '../../services/theme_service.dart';

const Color kBbcApiBrandColor = Color(0xff003366);

class BbcApiHomeScreen extends StatefulWidget {
  const BbcApiHomeScreen({super.key});
  @override
  State<BbcApiHomeScreen> createState() => _BbcApiHomeScreenState();
}

class _BbcApiHomeScreenState extends State<BbcApiHomeScreen> {
  List<ApiPresetGroup> groups = [];
  bool loading = true;
  String? error;
  dynamic selectedPreset;
  String? selectedGroupName;
  String? selectedCallTitle;
  bool _disposed = false;

  @override
  void initState() { super.initState(); _loadCollection(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }

  Future<void> _loadCollection() async {
    try {
      final loadedGroups = await PostmanLoader.loadFromAssets('assets/BBC_Request.postman_collection.json');
      if (!_disposed && mounted) setState(() { groups = loadedGroups; loading = false; });
    } catch (e) {
      if (!_disposed && mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  void _selectPreset(ApiPresetGroup group, ApiPreset preset) {
    setState(() {
      selectedGroupName = group.name; selectedCallTitle = preset.name;
      selectedPreset = ApiPreset(
        id: preset.id, name: preset.name, method: preset.method, url: preset.url,
        headers: Map<String, String>.from(preset.headers),
        params: Map<String, String>.from(preset.params),
        body: preset.body, editableFields: Map<String, bool>.from(preset.editableFields),
        urlVariables: List<String>.from(preset.urlVariables),
        authType: preset.authType, authToken: preset.authToken,
      );
    });
  }

  void _clearSelection() { setState(() { selectedPreset = null; selectedGroupName = null; selectedCallTitle = null; }); }
  void _backToPlatform(BuildContext context) { context.go(AppRouter.home); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return Scaffold(backgroundColor: theme.colorScheme.surface, body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)));
    if (error != null) return Scaffold(backgroundColor: theme.colorScheme.surface, body: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 42, color: Colors.redAccent), const SizedBox(height: 16), const Text('Failed to load collections', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text(error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))])))));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 1100;
        if (isMobile) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: theme.colorScheme.surface, elevation: 0,
              leading: Builder(builder: (context) => IconButton(icon: Icon(Icons.menu, color: theme.colorScheme.primary), onPressed: () => Scaffold.of(context).openDrawer())),
              title: const Text('BBC API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true, shape: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            drawer: Drawer(width: 285, child: _BbcApiNavigation(groups: groups, selectedGroupName: selectedGroupName, selectedCallTitle: selectedCallTitle, isDrawer: true, onBackToPlatform: () { Navigator.pop(context); _backToPlatform(context); }, onPresetSelected: (g, p) { Navigator.pop(context); _selectPreset(g, p); })),
            body: _BbcApiContent(selectedPreset: selectedPreset, onClose: _clearSelection),
          );
        }
        return Row(children: [
          _BbcApiNavigation(groups: groups, selectedGroupName: selectedGroupName, selectedCallTitle: selectedCallTitle, onBackToPlatform: () => _backToPlatform(context), onPresetSelected: _selectPreset),
          Expanded(child: _BbcApiContent(selectedPreset: selectedPreset, onClose: _clearSelection)),
        ]);
      }),
    );
  }
}

class _BbcApiNavigation extends StatelessWidget {
  const _BbcApiNavigation({required this.groups, required this.selectedGroupName, required this.selectedCallTitle, required this.onBackToPlatform, required this.onPresetSelected, this.isDrawer = false});
  final List<ApiPresetGroup> groups; final String? selectedGroupName, selectedCallTitle; final bool isDrawer; final VoidCallback onBackToPlatform; final Function(ApiPresetGroup, ApiPreset) onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: 285, decoration: BoxDecoration(color: theme.colorScheme.surface, border: isDrawer ? null : Border(right: BorderSide(color: theme.dividerColor))),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Material(color: Colors.transparent, child: InkWell(onTap: onBackToPlatform, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [Icon(Icons.arrow_back_rounded, size: 19, color: theme.colorScheme.primary), const SizedBox(width: 9), Expanded(child: Text(l10n?.translate('back_to_platforms') ?? 'Back to Platforms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)))]))))),
        const _BbcApiHeader(),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Icon(Icons.folder_outlined, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)), const SizedBox(width: 7), Text(l10n?.translate('collections') ?? 'Collections', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 0.3))])),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: groups.map((g) => _BbcApiGroup(group: g, selected: selectedGroupName == g.name, selectedCallTitle: selectedCallTitle, onPresetSelected: onPresetSelected)).toList()))),
        const _BbcApiNavigationFooter(),
      ])),
    );
  }
}

class _BbcApiHeader extends StatelessWidget {
  const _BbcApiHeader();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.api_outlined, color: theme.colorScheme.primary, size: 23)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n?.translate('bbc_api_tool') ?? 'BBC API Tool', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        Text(l10n?.translate('api_collections') ?? 'API Collections', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ])),
      ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeNotifier,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          return IconButton(onPressed: ThemeService.toggleTheme, icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20), color: theme.colorScheme.onSurface.withValues(alpha: 0.6));
        },
      ),
    ]));
  }
}

class _BbcApiGroup extends StatelessWidget {
  const _BbcApiGroup({required this.group, required this.selected, required this.selectedCallTitle, required this.onPresetSelected});
  final ApiPresetGroup group; final bool selected; final String? selectedCallTitle; final Function(ApiPresetGroup, ApiPreset) onPresetSelected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: selected ? theme.colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Theme(data: theme.copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
        initiallyExpanded: selected, tilePadding: const EdgeInsets.symmetric(horizontal: 12), childrenPadding: const EdgeInsets.only(bottom: 6),
        leading: Icon(selected ? Icons.folder : Icons.folder_outlined, size: 20, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
        children: group.presets.map((p) {
          final isS = selectedCallTitle == p.name;
          return Padding(padding: const EdgeInsets.only(left: 12, right: 8, bottom: 3), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(8), onTap: () => onPresetSelected(group, p), child: AnimatedContainer(
            duration: const Duration(milliseconds: 160), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: isS ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(_methodIcon(p.method), size: 16, color: isS ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 9),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: isS ? FontWeight.bold : FontWeight.normal, color: isS ? theme.colorScheme.primary : theme.colorScheme.onSurface))),
              if (isS) Container(width: 4, height: 18, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(4))),
            ]),
          ))));
        }).toList(),
      )),
    );
  }
  IconData _methodIcon(String m) {
    switch (m.toUpperCase()) {
      case 'GET': return Icons.arrow_downward_rounded;
      case 'POST': return Icons.add_circle_outline;
      case 'PUT': return Icons.edit_outlined;
      case 'PATCH': return Icons.sync_alt_rounded;
      case 'DELETE': return Icons.delete_outline;
      default: return Icons.api_outlined;
    }
  }
}

class _BbcApiNavigationFooter extends StatelessWidget {
  const _BbcApiNavigationFooter();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
      child: Row(children: [
        Icon(Icons.settings_suggest_outlined, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text('API Operations', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
      ]),
    );
  }
}

class _BbcApiContent extends StatelessWidget {
  const _BbcApiContent({required this.selectedPreset, required this.onClose});
  final dynamic selectedPreset; final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: selectedPreset == null ? const _BbcApiEmptyState() : _BbcApiRequestContent(key: ValueKey(selectedPreset.id), selectedPreset: selectedPreset, onClose: onClose),
    );
  }
}

class _BbcApiEmptyState extends StatelessWidget {
  const _BbcApiEmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: Card(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.api_outlined, size: 36, color: theme.colorScheme.primary)),
      const SizedBox(height: 24),
      Text('BBC API Collections', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      const SizedBox(height: 10),
      Text('Select a request to start testing.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)),
    ]))));
  }
}

class _BbcApiRequestContent extends StatelessWidget {
  const _BbcApiRequestContent({super.key, required this.selectedPreset, required this.onClose});
  final dynamic selectedPreset; final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.api_outlined, color: theme.colorScheme.primary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(selectedPreset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text('API Request', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ])),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded), color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      ]))),
      const SizedBox(height: 16),
      Expanded(child: Card(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: RequestEditor(key: ValueKey(selectedPreset.id), preset: selectedPreset)))),
    ]);
  }
}
