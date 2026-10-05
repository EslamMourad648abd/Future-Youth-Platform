import 'package:flutter/material.dart';

import '../../../../../services/auth_service.dart';
import '../../../../../services/localization_service.dart';
import '../../models/client_model.dart';
import '../../models/onboarding_tasks_model.dart';
import '../../repositories/onboarding_repository.dart';

class OnboardingReports extends StatefulWidget {
  const OnboardingReports({super.key});

  @override
  State<OnboardingReports> createState() => _OnboardingReportsState();
}

class _OnboardingReportsState extends State<OnboardingReports> {
  final OnboardingRepository _repository = OnboardingRepository();

  DateTime _startDate = _dateOnly(DateTime.now());
  DateTime _endDate = _dateOnly(DateTime.now());

  String _taskTypeFilter = 'All';
  String _clientStatusFilter = 'All';
  String _agentFilter = 'All';

  bool _rangeMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!AuthService.isSuperAdmin) {
      return Scaffold(
        body: _ReportsMessage(
          icon: Icons.lock_outline,
          title: l10n?.translate('access_denied') ?? 'Access Denied',
          message:
          l10n?.translate('super_admin_only') ??
              'Only Super Admins can view reports.',
          isError: false,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<Map<String, Map<String, String>>>(
        stream: _repository.watchAllAgentsByRole(),
        builder: (context, agentSnapshot) {
          if (agentSnapshot.hasError) {
            return _ReportsMessage(
              icon: Icons.error_outline,
              title: 'Error',
              message: '${agentSnapshot.error}',
              isError: true,
            );
          }

    final groupedAgents = agentSnapshot.data ?? <String, Map<String, String>>{};
          
    // Build the grouped items list for validation
    final List<String> validAgentNames = ['All'];
    for (final team in groupedAgents.values) {
      validAgentNames.addAll(team.values);
    }

    // Ensure the current filter is valid for the loaded data
    if (!validAgentNames.contains(_agentFilter)) {
      _agentFilter = 'All';
    }

    // Flatten for calculations
    final allAgents = <String, String>{};
    groupedAgents.values.forEach(allAgents.addAll);

          return StreamBuilder<List<ClientModel>>(
            stream: _repository.watchClients(),
            builder: (context, clientSnapshot) {
              if (clientSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                );
              }

              if (clientSnapshot.hasError) {
                return _ReportsMessage(
                  icon: Icons.error_outline,
                  title: 'Error',
                  message: '${clientSnapshot.error}',
                  isError: true,
                );
              }

              final clients = clientSnapshot.data ?? <ClientModel>[];

              return StreamBuilder<List<OnboardingTaskModel>>(
                stream: _repository.watchAllTasks(),
                builder: (context, taskSnapshot) {
                  if (taskSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }

                  if (taskSnapshot.hasError) {
                    return _ReportsMessage(
                      icon: Icons.error_outline,
                      title: 'Error',
                      message: '${taskSnapshot.error}',
                      isError: true,
                    );
                  }

                  return _buildContent(
                    clients,
                    taskSnapshot.data ?? <OnboardingTaskModel>[],
                    groupedAgents,
                    allAgents,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildContent(
      List<ClientModel> clients,
      List<OnboardingTaskModel> tasks,
      Map<String, Map<String, String>> groupedAgents,
      Map<String, String> allAgents,
      ) {
    final filteredTasks = tasks
        .where(_taskMatchesDate)
        .where(_taskMatchesType)
        .where((t) => _taskMatchesAgent(t, allAgents))
        .toList();

    final filteredClients = clients
        .where(_clientMatchesStatus)
        .where((c) => _clientMatchesAgent(c, allAgents))
        .toList();

    final metrics = _ReportMetrics.fromData(
      clients: filteredClients,
      tasks: filteredTasks,
      startDate: _startDate,
      endDate: _endDate,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1250,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 22),

              _buildDateSelector(),

              const SizedBox(height: 18),

              _buildFilters(groupedAgents),

              const SizedBox(height: 24),

              _buildAgentOccupancy(
                filteredTasks,
                allAgents,
              ),

              const SizedBox(height: 24),

              _buildSummary(metrics),

              const SizedBox(height: 24),

              _buildMainGrid(metrics),

              const SizedBox(height: 24),

              _buildTaskPerformance(filteredTasks),

              const SizedBox(height: 24),

              _buildClientStatusBreakdown(filteredClients),

              const SizedBox(height: 24),

              _buildClientProgress(filteredClients),

              const SizedBox(height: 24),

              _buildTaskDetails(filteredTasks),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 600;
      final content = [
        Expanded(
          flex: isCompact ? 0 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.translate('reports') ?? 'Reports',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n?.translate('analyze_onboarding') ??
                    'Analyze onboarding performance and workload.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCompact) const SizedBox(height: 16) else const SizedBox(width: 16),
        _DateRangeBadge(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ];

      return isCompact
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      );
    });
  }

  // ============================================================
  // DATE SELECTOR
  // ============================================================

  Widget _buildDateSelector() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 850;

          final periodLabel = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                l10n?.translate('report_period') ?? 'Report Period',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

          final periodSelector = SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text(
                  l10n?.translate('day') ?? 'Day',
                ),
                icon: const Icon(Icons.today),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text(
                  l10n?.translate('range') ?? 'Range',
                ),
                icon: const Icon(Icons.date_range),
              ),
            ],
            selected: {_rangeMode},
            onSelectionChanged: (selection) {
              setState(() {
                _rangeMode = selection.first;
                if (!_rangeMode) {
                  _endDate = _startDate;
                }
              });
            },
          );

          final dateControls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: _movePrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              OutlinedButton.icon(
                onPressed: _pickStartDate,
                icon: const Icon(
                  Icons.calendar_today,
                  size: 17,
                ),
                label: Text(_formatDate(_startDate)),
              ),
              if (_rangeMode) ...[
                const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.grey,
                ),
                OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(
                    Icons.event,
                    size: 17,
                  ),
                  label: Text(_formatDate(_endDate)),
                ),
              ],
              IconButton(
                tooltip: 'Next',
                onPressed: _moveNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    periodLabel,
                    periodSelector,
                  ],
                ),
                const SizedBox(height: 20),
                Center(child: dateControls),
              ],
            );
          }

          return Row(
            children: [
              periodLabel,
              const SizedBox(width: 20),
              periodSelector,
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: dateControls,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(
      Map<String, Map<String, String>> groupedAgents,
      ) {
    final l10n = AppLocalizations.of(context);

    // Build the grouped items list and keep track of valid values
    final Set<String> validValues = {'All'};
    final List<DropdownMenuItem<String>> dropdownItems = [
      const DropdownMenuItem(value: 'All', child: Text('All Agents')),
    ];

    // Helper to add group
    void addTeamGroup(String role, String label, Color color) {
      final team = groupedAgents[role] ?? {};
      if (team.isNotEmpty) {
        dropdownItems.add(DropdownMenuItem(
          enabled: false, 
          child: Text('-- $label --', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color))
        ));
        final sortedNames = team.values.map((s) => s.trim()).toList()..sort();
        for (final name in sortedNames) {
          if (name.isNotEmpty) {
            validValues.add(name);
            dropdownItems.add(DropdownMenuItem(
              value: name, 
              child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(name))
            ));
          }
        }
      }
    }

    addTeamGroup('onboarding_agent', 'ONBOARDING TEAM', Colors.blue);
    addTeamGroup('support_agent', 'SUPPORT TEAM', Colors.green);

    // CRITICAL: Validate selection against valid values before rendering
    String currentSelection = _agentFilter.trim();
    if (!validValues.contains(currentSelection)) {
      currentSelection = 'All';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final content = [
          Expanded(
            flex: isCompact ? 0 : 1,
            child: DropdownButtonFormField<String>(
              value: currentSelection,
              decoration: InputDecoration(
                labelText: l10n?.translate('agent') ?? 'Filter by Agent',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: dropdownItems,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _agentFilter = value;
                  });
                }
              },
            ),
          ),

          if (isCompact)
            const SizedBox(height: 12)
          else
            const SizedBox(width: 14),

          Expanded(
            flex: isCompact ? 0 : 1,
            child: _FilterDropdown(
              label: l10n?.translate('task_type') ?? 'Type',
              value: _taskTypeFilter,
              values: const [
                'All',
                'Activation',
                'Verification',
                'Chatbot',
                'Client Follow Up',
                'Internal',
              ],
              onChanged: (value) {
                setState(() {
                  _taskTypeFilter = value;
                });
              },
            ),
          ),

          if (isCompact)
            const SizedBox(height: 12)
          else
            const SizedBox(width: 14),

          Expanded(
            flex: isCompact ? 0 : 1,
            child: _FilterDropdown(
              label:
              l10n?.translate('client_status') ??
                  'Status',
              value: _clientStatusFilter,
              values: const [
                'All',
                'Not Started',
                'In Progress',
                'Pending',
                'Activated',
                'Completed',
              ],
              onChanged: (value) {
                setState(() {
                  _clientStatusFilter = value;
                });
              },
            ),
          ),

          if (isCompact)
            const SizedBox(height: 12)
          else
            const SizedBox(width: 14),

          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: Text(
              l10n?.translate('reset') ?? 'Reset',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          );
        }

        return Row(
          children: content,
        );
      },
    );
  }

  // ============================================================
  // AGENT OCCUPANCY
  // ============================================================

  Widget _buildAgentOccupancy(
      List<OnboardingTaskModel> tasks,
      Map<String, String> agents,
      ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final counts = <String, int>{};
    final occupancy = <String, Duration>{};

    for (final task in tasks) {
      final agentName =
          agents[task.assignedTo] ?? 'Unknown';

      counts[agentName] =
          (counts[agentName] ?? 0) + 1;

      if (task.completedDuration != null) {
        occupancy[agentName] =
            (occupancy[agentName] ?? Duration.zero) +
                task.completedDuration!;
      }
    }

    final sortedAgents = counts.keys.toList()
      ..sort(
            (a, b) => counts[b]!.compareTo(
          counts[a]!,
        ),
      );

    return _SectionCard(
      title:
      l10n?.translate('agent_occupancy') ??
          'Agent Occupancy',
      icon: Icons.badge_outlined,
      child: sortedAgents.isEmpty
          ? _InlineEmpty(
        text:
        l10n?.translate('no_activity_found') ??
            'No activity found.',
      )
          : Column(
        children: sortedAgents.map(
              (agentName) {
            return Padding(
              padding:
              const EdgeInsets.only(
                bottom: 12,
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 500;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                            theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              size: 16,
                              color:
                              theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              agentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          _SmallStatusChip(
                            label: '${counts[agentName]} tasks',
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(
                              occupancy[agentName] ?? Duration.zero,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                      theme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color:
                        theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        agentName,
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                    _SmallStatusChip(
                      label:
                      '${counts[agentName]} tasks',
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: Text(
                        _formatDuration(
                          occupancy[agentName] ??
                              Duration.zero,
                        ),
                        textAlign:
                        TextAlign.right,
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(
      _ReportMetrics metrics,
      ) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns =
        constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1100
            ? 2
            : 5;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics:
          const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio:
          columns == 1 ? 4.5 : (columns == 5 ? 1.9 : 2.4),
          children: [
            _MetricCard(
              icon: Icons.people_outline,
              label:
              l10n?.translate('clients') ??
                  'Clients',
              value:
              '${metrics.clientCount}',
            ),

            _MetricCard(
              icon:
              Icons.pending_actions_outlined,
              label:
              l10n?.translate('tasks') ??
                  'Tasks',
              value:
              '${metrics.taskCount}',
            ),

            _MetricCard(
              icon:
              Icons.check_circle_outline,
              label:
              l10n?.translate('completed_tasks') ??
                  'Completed',
              value:
              '${metrics.completedTasks}',
              accent: Colors.green,
            ),

            _MetricCard(
              icon: Icons.timer_outlined,
              label:
              l10n?.translate('tracked_time') ??
                  'Tracked Time',
              value:
              _formatDuration(
                metrics.totalDuration,
              ),
            ),

            _MetricCard(
              icon: Icons.hourglass_full_rounded,
              label: l10n?.translate('actual_occupancy') ?? 'Actual Occupancy',
              value: _formatDuration(
                metrics.actualOccupancy,
              ),
              accent: Colors.blueAccent,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MAIN GRID
  // ============================================================

  Widget _buildMainGrid(
      _ReportMetrics metrics,
      ) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < 900;

        if (isCompact) {
          return Column(
            children: [
              _SectionCard(
                title:
                l10n?.translate(
                  'client_onboarding_status',
                ) ??
                    'Client Status',
                icon:
                Icons.track_changes_outlined,
                child:
                _ClientStatusRows(
                  metrics: metrics,
                ),
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title:
                l10n?.translate(
                  'task_overview',
                ) ??
                    'Task Overview',
                icon:
                Icons.task_alt_outlined,
                child:
                _TaskOverview(
                  metrics: metrics,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SectionCard(
                title:
                l10n?.translate(
                  'client_onboarding_status',
                ) ??
                    'Client Status',
                icon:
                Icons.track_changes_outlined,
                child:
                _ClientStatusRows(
                  metrics: metrics,
                ),
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: _SectionCard(
                title:
                l10n?.translate(
                  'task_overview',
                ) ??
                    'Task Overview',
                icon:
                Icons.task_alt_outlined,
                child:
                _TaskOverview(
                  metrics: metrics,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // TASK PERFORMANCE
  // ============================================================

  Widget _buildTaskPerformance(
      List<OnboardingTaskModel> tasks,
      ) {
    final l10n = AppLocalizations.of(context);

    final byType =
    <String, List<OnboardingTaskModel>>{};

    for (final task in tasks) {
      byType
          .putIfAbsent(
        task.taskType,
            () => [],
      )
          .add(task);
    }

    final sorted =
    byType.entries.toList()
      ..sort(
            (a, b) => b.value.length.compareTo(
          a.value.length,
        ),
      );

    return _SectionCard(
      title:
      l10n?.translate('task_performance') ??
          'Performance',
      icon: Icons.bar_chart_outlined,
      child: sorted.isEmpty
          ? _InlineEmpty(
        text:
        l10n?.translate('no_data') ??
            'No data.',
      )
          : Column(
        children: sorted.map((entry) {
          final completed =
              entry.value
                  .where(_isFinished)
                  .length;

          final percentage =
          entry.value.isEmpty
              ? 0.0
              : completed /
              entry.value.length;

          return Padding(
            padding:
            const EdgeInsets.only(
              bottom: 16,
            ),
            child: _TaskPerformanceRow(
              type: entry.key,
              total: entry.value.length,
              completed: completed,
              percentage: percentage,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // CLIENT STATUS BREAKDOWN
  // ============================================================

  Widget _buildClientStatusBreakdown(
      List<ClientModel> clients,
      ) {
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      title:
      l10n?.translate(
        'onboarding_stage_breakdown',
      ) ??
          'Stage Breakdown',
      icon: Icons.layers_outlined,
      child: Column(
        children: [
          _StageStatusRow(
            label:
            l10n?.translate('activation') ??
                'Activation',
            icon:
            Icons.power_settings_new_outlined,
            statuses: _countStatus(
              clients,
                  (client) =>
              client.activationStatus,
            ),
          ),

          const Divider(height: 24),

          _StageStatusRow(
            label:
            l10n?.translate('verification') ??
                'Verification',
            icon:
            Icons.verified_outlined,
            statuses: _countStatus(
              clients,
                  (client) =>
              client.verificationStatus,
            ),
          ),

          const Divider(height: 24),

          _StageStatusRow(
            label:
            l10n?.translate('chatbot') ??
                'Chatbot',
            icon:
            Icons.smart_toy_outlined,
            statuses: _countStatus(
              clients,
                  (client) =>
              client.chatbotStatus,
            ),
          ),

          const Divider(height: 24),

          _StageStatusRow(
            label:
            l10n?.translate('group') ??
                'Group',
            icon:
            Icons.groups_outlined,
            statuses: _countStatus(
              clients,
                  (client) =>
              client.groupStatus,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CLIENT PROGRESS
  // ============================================================

  Widget _buildClientProgress(
      List<ClientModel> clients,
      ) {
    final l10n = AppLocalizations.of(context);

    final sorted = [...clients]
      ..sort(
            (a, b) => _clientProgress(b).compareTo(
          _clientProgress(a),
        ),
      );

    final visible =
    sorted.take(10).toList();

    return _SectionCard(
      title:
      l10n?.translate('client_progress') ??
          'Client Progress',
      icon: Icons.insights_outlined,
      child: visible.isEmpty
          ? _InlineEmpty(
        text:
        l10n?.translate('no_clients') ??
            'No clients.',
      )
          : Column(
        children: visible
            .map(
              (client) =>
              _ClientProgressRow(
                client: client,
              ),
        )
            .toList(),
      ),
    );
  }

  // ============================================================
  // TASK DETAILS
  // ============================================================

  Widget _buildTaskDetails(
      List<OnboardingTaskModel> tasks,
      ) {
    final l10n = AppLocalizations.of(context);

    final grouped =
    <DateTime,
        List<OnboardingTaskModel>>{};

    for (final task in tasks) {
      final date = _dateOnly(
        _taskDate(task) ??
            DateTime(0),
      );

      grouped
          .putIfAbsent(
        date,
            () => [],
      )
          .add(task);
    }

    final sortedDates =
    grouped.keys.toList()
      ..sort(
            (a, b) => b.compareTo(a),
      );

    return _SectionCard(
      title:
      l10n?.translate('task_activity') ??
          'Activity',
      icon: Icons.list_alt_outlined,
      child: sortedDates.isEmpty
          ? _InlineEmpty(
        text:
        l10n?.translate('no_tasks') ??
            'No tasks.',
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: sortedDates.map((date) {
          final dayTasks =
          grouped[date]!
            ..sort(
                  (a, b) =>
                  (_taskDate(b) ??
                      DateTime(0))
                      .compareTo(
                    _taskDate(a) ??
                        DateTime(0),
                  ),
            );

          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildDayHeader(
                date,
                l10n,
              ),

              ...dayTasks.map(
                    (task) =>
                    _TaskDetailRow(
                      task: task,
                    ),
              ),

              const SizedBox(
                height: 12,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // DAY HEADER
  // ============================================================

  Widget _buildDayHeader(
      DateTime date,
      AppLocalizations? l10n,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
              theme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius:
              BorderRadius.circular(8),
            ),
            child: Text(
              _formatFullDate(
                date,
                l10n,
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                FontWeight.bold,
                color:
                theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Divider(
              color: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = _dateOnly(picked);

      if (!_rangeMode ||
          _endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = _dateOnly(picked);
    });
  }

  // ============================================================
  // PREVIOUS / NEXT PERIOD
  // ============================================================

  void _movePrevious() {
    setState(() {
      final days = _rangeMode
          ? _endDate
          .difference(_startDate)
          .inDays +
          1
          : 1;

      _startDate = _startDate.subtract(
        Duration(days: days),
      );

      _endDate = _endDate.subtract(
        Duration(days: days),
      );
    });
  }

  void _moveNext() {
    setState(() {
      final days = _rangeMode
          ? _endDate
          .difference(_startDate)
          .inDays +
          1
          : 1;

      _startDate = _startDate.add(
        Duration(days: days),
      );

      _endDate = _endDate.add(
        Duration(days: days),
      );
    });
  }

  // ============================================================
  // FILTERS
  // ============================================================

  bool _taskMatchesDate(
      OnboardingTaskModel task,
      ) {
    final date = _dateOnly(
      _taskDate(task) ??
          DateTime(0),
    );

    return !date.isBefore(_startDate) &&
        !date.isAfter(_endDate);
  }

  bool _taskMatchesType(
      OnboardingTaskModel task,
      ) {
    return _taskTypeFilter == 'All' ||
        task.taskType.trim() ==
            _taskTypeFilter;
  }

  bool _clientMatchesStatus(
      ClientModel client,
      ) {
    if (_clientStatusFilter == 'All') {
      return true;
    }

    final statuses = [
      client.activationStatus,
      client.verificationStatus,
      client.chatbotStatus,
      client.groupStatus,
    ];

    return statuses.any(
          (status) =>
      _normalizeStatus(status) ==
          _normalizeStatus(
            _clientStatusFilter,
          ),
    );
  }

  // ============================================================
  // IMPORTANT:
  // THE AGENT MAP ONLY CONTAINS ONBOARDING AGENTS
  // BECAUSE watchAgents(role: 'onboarding_agent')
  // IS USED ABOVE.
  // ============================================================

  bool _taskMatchesAgent(
      OnboardingTaskModel task,
      Map<String, String> agents,
      ) {
    if (_agentFilter == 'All') {
      return true;
    }

    return agents[task.assignedTo] ==
        _agentFilter;
  }

  bool _clientMatchesAgent(
      ClientModel client,
      Map<String, String> agents,
      ) {
    if (_agentFilter == 'All') {
      return true;
    }

    return agents[client.assignedTo] ==
        _agentFilter;
  }

  // ============================================================
  // RESET
  // ============================================================

  void _resetFilters() {
    setState(() {
      _taskTypeFilter = 'All';
      _clientStatusFilter = 'All';
      _agentFilter = 'All';

      _startDate = _dateOnly(
        DateTime.now(),
      );

      _endDate = _startDate;

      _rangeMode = false;
    });
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  String _formatFullDate(
      DateTime date,
      AppLocalizations? l10n,
      ) {
    final today = _dateOnly(
      DateTime.now(),
    );

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    if (date == today) {
      return l10n?.translate('today') ??
          'Today';
    }

    if (date == yesterday) {
      return l10n?.translate('yesterday') ??
          'Yesterday';
    }

    final months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];

    final monthKey =
    months[date.month - 1];

    return '${date.day} '
        '${l10n?.translate(monthKey) ?? monthKey.toUpperCase()} '
        '${date.year}';
  }
}

// ================================================================
// REPORT METRICS
// ================================================================

class _ReportMetrics {
  final int clientCount;
  final int taskCount;
  final int completedTasks;

  final int notStarted;
  final int inProgress;
  final int pending;
  final int activated;

  final Duration totalDuration;
  final Duration actualOccupancy;

  const _ReportMetrics({
    required this.clientCount,
    required this.taskCount,
    required this.completedTasks,
    required this.totalDuration,
    required this.actualOccupancy,
    required this.notStarted,
    required this.inProgress,
    required this.pending,
    required this.activated,
  });

  factory _ReportMetrics.fromData({
    required List<ClientModel> clients,
    required List<OnboardingTaskModel> tasks,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    var notStarted = 0;
    var inProgress = 0;
    var pending = 0;
    var activated = 0;

    var completedTasks = 0;

    var totalDuration =
        Duration.zero;

    List<_Interval> intervals = [];

    for (final client in clients) {
      final statuses = [
        client.activationStatus,
        client.verificationStatus,
        client.chatbotStatus,
        client.groupStatus,
      ];

      for (final status in statuses) {
        switch (_normalizeStatus(status)) {
          case 'not started':
            notStarted++;
            break;

          case 'in progress':
            inProgress++;
            break;

          case 'pending':
            pending++;
            break;

          case 'activated':
          case 'completed':
            activated++;
            break;
        }
      }
    }

    for (final task in tasks) {
      if (_isFinished(task)) {
        completedTasks++;

        if (task.completedDuration !=
            null) {
          totalDuration +=
          task.completedDuration!;
        }
      }

      final start = task.startedAt ?? task.createdAt;
      DateTime? end;

      if (_isFinished(task)) {
        end = task.finishedAt;
      } else if (task.isActive) {
        end = DateTime.now();
      }

      if (start != null && end != null) {
        intervals.add(_Interval(start, end));
      }
    }

    final actualOcc = _calculateActualOccupancy(intervals);

    return _ReportMetrics(
      clientCount: clients.length,
      taskCount: tasks.length,
      completedTasks: completedTasks,
      totalDuration: totalDuration,
      actualOccupancy: actualOcc,
      notStarted: notStarted,
      inProgress: inProgress,
      pending: pending,
      activated: activated,
    );
  }

  static Duration _calculateActualOccupancy(List<_Interval> intervals) {
    if (intervals.isEmpty) return Duration.zero;

    // 1. Sort by start time
    intervals.sort((a, b) => a.start.compareTo(b.start));

    List<_Interval> merged = [];
    _Interval current = intervals.first;

    for (int i = 1; i < intervals.length; i++) {
      _Interval next = intervals[i];
      if (next.start.isBefore(current.end)) {
        // Overlap!
        if (next.end.isAfter(current.end)) {
          current = _Interval(current.start, next.end);
        }
      } else {
        // No overlap
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    Duration total = Duration.zero;
    for (var interval in merged) {
      final diff = interval.end.difference(interval.start);
      if (!diff.isNegative) {
        total += diff;
      }
    }
    return total;
  }
}

class _Interval {
  final DateTime start;
  final DateTime end;
  _Interval(this.start, this.end);
}

// ================================================================
// METRIC CARD
// ================================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = kReportsBrandColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(
                  alpha: 0.1,
                ),
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                icon,
                color: accent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),

                  Text(
                    value,
                    style:
                    const TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
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

// ================================================================
// SECTION CARD
// ================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color:
                  theme.colorScheme.primary,
                ),

                const SizedBox(width: 8),

                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            child,
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DATE RANGE BADGE
// ================================================================

class _DateRangeBadge
    extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _DateRangeBadge({
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final same =
        _dateOnly(startDate) ==
            _dateOnly(endDate);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surface,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            Icons.date_range_outlined,
            size: 16,
            color:
            theme.colorScheme.primary,
          ),

          const SizedBox(width: 7),

          Text(
            same
                ? _formatDate(startDate)
                : '${_formatDate(startDate)} → ${_formatDate(endDate)}',
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FILTER DROPDOWN
// ================================================================

class _FilterDropdown
    extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            10,
          ),
        ),
      ),
      items: values
          .map(
            (item) =>
            DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
      )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

// ================================================================
// CLIENT STATUS ROWS
// ================================================================

class _ClientStatusRows
    extends StatelessWidget {
  final _ReportMetrics metrics;

  const _ClientStatusRows({
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final l10n =
    AppLocalizations.of(context);

    return Column(
      children: [
        _StatusCountRow(
          label:
          l10n?.translate(
            'not_started_status',
          ) ??
              'Not Started',
          count: metrics.notStarted,
          color: Colors.grey,
        ),

        const SizedBox(height: 12),

        _StatusCountRow(
          label:
          l10n?.translate(
            'in_progress_status',
          ) ??
              'In Progress',
          count: metrics.inProgress,
          color: Colors.blue,
        ),

        const SizedBox(height: 12),

        _StatusCountRow(
          label:
          l10n?.translate(
            'pending',
          ) ??
              'Pending',
          count: metrics.pending,
          color: Colors.orange,
        ),

        const SizedBox(height: 12),

        _StatusCountRow(
          label:
          '${l10n?.translate('completed') ?? 'Completed'} / '
              '${l10n?.translate('activated') ?? 'Activated'}',
          count: metrics.activated,
          color: Colors.green,
        ),
      ],
    );
  }
}

// ================================================================
// STATUS COUNT ROW
// ================================================================

class _StatusCountRow
    extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusCountRow({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration:
          BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            label,
            style:
            const TextStyle(
              fontSize: 13,
            ),
          ),
        ),

        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight:
            FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TASK OVERVIEW
// ================================================================

class _TaskOverview
    extends StatelessWidget {
  final _ReportMetrics metrics;

  const _TaskOverview({
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final l10n =
    AppLocalizations.of(context);

    final total =
        metrics.taskCount;

    final percentage =
    total == 0
        ? 0.0
        : metrics.completedTasks /
        total;

    final theme =
    Theme.of(context);

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${metrics.completedTasks}',
              style:
              const TextStyle(
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(width: 7),

            Text(
              l10n?.translate(
                'of_total_completed',
                params: {
                  'total':
                  total.toString(),
                },
              ) ??
                  'of $total completed',
              style: TextStyle(
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            10,
          ),
          child:
          LinearProgressIndicator(
            value: percentage,
            minHeight: 9,
            backgroundColor:
            theme
                .colorScheme
                .primary
                .withValues(
              alpha: 0.1,
            ),
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          l10n?.translate(
            'completion_rate',
            params: {
              'rate':
              (percentage * 100)
                  .toStringAsFixed(
                1,
              ),
            },
          ) ??
              '${(percentage * 100).toStringAsFixed(1)}% rate',
          style: TextStyle(
            fontSize: 12,
            color: theme
                .colorScheme
                .onSurface
                .withValues(
              alpha: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TASK PERFORMANCE ROW
// ================================================================

class _TaskPerformanceRow
    extends StatelessWidget {
  final String type;
  final int total;
  final int completed;
  final double percentage;

  const _TaskPerformanceRow({
    required this.type,
    required this.total,
    required this.completed,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            type,
            style:
            const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.bold,
            ),
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
          ),
        ),

        Expanded(
          child:
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              8,
            ),
            child:
            LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor:
              theme
                  .colorScheme
                  .primary
                  .withValues(
                alpha: 0.1,
              ),
              color:
              theme.colorScheme.primary,
            ),
          ),
        ),

        const SizedBox(width: 14),

        SizedBox(
          width: 90,
          child: Text(
            '$completed / $total',
            textAlign:
            TextAlign.right,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// STAGE STATUS ROW
// ================================================================

class _StageStatusRow
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final Map<String, int> statuses;

  const _StageStatusRow({
    required this.label,
    required this.icon,
    required this.statuses,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    final entries =
    statuses.entries.toList()
      ..sort(
            (a, b) => b.value.compareTo(
          a.value,
        ),
      );

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
          BoxDecoration(
            color: theme
                .colorScheme
                .primary
                .withValues(
              alpha: 0.1,
            ),
            borderRadius:
            BorderRadius.circular(
              9,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color:
            theme.colorScheme.primary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                const TextStyle(
                  fontSize: 13,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 7,
                runSpacing: 7,
                children:
                entries.map(
                      (entry) {
                    final l =
                    AppLocalizations
                        .of(context);

                    return _SmallStatusChip(
                      label:
                      '${l?.translateStatus(entry.key) ?? entry.key}: ${entry.value}',
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// CLIENT PROGRESS ROW
// ================================================================

class _ClientProgressRow
    extends StatelessWidget {
  final ClientModel client;

  const _ClientProgressRow({
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    final progress =
    _clientProgress(client);

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 14,
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                    BoxDecoration(
                      color: theme
                          .colorScheme
                          .primary
                          .withValues(
                        alpha: 0.1,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        9,
                      ),
                    ),
                    child: Icon(
                      Icons.business_outlined,
                      size: 19,
                      color:
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.companyName
                              .isEmpty
                              ? client.accNumber
                              : client.companyName,
                          style:
                          const TextStyle(
                            fontSize: 13,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ACC: ${client.accNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme
                                .colorScheme
                                .onSurface
                                .withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).round()}%',
                    style:
                    const TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  8,
                ),
                child:
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor:
                  theme
                      .colorScheme
                      .primary
                      .withValues(
                    alpha: 0.1,
                  ),
                  color: progress >= 1
                      ? Colors.green
                      : theme
                      .colorScheme
                      .primary,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withValues(
                  alpha: 0.1,
                ),
                borderRadius:
                BorderRadius.circular(
                  9,
                ),
              ),
              child: Icon(
                Icons.business_outlined,
                size: 19,
                color:
                theme.colorScheme.primary,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    client.companyName
                        .isEmpty
                        ? client.accNumber
                        : client.companyName,
                    style:
                    const TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    'ACC: ${client.accNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              width: 160,
              child:
              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  8,
                ),
                child:
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor:
                  theme
                      .colorScheme
                      .primary
                      .withValues(
                    alpha: 0.1,
                  ),
                  color: progress >= 1
                      ? Colors.green
                      : theme
                      .colorScheme
                      .primary,
                ),
              ),
            ),

            const SizedBox(width: 12),

            SizedBox(
              width: 45,
              child: Text(
                '${(progress * 100).round()}%',
                textAlign:
                TextAlign.right,
                style:
                const TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ================================================================
// TASK DETAIL ROW
// ================================================================

class _TaskDetailRow
    extends StatelessWidget {
  final OnboardingTaskModel task;

  const _TaskDetailRow({
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final l10n =
    AppLocalizations.of(context);

    final theme =
    Theme.of(context);

    final finished =
    _isFinished(task);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 12,
      ),
      decoration:
      BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
            theme.dividerColor,
          ),
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    finished
                        ? Icons.check_circle
                        : Icons.radio_button_checked,
                    size: 20,
                    color: finished
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.task,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _taskContext(task, context),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 32),
                  _SmallStatusChip(
                    label: l10n?.translate(
                      task.taskType.toLowerCase().replaceAll(' ', '_'),
                    ) ??
                        task.taskType,
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(task.startedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    task.completedDuration == null
                        ? '—'
                        : _formatDuration(task.completedDuration!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Icon(
              finished
                  ? Icons.check_circle
                  : Icons.radio_button_checked,
              size: 20,
              color: finished
                  ? Colors.green
                  : theme
                  .colorScheme
                  .primary,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    task.task,
                    style:
                    const TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    _taskContext(
                      task,
                      context,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _SmallStatusChip(
              label:
              l10n?.translate(
                task.taskType
                    .toLowerCase()
                    .replaceAll(
                  ' ',
                  '_',
                ),
              ) ??
                  task.taskType,
            ),

            const SizedBox(width: 12),

            Text(
              _formatTime(
                task.startedAt,
              ),
              style: TextStyle(
                fontSize: 11,
                color: theme
                    .colorScheme
                    .onSurface
                    .withValues(
                  alpha: 0.6,
                ),
              ),
            ),

            const SizedBox(width: 16),

            SizedBox(
              width: 70,
              child: Text(
                task.completedDuration ==
                    null
                    ? '—'
                    : _formatDuration(
                  task.completedDuration!,
                ),
                textAlign:
                TextAlign.right,
                style:
                const TextStyle(
                  fontSize: 11,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ================================================================
// SMALL STATUS CHIP
// ================================================================

class _SmallStatusChip
    extends StatelessWidget {
  final String label;

  const _SmallStatusChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color: theme
            .colorScheme
            .primary
            .withValues(
          alpha: 0.1,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.bold,
          color:
          theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ================================================================
// EMPTY STATE
// ================================================================

class _InlineEmpty
    extends StatelessWidget {
  final String text;

  const _InlineEmpty({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 28,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: theme
                .colorScheme
                .onSurface
                .withValues(
              alpha: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ERROR / ACCESS MESSAGE
// ================================================================

class _ReportsMessage
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  const _ReportsMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 44,
            color: isError
                ? theme
                .colorScheme
                .error
                : theme
                .colorScheme
                .onSurface
                .withValues(
              alpha: 0.4,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style:
            const TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            message,
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color: theme
                  .colorScheme
                  .onSurface
                  .withValues(
                alpha: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// HELPERS
// ================================================================

DateTime _dateOnly(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
  );
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

DateTime? _taskDate(
    OnboardingTaskModel task,
    ) {
  return task.startedAt ??
      task.createdAt;
}

String _normalizeStatus(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
}

bool _isFinished(
    OnboardingTaskModel task,
    ) {
  return _normalizeStatus(
    task.status,
  ) ==
      'finished';
}

String _formatDuration(
    Duration duration,
    ) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h '
        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
  }

  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m '
        '${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }

  return '${duration.inSeconds}s';
}

String _formatTime(
    DateTime? value,
    ) {
  if (value == null) {
    return '—';
  }

  final hour =
  value.hour % 12 == 0
      ? 12
      : value.hour % 12;

  final minute =
  value.minute
      .toString()
      .padLeft(2, '0');

  final suffix =
  value.hour >= 12
      ? 'PM'
      : 'AM';

  return '$hour:$minute $suffix';
}

String _taskContext(
    OnboardingTaskModel task,
    BuildContext context,
    ) {
  final l10n =
  AppLocalizations.of(context);

  if (task.taskType == 'Internal') {
    return task.department.isEmpty
        ? l10n?.translate(
      'internal',
    ) ??
        'Internal'
        : l10n?.translate(
      task.department
          .toLowerCase()
          .replaceAll(
        ' ',
        '_',
      ),
    ) ??
        task.department;
  }

  if (task.clientName.isNotEmpty &&
      task.accNumber.isNotEmpty) {
    return '${task.clientName} • ${task.accNumber}';
  }

  if (task.accNumber.isNotEmpty) {
    return task.accNumber;
  }

  if (task.clientName.isNotEmpty) {
    return task.clientName;
  }

  return l10n?.translate(
    'client_task',
  ) ??
      'Client task';
}

Map<String, int> _countStatus(
    List<ClientModel> clients,
    String Function(ClientModel) selector,
    ) {
  final result =
  <String, int>{};

  for (final client in clients) {
    final status =
    selector(client)
        .trim()
        .isEmpty
        ? 'Not Started'
        : selector(client).trim();

    result[status] =
        (result[status] ?? 0) + 1;
  }

  return result;
}

double _clientProgress(
    ClientModel client,
    ) {
  final statuses = [
    client.activationStatus,
    client.verificationStatus,
    client.chatbotStatus,
    client.groupStatus,
  ];

  if (statuses.isEmpty) {
    return 0;
  }

  var completed = 0;

  for (final status in statuses) {
    final normalized =
    _normalizeStatus(status);

    if (normalized == 'activated' ||
        normalized == 'completed' ||
        normalized == 'closed') {
      completed++;
    }
  }

  return completed /
      statuses.length;
}

// ================================================================
// BRAND COLOR
// ================================================================

const Color kReportsBrandColor =
Color(0xff003366);