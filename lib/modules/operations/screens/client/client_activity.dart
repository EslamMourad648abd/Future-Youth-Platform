import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/activity_model.dart';
import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientActivityScreen extends StatefulWidget {
  final String clientId;

  const ClientActivityScreen({super.key, required this.clientId});

  @override
  State<ClientActivityScreen> createState() => _ClientActivityScreenState();
}

class _ClientActivityScreenState extends State<ClientActivityScreen> {
  String _categoryFilter = 'all';
  String _actionFilter = 'all';
  String _search = '';

  late final TextEditingController _searchController;
  late final OnboardingRepository _repository;

  // IMPORTANT:
  // Keep these streams stable instead of creating them inside build().
  // This prevents the Firestore streams from restarting whenever
  // the user types into the search field.
  late Stream<ClientModel?> _clientStream;
  late Stream<List<ActivityModel>> _activityStream;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _repository = OnboardingRepository();

    _clientStream = _repository.watchClient(widget.clientId);
    _activityStream = _repository.watchClientActivity(widget.clientId);
  }

  @override
  void didUpdateWidget(covariant ClientActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.clientId != widget.clientId) {
      _clientStream = _repository.watchClient(widget.clientId);
      _activityStream =
          _repository.watchClientActivity(widget.clientId);

      _categoryFilter = 'all';
      _actionFilter = 'all';
      _search = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<ClientModel?>(
      // Use the existing stream instead of creating a new one in build().
      stream: _clientStream,
      builder: (context, clientSnap) {
        if (clientSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (clientSnap.hasError || clientSnap.data == null) {
          return Center(
            child: Text(
              clientSnap.hasError
                  ? 'Failed to load client activity.'
                  : 'Not found.',
            ),
          );
        }

        final client = clientSnap.data!;

        return StreamBuilder<List<ActivityModel>>(
          // Use the existing activity stream instead of recreating it
          // every time the screen rebuilds.
          stream: _activityStream,
          builder: (context, activitySnap) {
            if (activitySnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (activitySnap.hasError) {
              return Center(
                child: Text('Failed to load activity.\n${activitySnap.error}'),
              );
            }

            final allActivities =
                activitySnap.data ?? const <ActivityModel>[];
            final filtered = _filterActivities(allActivities);

            return LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  color: theme.colorScheme.surface,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(builder: (context, headerConstraints) {
                              final isCompact = headerConstraints.maxWidth < 600;

                              final content = [
                                Expanded(
                                  flex: isCompact ? 0 : 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Activity',
                                        style: TextStyle(
                                          fontSize: isCompact ? 22 : 26,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Audit history for ${client.companyName}',
                                        style: TextStyle(
                                          fontSize: isCompact ? 12 : 14,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCompact)
                                  const SizedBox(height: 16)
                                else
                                  const SizedBox(width: 12),
                                _CountBadge(
                                  count: filtered.length,
                                  totalCount: allActivities.length,
                                  filtered:
                                  filtered.length != allActivities.length,
                                ),
                              ];

                              return isCompact
                                  ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: content,
                              )
                                  : Row(
                                children: content,
                              );
                            }),
                            const SizedBox(height: 28),
                            _SummaryCard(client: client),
                            const SizedBox(height: 20),
                            _Filters(
                              activities: allActivities,
                              categoryFilter: _categoryFilter,
                              actionFilter: _actionFilter,
                              search: _search,
                              searchController: _searchController,
                              onCategoryChanged: (value) =>
                                  setState(() => _categoryFilter = value),
                              onActionChanged: (value) =>
                                  setState(() => _actionFilter = value),
                              onSearchChanged: (value) =>
                                  setState(() => _search = value),
                              onClear: () {
                                _searchController.clear();

                                setState(() {
                                  _categoryFilter = 'all';
                                  _actionFilter = 'all';
                                  _search = '';
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            _Timeline(activities: filtered),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
            );
          },
        );
      },
    );
  }

  List<ActivityModel> _filterActivities(
      List<ActivityModel> activities,
      ) {
    final query = _search.trim().toLowerCase();

    return activities.where((activity) {
      if (_categoryFilter != 'all' &&
          _activityCategory(activity) != _categoryFilter) {
        return false;
      }

      if (_actionFilter != 'all' &&
          activity.action.trim().toLowerCase() != _actionFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final searchable = <String>[
        activity.title,
        activity.description,
        activity.type,
        activity.action,
        activity.actorName,
        activity.actorId,
        _flattenMetadata(
          _meaningfulMetadata(activity.metadata),
        ),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final ClientModel client;

  const _SummaryCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 22),
            child: Wrap(
              spacing: isMobile ? 16 : 32,
              runSpacing: isMobile ? 12 : 18,
              children: [
                _SItem(
                  l: 'Company',
                  v: client.companyName,
                  i: Icons.business,
                ),
                _SItem(
                  l: 'ACC',
                  v: client.accNumber,
                  i: Icons.badge,
                ),
                _SItem(
                  l: 'Activation',
                  v: client.activationStatus,
                  i: Icons.power_settings_new,
                ),
                _SItem(
                  l: 'Verification',
                  v: client.verificationStatus,
                  i: Icons.verified,
                ),
                _SItem(
                  l: 'Chatbot',
                  v: client.chatbotStatus,
                  i: Icons.smart_toy,
                ),
                _SItem(
                  l: 'Group',
                  v: client.groupStatus,
                  i: Icons.groups,
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

class _SItem extends StatelessWidget {
  final String l;
  final String v;
  final IconData i;

  const _SItem({
    required this.l,
    required this.v,
    required this.i,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 140,
            maxWidth: isMobile ? (screenWidth - 80) / 2 : 200,
          ),
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      i,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          v.trim().isEmpty ? '—' : v,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  final List<ActivityModel> activities;
  final String categoryFilter;
  final String actionFilter;
  final String search;
  final TextEditingController searchController;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onActionChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  const _Filters({
    required this.activities,
    required this.categoryFilter,
    required this.actionFilter,
    required this.search,
    required this.searchController,
    required this.onCategoryChanged,
    required this.onActionChanged,
    required this.onSearchChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'all',
      'activation',
      'verification',
      'chatbot',
      'channel',
      'group',
      'crm',
      'assignment',
      'client',
      'task',
      ...activities.map(_activityCategory),
    }.toList();

    final actions = <String>{
      'all',
      ...activities
          .map((e) => e.action.trim().toLowerCase())
          .where((e) => e.isNotEmpty),
    }.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
            
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : (isTablet ? 300 : 250),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search activity...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 19,
                      ),
                      suffixIcon: search.isEmpty
                          ? null
                          : IconButton(
                        tooltip: 'Clear search',
                        onPressed: onClear,
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                        ),
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                _FilterDropdown(
                  label: 'Section',
                  width: isMobile ? double.infinity : (isTablet ? 200 : 180),
                  value: categories.contains(categoryFilter)
                      ? categoryFilter
                      : 'all',
                  values: categories,
                  onChanged: onCategoryChanged,
                ),
                _FilterDropdown(
                  label: 'Action',
                  width: isMobile ? double.infinity : (isTablet ? 200 : 180),
                  value: actions.contains(actionFilter)
                      ? actionFilter
                      : 'all',
                  values: actions,
                  onChanged: onActionChanged,
                ),
                if (categoryFilter != 'all' ||
                    actionFilter != 'all' ||
                    search.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: isMobile ? 0 : 8),
                    child: TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(
                        Icons.filter_alt_off,
                        size: 17,
                      ),
                      label: const Text('Clear filters'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final double width;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.width,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: values
            .map(
              (value) => DropdownMenuItem<String>(
            value: value,
            child: Text(
              _prettyLabel(value),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<ActivityModel> activities;

  const _Timeline({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No activity matches the current filters.',
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              activities.length,
                  (i) => _Item(
                act: activities[i],
                last: i == activities.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final ActivityModel act;
  final bool last;

  const _Item({
    required this.act,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _color(act.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 42,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(act.type),
                  size: 17,
                  color: c,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: 50,
                  color: theme.dividerColor,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _ActivityCard(act: act),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel act;

  const _ActivityCard({required this.act});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _meaningfulMetadata(act.metadata);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.35),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;

          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              14,
              0,
              14,
              14,
            ),
            title: isCompact
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.title.trim().isEmpty
                      ? 'Activity'
                      : act.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fDt(act.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  child: Text(
                    act.title.trim().isEmpty
                        ? 'Activity'
                        : act.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _fDt(act.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (act.action.trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _prettyLabel(act.action),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  if (act.description.trim().isNotEmpty)
                    Text(
                      act.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        act.actorName.trim().isEmpty
                            ? 'System'
                            : act.actorName,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              if (metadata.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No additional details recorded.',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                _MetadataDetails(metadata: metadata),
            ],
          );
        },
      ),
    );
  }
}

class _MetadataDetails extends StatelessWidget {
  final Map<String, dynamic> metadata;

  const _MetadataDetails({
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change details',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...metadata.entries.map(
                (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MetadataRow(
                label: _metadataLabel(entry.key),
                value: _formatMetadataValue(entry.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 450;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 155,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final int totalCount;
  final bool filtered;

  const _CountBadge({
    required this.count,
    required this.totalCount,
    required this.filtered,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            filtered
                ? '$count / $totalCount events'
                : '$count events',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String _activityCategory(ActivityModel activity) {
  final type = activity.type.trim().toLowerCase();

  if (type == 'activation' || type.startsWith('activation_')) {
    return 'activation';
  }

  if (type == 'verification' ||
      type.startsWith('verification_')) {
    return 'verification';
  }

  if (type == 'chatbot' ||
      type.startsWith('chatbot_')) {
    return 'chatbot';
  }

  if (type == 'channel' ||
      type == 'channels' ||
      type.startsWith('channel_')) {
    return 'channel';
  }

  if (type == 'group' ||
      type.startsWith('group_')) {
    return 'group';
  }

  if (type == 'crm' ||
      type.startsWith('crm_')) {
    return 'crm';
  }

  if (type == 'assignment' ||
      type.startsWith('assignment_')) {
    return 'assignment';
  }

  if (type == 'task' ||
      type.startsWith('task_')) {
    return 'task';
  }

  if (type == 'client' ||
      type.startsWith('client_')) {
    return 'client';
  }

  return type.isEmpty ? 'client' : type;
}

Map<String, dynamic> _meaningfulMetadata(
    Map<String, dynamic> source,
    ) {
  final result = <String, dynamic>{};

  // Prefer actual change data. Do not expose full before/after snapshots
  // when the activity already records the exact changed fields.
  final changedFields = source['changedFields'];

  if (changedFields is Map &&
      changedFields.isNotEmpty) {
    result['changedFields'] =
        _removeEmptyValues(changedFields);
  }

  final excluded = <String>{
    'changedFields',
    'previousChannel',
    'updatedChannel',
    'channel',
    'deletedChannel',
  };

  for (final entry in source.entries) {
    if (excluded.contains(entry.key)) continue;

    final cleaned = _cleanValue(entry.value);

    if (_hasMeaningfulValue(cleaned)) {
      result[entry.key] = cleaned;
    }
  }

  return result;
}

dynamic _cleanValue(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  if (value is Map) {
    return _removeEmptyValues(value);
  }

  if (value is Iterable) {
    final list = value
        .map(_cleanValue)
        .where(_hasMeaningfulValue)
        .toList();

    return list.isEmpty ? null : list;
  }

  return value;
}

Map<String, dynamic> _removeEmptyValues(Map value) {
  final result = <String, dynamic>{};

  for (final entry in value.entries) {
    final cleaned = _cleanValue(entry.value);

    if (_hasMeaningfulValue(cleaned)) {
      result[entry.key.toString()] = cleaned;
    }
  }

  return result;
}

bool _hasMeaningfulValue(dynamic value) {
  if (value == null) return false;

  if (value is String) {
    return value.trim().isNotEmpty;
  }

  if (value is Map) {
    return value.isNotEmpty;
  }

  if (value is Iterable) {
    return value.isNotEmpty;
  }

  return true;
}

String _fDt(DateTime? d) {
  if (d == null) return '—';

  return '${d.day}/${d.month}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

IconData _icon(String type) {
  switch (_activityCategoryFromType(type)) {
    case 'client':
      return Icons.person_add;

    case 'assignment':
      return Icons.assignment_ind;

    case 'activation':
      return Icons.power_settings_new;

    case 'verification':
      return Icons.verified;

    case 'chatbot':
      return Icons.smart_toy;

    case 'channel':
      return Icons.hub;

    case 'group':
      return Icons.groups;

    case 'crm':
      return Icons.comment;

    case 'task':
      return Icons.task_alt;

    default:
      return Icons.history;
  }
}

Color _color(String type) {
  switch (_activityCategoryFromType(type)) {
    case 'client':
      return Colors.green;

    case 'assignment':
      return Colors.indigo;

    case 'activation':
      return Colors.blue;

    case 'verification':
      return Colors.blue;

    case 'chatbot':
      return Colors.teal;

    case 'channel':
      return Colors.cyan;

    case 'group':
      return Colors.orange;

    case 'crm':
      return Colors.brown;

    case 'task':
      return Colors.deepPurple;

    default:
      return Colors.blueGrey;
  }
}

String _activityCategoryFromType(String type) {
  final normalized = type.trim().toLowerCase();

  if (normalized == 'activation' ||
      normalized.startsWith('activation_')) {
    return 'activation';
  }

  if (normalized == 'verification' ||
      normalized.startsWith('verification_')) {
    return 'verification';
  }

  if (normalized == 'chatbot' ||
      normalized.startsWith('chatbot_')) {
    return 'chatbot';
  }

  if (normalized == 'channel' ||
      normalized == 'channels' ||
      normalized.startsWith('channel_')) {
    return 'channel';
  }

  if (normalized == 'group' ||
      normalized.startsWith('group_')) {
    return 'group';
  }

  if (normalized == 'crm' ||
      normalized.startsWith('crm_')) {
    return 'crm';
  }

  if (normalized == 'assignment' ||
      normalized.startsWith('assignment_')) {
    return 'assignment';
  }

  if (normalized == 'task' ||
      normalized.startsWith('task_')) {
    return 'task';
  }

  if (normalized == 'client' ||
      normalized.startsWith('client_')) {
    return 'client';
  }

  return normalized;
}

String _metadataLabel(String key) {
  return key
      .replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
        (match) =>
    '${match.group(1)} ${match.group(2)}',
  )
      .replaceAll('_', ' ')
      .replaceFirstMapped(
    RegExp(r'^.'),
        (match) =>
        match.group(0)!.toUpperCase(),
  );
}

String _formatMetadataValue(dynamic value) {
  if (value is Timestamp) {
    return _fDt(value.toDate());
  }

  if (value is DateTime) {
    return _fDt(value);
  }

  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
      '${_metadataLabel(entry.key.toString())}: '
          '${_formatMetadataValue(entry.value)}',
    )
        .join('  |  ');
  }

  if (value is Iterable) {
    return value.map(_formatMetadataValue).join('  |  ');
  }

  if (value is bool) {
    return value ? 'Yes' : 'No';
  }

  return value?.toString() ?? '';
}

String _prettyLabel(String value) {
  if (value == 'all') return 'All';

  return value
      .replaceAll('_', ' ')
      .replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
        (match) =>
    '${match.group(1)} ${match.group(2)}',
  )
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
    part[0].toUpperCase() +
        part.substring(1),
  )
      .join(' ');
}

String _flattenMetadata(dynamic value) {
  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
      '${entry.key} '
          '${_flattenMetadata(entry.value)}',
    )
        .join(' ');
  }

  if (value is Iterable) {
    return value.map(_flattenMetadata).join(' ');
  }

  return value?.toString() ?? '';
}