import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/client_model.dart';
import '../../models/onboarding_tasks_model.dart';
import '../../repositories/onboarding_repository.dart';
import '../../../../../services/localization_service.dart';
import '../../../../../services/auth_service.dart';
import '../../../../../services/auth_service.dart';

class OnboardingTasks extends StatefulWidget {
  const OnboardingTasks({super.key});

  @override
  State<OnboardingTasks> createState() => _OnboardingTasksState();
}

class _OnboardingTasksState extends State<OnboardingTasks> {
  final OnboardingRepository _repository = OnboardingRepository();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _rangeMode = false;
  bool _showAll = false;

  // UI-only anchor for a task created from this screen.
  // This prevents the elapsed timer from appearing with the Firestore
  // write/listener latency already included.
  // Reporting and persisted task duration remain unchanged.
  String? _locallyCreatedTaskId;
  DateTime? _locallyCreatedAt;

  // Keep one stable stream for the lifetime of this screen.
  late final Stream<List<OnboardingTaskModel>> _tasksStream;

  // Keep the last successful snapshot so the existing UI remains visible
  // during any transient stream reconnect.
  List<OnboardingTaskModel> _lastTasks = const [];
  bool _hasReceivedTasks = false;

  @override
  void initState() {
    super.initState();

    _startDate = _dateOnly(DateTime.now());
    _endDate = _startDate;

    _tasksStream = _repository.watchMyTasks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<List<OnboardingTaskModel>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _lastTasks = snapshot.data!;
            _hasReceivedTasks = true;
          }

          if (!_hasReceivedTasks &&
              snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError && !_hasReceivedTasks) {
            return _MessageState(
              icon: Icons.error_outline,
              title: l10n?.translate('error') ?? 'Error',
              message: '${snapshot.error}',
              isError: true,
            );
          }

          final tasks = snapshot.data ?? _lastTasks;

          final activeTasks = tasks.where((t) => t.isActive).toList();

          final visibleTasks = _showAll
              ? tasks.where((t) => !t.isActive).toList()
              : tasks.where((t) {
            if (t.isActive) return false;

            final d = _dateOnly(t.createdAt ?? DateTime.now());

            return _rangeMode
                ? (!d.isBefore(_startDate) &&
                !d.isAfter(_endDate))
                : _isSameDay(d, _startDate);
          }).toList();

          final now = DateTime.now();

          final totalToday = tasks
              .where((t) => _isSameDay(t.createdAt, now))
              .length;

          final completedToday = tasks
              .where(
                (t) =>
            t.status == 'Finished' &&
                _isSameDay(t.finishedAt, now),
          )
              .length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(l10n, theme),
                    const SizedBox(height: 24),
                    _SummaryRow(
                      totalToday: totalToday,
                      completedToday: completedToday,
                      activeTaskCount: activeTasks.length,
                    ),
                    if (activeTasks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n?.translate('active_tasks_label') ??
                            'Active Tasks',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...activeTasks.map(
                            (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ActiveTaskCard(
                            key: ValueKey(t.id),
                            task: t,
                            displayStartAt:
                            t.id == _locallyCreatedTaskId
                                ? _locallyCreatedAt
                                : null,
                            onFinish: () => _finishTask(t.id),
                            onEdit: () => _showEditTaskDialog(t),
                            onDelete: () => _deleteTask(t),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildTaskListHeader(l10n, theme),
                    const SizedBox(height: 12),
                    _buildHistoryContent(
                      visibleTasks,
                      l10n,
                      theme,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryContent(
      List<OnboardingTaskModel> tasks,
      AppLocalizations? l10n,
      ThemeData theme,
      ) {
    if (tasks.isEmpty) {
      return _EmptyTasks(showAll: _showAll);
    }

    final grouped = <DateTime, List<OnboardingTaskModel>>{};

    for (final t in tasks) {
      final d = _dateOnly(t.createdAt ?? DateTime.now());
      grouped.putIfAbsent(d, () => []).add(t);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedDates.map((d) {
        final dayTasks = grouped[d]!
          ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(d, l10n, theme),
            const SizedBox(height: 12),
            ...dayTasks.map(
                  (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(
                  task: t,
                  onEdit: () => _showEditTaskDialog(t),
                  onDelete: () => _deleteTask(t),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDateHeader(
      DateTime d,
      AppLocalizations? l10n,
      ThemeData theme,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatFullDate(d, l10n),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(color: theme.dividerColor),
        ),
      ],
    );
  }

  Widget _buildHeader(
      AppLocalizations? l10n,
      ThemeData theme,
      ) {
    final roleLabel = AuthService.isSupportAgent 
      ? (l10n?.translate('support') ?? 'Support')
      : (AuthService.isSuperAdmin ? (l10n?.translate('operations') ?? 'Operations') : (l10n?.translate('onboarding') ?? 'Onboarding'));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.translate('tasks') ?? 'Tasks',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                l10n?.translate('tasks_description', params: {'role': roleLabel}) ??
                    'Track $roleLabel workload and daily occupancy.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showCreateTaskDialog,
          icon: const Icon(Icons.add),
          label: Text(
            l10n?.translate('new_task') ?? 'New Task',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskListHeader(
      AppLocalizations? l10n,
      ThemeData theme,
      ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n?.translate('task_history') ?? 'Task History',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(
                    l10n?.translate('filter_by_date') ?? 'Filter',
                  ),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    l10n?.translate('all_history') ?? 'All',
                  ),
                ),
              ],
              selected: {_showAll},
              onSelectionChanged: (s) {
                setState(() => _showAll = s.first);
              },
            ),
          ],
        ),
        if (!_showAll) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(
                          l10n?.translate('day') ?? 'Day',
                        ),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(
                          l10n?.translate('range') ?? 'Range',
                        ),
                      ),
                    ],
                    selected: {_rangeMode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _rangeMode = s.first;

                        if (!_rangeMode) {
                          _endDate = _startDate;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: _movePrevious,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickStartDate,
                          icon: const Icon(
                            Icons.calendar_today,
                            size: 16,
                          ),
                          label: Text(
                            _formatDate(_startDate),
                          ),
                        ),
                        if (_rangeMode) ...[
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey,
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickEndDate,
                            icon: const Icon(
                              Icons.event,
                              size: 16,
                            ),
                            label: Text(
                              _formatDate(_endDate),
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: _moveNext,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickStartDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (p != null) {
      setState(() {
        _startDate = _dateOnly(p);

        if (!_rangeMode || _endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (p != null) {
      setState(() {
        _endDate = _dateOnly(p);
      });
    }
  }

  void _movePrevious() {
    setState(() {
      final d = _rangeMode
          ? _endDate.difference(_startDate).inDays + 1
          : 1;

      _startDate = _startDate.subtract(
        Duration(days: d),
      );

      _endDate = _endDate.subtract(
        Duration(days: d),
      );
    });
  }

  void _moveNext() {
    setState(() {
      final d = _rangeMode
          ? _endDate.difference(_startDate).inDays + 1
          : 1;

      _startDate = _startDate.add(
        Duration(days: d),
      );

      _endDate = _endDate.add(
        Duration(days: d),
      );
    });
  }

  Future<void> _finishTask(String id) async {
    final l = AppLocalizations.of(context);

    try {
      await _repository.finishTask(id);

      if (mounted) {
        if (_locallyCreatedTaskId == id) {
          setState(() {
            _locallyCreatedTaskId = null;
            _locallyCreatedAt = null;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l?.translate('task_finished_success') ?? 'Finished',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l?.translate('failed_finish_task') ?? 'Failed'}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEditTaskDialog(
      OnboardingTaskModel task,
      ) async {
    final l = AppLocalizations.of(context);

    final res = await showDialog<_TaskEditDraft>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return _EditTaskDialog(
          task: task,
          clientsStream: _repository.watchClients(),
        );
      },
    );

    if (res == null) return;

    try {
      await _repository.updateTask(
        taskId: task.id,
        task: res.task,
        taskType: res.taskType,
        clientId: res.client?.id,
        clientName: res.client?.companyName,
        accNumber: res.client?.accNumber,
        department: res.department,

        // Only the start timestamp is editable here.
        // finishedAt remains unchanged.
        startedAt: res.startedAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l?.translate('task_updated_success') ?? 'Task updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l?.translate('failed_update_task') ?? 'Failed to update task'}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(
      OnboardingTaskModel task,
      ) async {
    final l = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) {
        final theme = Theme.of(c);

        return AlertDialog(
          title: Text(
            l?.translate('delete_task') ?? 'Delete Task',
          ),
          content: Text(
            l?.translate('delete_task_confirmation') ??
                'Delete this task from calculated time? The activity history will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(
                l?.translate('cancel') ?? 'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: Text(
                l?.translate('delete') ?? 'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteTask(task.id);

      if (mounted) {
        if (_locallyCreatedTaskId == task.id) {
          setState(() {
            _locallyCreatedTaskId = null;
            _locallyCreatedAt = null;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l?.translate('task_deleted_success') ??
                  'Task removed from calculated time',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l?.translate('failed_delete_task') ?? 'Failed to delete task'}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showCreateTaskDialog() async {
    final l = AppLocalizations.of(context);

    final res = await showDialog<_TaskDraft>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return _CreateTaskDialog(
          clientsStream: _repository.watchClients(),
        );
      },
    );

    if (res != null) {
      final localStart = DateTime.now();

      try {
        final taskId = await _repository.createTask(
          task: res.task,
          taskType: res.taskType,
          clientId: res.client?.id,
          clientName: res.client?.companyName,
          accNumber: res.client?.accNumber,
          department: res.department,
        );

        if (mounted) {
          setState(() {
            _locallyCreatedTaskId = taskId;
            _locallyCreatedAt = localStart;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l?.translate('task_started_success') ?? 'Started',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l?.translate('failed_create_task') ?? 'Failed'}: $e',
              ),
            ),
          );
        }
      }
    }
  }
}

class _TaskDraft {
  final String task;
  final String taskType;
  final ClientModel? client;
  final String? department;

  _TaskDraft({
    required this.task,
    required this.taskType,
    this.client,
    this.department,
  });
}

class _TaskEditDraft {
  final String task;
  final String taskType;
  final ClientModel? client;
  final String? department;
  final DateTime startedAt;

  const _TaskEditDraft({
    required this.task,
    required this.taskType,
    required this.startedAt,
    this.client,
    this.department,
  });
}

class _EditTaskDialog extends StatefulWidget {
  final OnboardingTaskModel task;
  final Stream<List<ClientModel>> clientsStream;

  const _EditTaskDialog({
    required this.task,
    required this.clientsStream,
  });

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final TextEditingController _tc;

  late String _tt;

  String? _cid;
  String? _dep;

  late DateTime _startedAt;

  List<ClientModel> _currentClients = [];

  bool get _needsClient => _tt != 'Internal';

  @override
  void initState() {
    super.initState();

    _tc = TextEditingController(
      text: widget.task.task,
    );

    _tt = kTaskTypes.contains(widget.task.taskType)
        ? widget.task.taskType
        : kTaskTypes.first;

    _cid = widget.task.clientId.isEmpty
        ? null
        : widget.task.clientId;

    _dep = widget.task.department.isEmpty
        ? null
        : widget.task.department;

    _startedAt =
        widget.task.startedAt ??
            widget.task.createdAt ??
            DateTime.now();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(
        l?.translate('Edit Task') ?? 'Edit Task',
      ),
      content: SizedBox(
        width: 520,
        child: StreamBuilder<List<ClientModel>>(
          stream: widget.clientsStream,
          builder: (context, snapshot) {
            _currentClients = snapshot.data ?? [];

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tt,
                    decoration: InputDecoration(
                      labelText:
                      l?.translate('task_type') ?? 'Type',
                    ),
                    items: kTaskTypes
                        .where((t) {
                      if (AuthService.isSupportAgent) {
                        return t != 'Client Group Follow Up';
                      }
                      return true;
                    })
                        .map(
                          (t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(
                          l?.translate(
                            t
                                .toLowerCase()
                                .replaceAll(' ', '_'),
                          ) ??
                              t,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;

                      setState(() {
                        _tt = v;
                        _cid = null;
                        _dep = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tc,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                      '${l?.translate('task') ?? 'Description'} '
                          '(${l?.translate('optional') ?? 'Optional'})',
                      hintText:
                      l?.translate('what_working_on') ??
                          'Add a description if needed...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_needsClient)
                    Autocomplete<ClientModel>(
                      displayStringForOption: (cl) {
                        if (cl.companyName.isEmpty) {
                          return cl.accNumber;
                        }

                        return '${cl.companyName} — ${cl.accNumber}';
                      },
                      initialValue: TextEditingValue(
                        text: _existingClientDisplayValue(
                          _currentClients,
                        ),
                      ),
                      optionsBuilder: (textEditingValue) {
                        final query =
                        textEditingValue.text.trim().toLowerCase();

                        if (query.isEmpty) {
                          return const Iterable<ClientModel>.empty();
                        }

                        return _currentClients.where(
                              (cl) =>
                          cl.companyName
                              .toLowerCase()
                              .contains(query) ||
                              cl.accNumber
                                  .toLowerCase()
                                  .contains(query),
                        );
                      },
                      onSelected: (cl) {
                        setState(() {
                          _cid = cl.id;
                        });
                      },
                      fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                          ) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText:
                            l?.translate('client') ??
                                'Client / ACC Number',
                            hintText:
                            l?.translate('select_client') ??
                                'Search by name or ACC...',
                            suffixIcon: const Icon(
                              Icons.search,
                              size: 20,
                            ),
                          ),
                          onChanged: (value) {
                            final selectedClient =
                            _findClientById(_cid);

                            if (selectedClient == null) {
                              return;
                            }

                            final selectedDisplay =
                            _clientDisplayValue(selectedClient);

                            if (value.trim() !=
                                selectedDisplay.trim()) {
                              _cid = null;
                            }
                          },
                        );
                      },
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                      kInternalDepartments.contains(_dep)
                          ? _dep
                          : null,
                      decoration: InputDecoration(
                        labelText:
                        l?.translate('department') ??
                            'Department',
                      ),
                      items: kInternalDepartments
                          .map(
                            (d) => DropdownMenuItem<String>(
                          value: d,
                          child: Text(
                            l?.translate(
                              d
                                  .toLowerCase()
                                  .replaceAll(' ', '_'),
                            ) ??
                                d,
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _dep = v;
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        18,
      ),
      actions: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickStartedTime,
              icon: const Icon(
                Icons.access_time_outlined,
                size: 17,
              ),
              label: Text(
                '${l?.translate('Start Time') ?? 'Start Time'} '
                    '${_formatTime(_startedAt)}',
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l?.translate('cancel') ?? 'Cancel',
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              child: Text(
                l?.translate('save') ?? 'Save',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickStartedTime() async {
    final now = DateTime.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startedAt.hour,
        minute: _startedAt.minute,
      ),
    );

    if (picked == null) return;

    // Keep the existing task date internally.
    // Only the time portion is changed.
    final candidate = DateTime(
      _startedAt.year,
      _startedAt.month,
      _startedAt.day,
      picked.hour,
      picked.minute,
      0,
    );

    if (candidate.isAfter(now)) {
      _showStartTimeValidationError(
        message: 'Start time cannot be in the future.',
      );
      return;
    }

    final finishedAt = widget.task.finishedAt;

    if (finishedAt != null &&
        !candidate.isBefore(finishedAt)) {
      _showStartTimeValidationError(
        message: 'Start time must be before the task end time.',
      );
      return;
    }

    setState(() {
      _startedAt = candidate;
    });
  }

  void _showStartTimeValidationError({
    required String message,
  }) {
    final l = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l?.translate('invalid_task_start_time') ??
              message,
        ),
      ),
    );
  }

  ClientModel? _findClientById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final client in _currentClients) {
      if (client.id == id) {
        return client;
      }
    }

    return null;
  }

  String _clientDisplayValue(ClientModel client) {
    if (client.companyName.isEmpty) {
      return client.accNumber;
    }

    return '${client.companyName} — ${client.accNumber}';
  }

  String _existingClientDisplayValue(
      List<ClientModel> clients,
      ) {
    final existingClient = _findClientById(_cid);

    if (existingClient != null) {
      return _clientDisplayValue(existingClient);
    }

    if (widget.task.clientName.isNotEmpty &&
        widget.task.accNumber.isNotEmpty) {
      return '${widget.task.clientName} — '
          '${widget.task.accNumber}';
    }

    if (widget.task.accNumber.isNotEmpty) {
      return widget.task.accNumber;
    }

    return widget.task.clientName;
  }

  void _save() {
    final description = _tc.text.trim();

    // Description is intentionally optional.

    final now = DateTime.now();

    if (_startedAt.isAfter(now)) {
      _showStartTimeValidationError(
        message: 'Start time cannot be in the future.',
      );
      return;
    }

    final finishedAt = widget.task.finishedAt;

    if (finishedAt != null &&
        !_startedAt.isBefore(finishedAt)) {
      _showStartTimeValidationError(
        message: 'Start time must be before the task end time.',
      );
      return;
    }

    if (_needsClient && _cid == null) {
      return;
    }

    if (!_needsClient && _dep == null) {
      return;
    }

    ClientModel? selectedClient;

    if (_needsClient) {
      selectedClient = _findClientById(_cid);

      if (selectedClient == null) {
        return;
      }
    }

    Navigator.pop(
      context,
      _TaskEditDraft(
        task: description,
        taskType: _tt,
        client: selectedClient,
        department: _needsClient ? null : _dep,
        startedAt: _startedAt,
      ),
    );
  }
}

class _CreateTaskDialog extends StatefulWidget {
  final Stream<List<ClientModel>> clientsStream;

  const _CreateTaskDialog({
    required this.clientsStream,
  });

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _tc = TextEditingController();

  String _tt = kTaskTypes.first;

  String? _cid;
  String? _dep;

  List<ClientModel> _currentClients = [];

  bool get _needsClient => _tt != 'Internal';

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(
        l?.translate('start_new_task') ?? 'New Task',
      ),
      content: SizedBox(
        width: 520,
        child: StreamBuilder<List<ClientModel>>(
          stream: widget.clientsStream,
          builder: (c, snapshot) {
            _currentClients = snapshot.data ?? [];

            final cls = _currentClients;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _tt,
                    decoration: InputDecoration(
                      labelText:
                      l?.translate('task_type') ?? 'Type',
                    ),
                    items: kTaskTypes
                        .where((t) {
                      if (AuthService.isSupportAgent) {
                        return t != 'Client Group Follow Up';
                      }
                      return true;
                    })
                        .map(
                          (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          l?.translate(
                            t
                                .toLowerCase()
                                .replaceAll(' ', '_'),
                          ) ??
                              t,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _tt = v;
                          _cid = null;
                          _dep = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tc,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                      '${l?.translate('task') ?? 'Description'} '
                          '(${l?.translate('optional') ?? 'Optional'})',
                      hintText:
                      l?.translate('what_working_on') ??
                          'Add a description if needed...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_needsClient)
                    Autocomplete<ClientModel>(
                      displayStringForOption: (cl) {
                        if (cl.companyName.isEmpty) {
                          return cl.accNumber;
                        }

                        return '${cl.companyName} — ${cl.accNumber}';
                      },
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<ClientModel>.empty();
                        }

                        final query =
                        textEditingValue.text.toLowerCase();

                        return cls.where(
                              (cl) =>
                          cl.companyName
                              .toLowerCase()
                              .contains(query) ||
                              cl.accNumber
                                  .toLowerCase()
                                  .contains(query),
                        );
                      },
                      onSelected: (cl) {
                        setState(() {
                          _cid = cl.id;
                        });
                      },
                      fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                          ) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText:
                            l?.translate('client') ??
                                'Client / ACC Number',
                            hintText:
                            l?.translate('select_client') ??
                                'Search by name or ACC...',
                            suffixIcon: const Icon(
                              Icons.search,
                              size: 20,
                            ),
                          ),
                          validator: (v) =>
                          _needsClient && _cid == null
                              ? (l?.translate(
                            'client_required',
                          ) ??
                              'Required')
                              : null,
                        );
                      },
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _dep,
                      decoration: InputDecoration(
                        labelText:
                        l?.translate('department') ??
                            'Department',
                      ),
                      items: kInternalDepartments
                          .map(
                            (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            l?.translate(
                              d
                                  .toLowerCase()
                                  .replaceAll(' ', '_'),
                            ) ??
                                d,
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _dep = v;
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l?.translate('cancel') ?? 'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(
            l?.translate('start_task') ?? 'Start',
          ),
        ),
      ],
    );
  }

  void _save() {
    final t = _tc.text.trim();

    if (_needsClient && _cid == null) {
      return;
    }

    if (!_needsClient && _dep == null) {
      return;
    }

    ClientModel? selectedClient;

    if (_needsClient && _cid != null) {
      for (final client in _currentClients) {
        if (client.id == _cid) {
          selectedClient = client;
          break;
        }
      }
    }

    Navigator.pop(
      context,
      _TaskDraft(
        task: t,
        taskType: _tt,
        client: selectedClient,
        department: _dep,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int totalToday;
  final int completedToday;
  final int activeTaskCount;

  const _SummaryRow({
    required this.totalToday,
    required this.completedToday,
    required this.activeTaskCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final items = [
          _SummaryCard(
            icon: Icons.today_outlined,
            label: l?.translate('tasks_today') ?? 'Tasks Today',
            value: '$totalToday',
          ),
          _SummaryCard(
            icon: Icons.check_circle_outline,
            label: l?.translate('completed_today') ?? 'Completed',
            value: '$completedToday',
          ),
          _SummaryCard(
            icon: Icons.layers_outlined,
            label:
            l?.translate('active_tasks_label') ?? 'Active',
            value: '$activeTaskCount',
          ),
        ];

        if (isCompact) {
          return Column(
            children: items
                .map(
                  (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: i,
              ),
            )
                .toList(),
          );
        }

        return Row(
          children: items
              .map(
                (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: i,
              ),
            ),
          )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary
                    .withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
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

class _ActiveTaskCard extends StatefulWidget {
  final OnboardingTaskModel task;
  final DateTime? displayStartAt;
  final VoidCallback onFinish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActiveTaskCard({
    super.key,
    required this.task,
    required this.displayStartAt,
    required this.onFinish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ActiveTaskCard> createState() => _ActiveTaskCardState();
}

class _ActiveTaskCardState extends State<_ActiveTaskCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final displayStart =
        widget.displayStartAt ?? widget.task.startedAt;

    final elapsed = displayStart == null
        ? Duration.zero
        : DateTime.now().difference(displayStart);

    final safeElapsed =
    elapsed.isNegative ? Duration.zero : elapsed;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: .3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: .1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l?.translate('running') ??
                                      'RUNNING',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                    theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _TypeChip(
                                  label: l?.translate(
                                    widget.task.taskType
                                        .toLowerCase()
                                        .replaceAll(' ', '_'),
                                  ) ??
                                      widget.task.taskType,
                                ),
                              ],
                            ),
                            if (widget.task.task.trim().isNotEmpty)
                              Text(
                                widget.task.task,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDuration(safeElapsed),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            l?.translate('elapsed') ?? 'Elapsed',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip:
                            l?.translate('edit') ?? 'Edit',
                            onPressed: widget.onEdit,
                            icon: const Icon(
                              Icons.edit_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip:
                            l?.translate('delete') ?? 'Delete',
                            onPressed: widget.onDelete,
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: widget.onFinish,
                            child: Text(
                              l?.translate('finish') ?? 'Finish',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l?.translate('running') ?? 'RUNNING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: l?.translate(
                              widget.task.taskType
                                  .toLowerCase()
                                  .replaceAll(' ', '_'),
                            ) ??
                                widget.task.taskType,
                          ),
                        ],
                      ),
                      if (widget.task.task.trim().isNotEmpty)
                        Text(
                          widget.task.task,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        _taskContext(widget.task, context),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDuration(safeElapsed),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      l?.translate('elapsed') ?? 'Elapsed',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: l?.translate('edit') ?? 'Edit',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: l?.translate('delete') ?? 'Delete',
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: widget.onFinish,
                  child: Text(
                    l?.translate('finish') ?? 'Finish',
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

class _TaskCard extends StatelessWidget {
  final OnboardingTaskModel task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final finished = task.status == 'Finished';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;

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
                        color: finished
                            ? Colors.green
                            : theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: task.task.trim().isEmpty
                            ? Text(
                          l?.translate('no_comment') ??
                              'No comment',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        )
                            : Text(
                          task.task,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 32),
                      _TypeChip(
                        label: l?.translate(
                          task.taskType
                              .toLowerCase()
                              .replaceAll(' ', '_'),
                        ) ??
                            task.taskType,
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(task.startedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        task.completedDuration == null
                            ? '—'
                            : _formatDuration(
                          task.completedDuration!,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l?.translate('edit') ?? 'Edit',
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        tooltip:
                        l?.translate('delete') ?? 'Delete',
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: theme.colorScheme.error,
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
                  color: finished
                      ? Colors.green
                      : theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      if (task.task.trim().isNotEmpty)
                        Text(
                          task.task,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (task.task.trim().isEmpty)
                        Text(
                          l?.translate('no_comment') ??
                              'No comment',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      Text(
                        _taskContext(task, context),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeChip(
                  label: l?.translate(
                    task.taskType
                        .toLowerCase()
                        .replaceAll(' ', '_'),
                  ) ??
                      task.taskType,
                ),
                const SizedBox(width: 14),
                Text(
                  _formatTime(task.startedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  task.completedDuration == null
                      ? '—'
                      : _formatDuration(
                    task.completedDuration!,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l?.translate('edit') ?? 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: l?.translate('delete') ?? 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
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

class _TypeChip extends StatelessWidget {
  final String label;

  const _TypeChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  final bool showAll;

  const _EmptyTasks({
    required this.showAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final roleLabel = AuthService.isSupportAgent 
      ? (l?.translate('support') ?? 'Support')
      : (AuthService.isSuperAdmin ? (l?.translate('operations') ?? 'Operations') : (l?.translate('onboarding') ?? 'Onboarding'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 42,
              color: Colors.grey.shade400,
            ),
            Text(
              showAll
                  ? (l?.translate('no_task_history') ??
                  'No history')
                  : (l?.translate('no_tasks_day') ??
                  'No tasks'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              l?.translate('start_task_desc', params: {'role': roleLabel}) ?? 'Start a task.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 42,
            color: isError ? Colors.red : Colors.grey,
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _taskContext(
    OnboardingTaskModel task,
    BuildContext context,
    ) {
  final l = AppLocalizations.of(context);

  if (task.taskType == 'Internal') {
    return task.department.isEmpty
        ? (l?.translate('internal') ?? 'Internal')
        : (l?.translate(
      task.department
          .toLowerCase()
          .replaceAll(' ', '_'),
    ) ??
        task.department);
  }

  if (task.clientName.isNotEmpty &&
      task.accNumber.isNotEmpty) {
    return '${task.clientName} • ${task.accNumber}';
  }

  if (task.accNumber.isNotEmpty) {
    return task.accNumber;
  }

  return task.clientName.isNotEmpty
      ? task.clientName
      : (l?.translate('client_task') ?? 'Client task');
}

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h '
        '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
  }

  if (d.inMinutes > 0) {
    return '${d.inMinutes}m '
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}s';
  }

  return '${d.inSeconds}s';
}

String _formatTime(DateTime? v) {
  if (v == null) return '—';

  final h = v.hour % 12 == 0 ? 12 : v.hour % 12;

  final m = v.minute.toString().padLeft(2, '0');

  final s = v.hour >= 12 ? 'PM' : 'AM';

  return '$h:$m $s';
}

DateTime _dateOnly(DateTime v) {
  return DateTime(v.year, v.month, v.day);
}

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

String _formatFullDate(
    DateTime d,
    AppLocalizations? l,
    ) {
  final n = _dateOnly(DateTime.now());
  final y = n.subtract(const Duration(days: 1));

  if (d == n) {
    return l?.translate('today') ?? 'Today';
  }

  if (d == y) {
    return l?.translate('yesterday') ?? 'Yesterday';
  }

  final m = [
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

  return '${d.day} ${l?.translate(m[d.month - 1]) ?? m[d.month - 1].toUpperCase()} ${d.year}';
}

bool _isSameDay(DateTime? v, DateTime d) {
  return v != null &&
      v.year == d.year &&
      v.month == d.month &&
      v.day == d.day;
}

const List<String> kTaskTypes = [
  'Activation',
  'Verification',
  'Chatbot',
  'Client Group Follow Up',
  'Internal',
  'Call',
  'Meeting',
  'Ticket',
  'Anydesk',
];

const List<String> kInternalDepartments = [
  'Business Chat',
  'Account Manager',
  'Sales',
  'VoIP',
];