import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';
import '../../widgets/client_card.dart';
import '../../../../../services/localization_service.dart';
import '../../../../../services/user_display_name_resolver.dart';
import '../../../../../services/auth_service.dart';

class OnboardingClientsScreen extends StatefulWidget {
  const OnboardingClientsScreen({super.key});

  @override
  State<OnboardingClientsScreen> createState() =>
      _OnboardingClientsScreenState();
}

class _OnboardingClientsScreenState
    extends State<OnboardingClientsScreen> {
  final OnboardingRepository _repository =
  OnboardingRepository();

  late final Stream<List<ClientModel>> _clientsStream;

  final UserDisplayNameResolver _resolver =
  UserDisplayNameResolver();

  // Full list of agents for search mapping
  final Map<String, String> _agentNames = {};
  StreamSubscription? _agentsSub;

  // Filtered list of agents for reassignment
  final Map<String, String> _onboardingAgentNames = {};

  String _search = '';
  List<ClientModel>? _displayedClients;
  List<ClientModel> _latestClients = const [];
  _ClientFilterState _filters = _ClientFilterState();

  // ===========================================================================
  // EMBEDDED OPERATION PANEL
  // ===========================================================================

  bool _operationRunning = false;
  bool _operationCancelling = false;
  bool _cancelOperationRequested = false;

  final ValueNotifier<_OperationPanelData> _operationPanel =
  ValueNotifier(const _OperationPanelData.hidden());

  @override
  void initState() {
    super.initState();

    _clientsStream = _repository.watchClients();

    // Fetch all agents and group them
    _agentsSub = _repository.watchAllAgentsByRole().listen((grouped) {
      if (!mounted) return;

      setState(() {
        _agentNames.clear();
        _onboardingAgentNames.clear();

        // 1. Full list for mapping names
        grouped.values.forEach(_agentNames.addAll);

        // 2. Onboarding agents for Reassign dropdown
        final onboarding = grouped['onboarding_agent'];
        if (onboarding != null) {
          _onboardingAgentNames.addAll(onboarding);
        }
      });
    });
  }

  @override
  void dispose() {
    _agentsSub?.cancel();
    _operationPanel.dispose();
    super.dispose();
  }

  Future<String> _resolveUserName(String uid) {
    return _resolver.resolve(uid);
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  bool get _isSuperAdmin {
    return AuthService.isSuperAdmin;
  }

  // ===========================================================================
  // OPERATION PANEL HELPERS
  // ===========================================================================

  void _startOperationPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required int total,
  }) {
    if (!mounted) return;

    _operationRunning = true;
    _operationCancelling = false;
    _cancelOperationRequested = false;

    _operationPanel.value = _OperationPanelData(
      title: title,
      processed: 0,
      total: total,
      progress: 0,
      cancelling: false,
      status: '',
      resultMessage: null,
      error: false,
      skippedRows: null,
    );

    setState(() {});
  }

  void _updateOperationProgress({
    required int processed,
    required int total,
    String? status,
  }) {
    if (!mounted) return;

    _operationPanel.value = _operationPanel.value.copyWith(
      processed: processed,
      total: total,
      progress: total == 0
          ? 1
          : (processed / total).clamp(0.0, 1.0).toDouble(),
      status: status,
    );
  }

  void _requestOperationCancel() {
    if (!_operationRunning || _operationCancelling) return;

    _cancelOperationRequested = true;
    _operationCancelling = true;

    _operationPanel.value = _operationPanel.value.copyWith(
      cancelling: true,
      status: 'Cancelling...',
    );
  }

  void _finishOperationPanel({
    required String title,
    required String message,
    bool error = false,
    List<List<String>>? skippedRows,
  }) {
    if (!mounted) return;

    _operationRunning = false;
    _operationCancelling = false;

    _operationPanel.value = _OperationPanelData(
      title: title,
      processed: _operationPanel.value.processed,
      total: _operationPanel.value.total,
      progress: 1,
      cancelling: false,
      status: '',
      resultMessage: message,
      error: error,
      skippedRows: skippedRows,
    );

    setState(() {});

    // Auto-clear notification after delay if it's just a message (not a bulk operation result)
    if (_operationPanel.value.total == 0) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _operationPanel.value.resultMessage == message) {
          _clearOperationPanel();
        }
      });
    }
  }

  void _showNotification({
    required String title,
    required String message,
    bool error = false,
  }) {
    _operationRunning = false;
    _operationPanel.value = _OperationPanelData(
      title: title,
      processed: 0,
      total: 0,
      progress: 1,
      cancelling: false,
      status: '',
      resultMessage: message,
      error: error,
    );
    setState(() {});
    
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _operationPanel.value.resultMessage == message) {
        _clearOperationPanel();
      }
    });
  }

  void _clearOperationPanel() {
    if (!mounted) return;

    _operationRunning = false;
    _operationCancelling = false;
    _cancelOperationRequested = false;
    _operationPanel.value = const _OperationPanelData.hidden();

    setState(() {});
  }

  void _showSupportActionDialog(BuildContext context) {
    final commentController = TextEditingController();
    
    ClientModel? selectedClient;
    String? selectedStatus;
    bool loading = false;
    bool isStepTwo = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StreamBuilder<List<ClientModel>>(
        stream: _clientsStream,
        initialData: _latestClients,
        builder: (context, snapshot) {
          final allClients = snapshot.data ?? [];
          
          return StatefulBuilder(
            builder: (context, setS) {
              final theme = Theme.of(context);
              final colors = theme.colorScheme;
              final l10n = AppLocalizations.of(context);

              Future<void> submit() async {
                if (selectedClient == null || selectedStatus == null) return;
                setS(() => loading = true);
                try {
                  final oldStatus = selectedClient!.verificationStatus;
                  final comment = commentController.text.trim();
                  
                  if (oldStatus != selectedStatus) {
                    await _repository.updateStatuses(
                      clientId: selectedClient!.id, 
                      verificationStatus: selectedStatus
                    );
                    await _repository.logStatusChange(
                      clientId: selectedClient!.id, 
                      type: 'verification', 
                      field: 'verificationStatus', 
                      oldValue: oldStatus, 
                      newValue: selectedStatus!
                    );
                    
                    // Sync with Zoho CRM
                    try {
                      await _repository.updateVerificationStatusInZoho(
                        accountNumber: selectedClient!.accNumber,
                        verificationStatus: selectedStatus!,
                      );
                    } catch (zohoError) {
                      debugPrint('Zoho Sync Failed: $zohoError');
                    }
                  }
                  
                  if (comment.isNotEmpty) {
                    await _repository.updateCrmComment(selectedClient!.id, comment);
                  }
                  
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client updated successfully.'))
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  setS(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Update failed: $e'))
                  );
                }
              }

              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: colors.primary),
                    const SizedBox(width: 12),
                    const Text('Support Action'),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: !isStepTwo 
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Search and select a client to update.', 
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 20),
                          Autocomplete<ClientModel>(
                            displayStringForOption: (c) {
                              if (c.companyName.isEmpty) {
                                return c.accNumber;
                              }
                              return '${c.companyName} — ${c.accNumber}';
                            },
                            optionsBuilder: (textValue) {
                              final query =
                              textValue.text.trim().toLowerCase();

                              if (query.isEmpty) {
                                return const Iterable<ClientModel>.empty();
                              }

                              return allClients.where((c) => 
                                c.companyName.toLowerCase().contains(query) || 
                                c.accNumber.toLowerCase().contains(query)
                              );
                            },
                            onSelected: (c) {
                              setS(() {
                                selectedClient = c;
                              });
                            },
                            fieldViewBuilder: (context, ctrl, node, onSubmitted) {
                              return TextFormField(
                                controller: ctrl,
                                focusNode: node,
                                decoration: InputDecoration(
                                  labelText: l10n?.translate('client') ?? 'Client / ACC Number',
                                  hintText: l10n?.translate('select_client') ?? 'Search by name or ACC...',
                                  suffixIcon: const Icon(Icons.search, size: 20),
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  if (selectedClient == null) return;
                                  final display = selectedClient!.companyName.isEmpty 
                                    ? selectedClient!.accNumber 
                                    : '${selectedClient!.companyName} — ${selectedClient!.accNumber}';
                                  if (value.trim() != display.trim()) {
                                    setS(() {
                                      selectedClient = null;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                          if (selectedClient == null) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 10),
                            const Text("Can't find the client?", 
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showCreateClientDialog();
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create New Client'),
                            ),
                          ]
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.business_outlined, color: colors.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(selectedClient!.companyName, 
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('ACC: ${selectedClient!.accNumber}', 
                                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Verification Status',
                              border: OutlineInputBorder(),
                            ),
                            items: ['Not Started', 'In Progress', 'Pending', 'Approved', 'Rejected', 'Verified', 'With Support']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setS(() => selectedStatus = v),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: commentController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'CRM Comment',
                              hintText: 'Write a comment to send to CRM...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                ),
                actions: [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(dialogContext), 
                    child: const Text('Cancel')
                  ),
                  if (!isStepTwo)
                    ElevatedButton(
                      onPressed: selectedClient == null ? null : () {
                        setS(() {
                          isStepTwo = true;
                          final allowed = ['Not Started', 'In Progress', 'Pending', 'Approved', 'Rejected', 'Verified', 'With Support'];
                          final current = selectedClient!.verificationStatus.trim();
                          selectedStatus = allowed.firstWhere(
                            (s) => s.toLowerCase() == current.toLowerCase(),
                            orElse: () => allowed.first,
                          );
                        });
                      },
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: loading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Updates'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _downloadSkippedCsv(List<List<String>> rows) {
    String csvContent = rows.map((row) {
      return row.map((field) {
        String escapedField = field.replaceAll('"', '""');
        return '"$escapedField"';
      }).join(',');
    }).join('\n');

    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'skipped_clients.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _buildOperationPanel() {
    return ValueListenableBuilder<_OperationPanelData>(
      valueListenable: _operationPanel,
      builder: (context, data, _) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final result = !_operationRunning && data.resultMessage != null;
        final accent = data.error ? colors.error : (data.progress >= 1.0 ? Colors.green : colors.primary);

        final isDelete = data.title.toLowerCase().contains('delete');
        final headerIcon = isDelete ? Icons.delete_sweep_rounded : Icons.cloud_upload_rounded;

        if (!_operationRunning && !result) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xff1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
                border: Border.all(color: data.error ? colors.error.withValues(alpha: 0.3) : theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_operationRunning) LinearProgressIndicator(value: data.progress, minHeight: 4, backgroundColor: accent.withValues(alpha: 0.1), color: accent),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(result ? (data.error ? Icons.error_outline : Icons.check_circle_outline) : headerIcon, color: accent, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(data.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (result)
                                  Text(data.resultMessage!, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.7)))
                                else
                                  Text(data.status.isNotEmpty ? data.status : 'Processing ${data.processed} of ${data.total}...', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                          if (_operationRunning && !data.cancelling)
                            IconButton(onPressed: _requestOperationCancel, icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 22), tooltip: 'Stop Operation'),
                          if (result && data.skippedRows != null && data.skippedRows!.isNotEmpty)
                            IconButton(onPressed: () => _downloadSkippedCsv(data.skippedRows!), icon: Icon(Icons.download_for_offline_outlined, color: colors.primary, size: 22), tooltip: 'Download Skipped'),
                          if (result)
                            IconButton(onPressed: _clearOperationPanel, icon: Icon(Icons.close_rounded, size: 20, color: colors.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final l10n =
    AppLocalizations.of(
      context,
    );

    final theme =
    Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor:
        theme.colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(
              AuthService.isSupportAgent 
                ? (l10n?.translate('Support Clients') ?? 'Support Clients')
                : (l10n?.translate('clients') ?? 'Clients'),
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              width: 12,
            ),

            // ACCOUNT COUNTER
            StreamBuilder<List<ClientModel>>(
              stream: _clientsStream,
              builder: (context, snapshot) {
                final allClients = snapshot.data ?? [];
                var clients = allClients;
                if (AuthService.isSupportAgent) {
                  clients = allClients.where((c) => _normalize(c.groupStatus) == 'closed').toList();
                }
                final filteredCount = _applyClientFilters(clients).length;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$filteredCount accounts',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          // =====================================================================
          // SUPPORT ACTION
          // =====================================================================

          if (AuthService.isSupportAgent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showSupportActionDialog(context),
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Support Action'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),

          // =====================================================================
          // BULK DELETE
          // =====================================================================

          if (_isSuperAdmin)
            StreamBuilder<
                List<ClientModel>>(
              stream: _clientsStream,
              builder:
                  (
                  context,
                  snapshot,
                  ) {
                final clients =
                    snapshot
                        .data ??
                        [];

                if (clients
                    .isEmpty) {
                  return const SizedBox
                      .shrink();
                }

                return Padding(
                  padding:
                  const EdgeInsets
                      .only(
                    right: 8,
                  ),
                  child:
                  TextButton
                      .icon(
                    onPressed:
                        () =>
                        _bulkDeleteAll(
                          clients,
                        ),
                    icon:
                    const Icon(
                      Icons
                          .delete_sweep,
                      color: Colors
                          .redAccent,
                      size: 20,
                    ),
                    label:
                    const Text(
                      'Bulk Delete',
                      style:
                      TextStyle(
                        color: Colors
                            .redAccent,
                      ),
                    ),
                  ),
                );
              },
            ),

          // =====================================================================
          // IMPORT
          // =====================================================================

          if (_isSuperAdmin)
            Padding(
              padding:
              const EdgeInsets
                  .only(
                right: 8,
              ),
              child:
              OutlinedButton
                  .icon(
                onPressed:
                _showImportDialog,
                icon:
                const Icon(
                  Icons.upload_file,
                  size: 18,
                ),
                label:
                const Text(
                  'Import',
                ),
                style:
                OutlinedButton
                    .styleFrom(
                  side: BorderSide(
                    color: theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha:
                      0.5,
                    ),
                  ),
                  foregroundColor:
                  theme
                      .colorScheme
                      .primary,
                ),
              ),
            ),

          // =====================================================================
          // CREATE CLIENT
          // =====================================================================

          if (!AuthService.isSupportAgent)
            Padding(
              padding:
              const EdgeInsets
                  .only(
                right: 16,
              ),
              child:
              ElevatedButton
                  .icon(
                onPressed:
                _showCreateClientDialog,
                icon:
                const Icon(
                  Icons.add,
                ),
                label:
                Text(
                  l10n?.translate(
                    'new_client',
                  ) ??
                      'New Client',
                ),
                style:
                ElevatedButton
                    .styleFrom(
                  backgroundColor:
                  theme
                      .colorScheme
                      .primary,
                  foregroundColor:
                  theme
                      .colorScheme
                      .onPrimary,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildSearch(
                  l10n,
                  theme,
                ),
                const SizedBox(
                  height: 20,
                ),
                Expanded(
                  child: StreamBuilder<
                      List<ClientModel>>(
                    stream: _clientsStream,
                    builder:
                        (
                        context,
                        snapshot,
                        ) {
                      if (snapshot
                          .connectionState ==
                          ConnectionState
                              .waiting) {
                        return Center(
                          child:
                          CircularProgressIndicator(
                            color: theme
                                .colorScheme
                                .primary,
                          ),
                        );
                      }

                      if (snapshot
                          .hasError) {
                        return const Center(
                          child: Text(
                            'Error loading clients.',
                          ),
                        );
                      }

                      final streamedClients =
                          snapshot.data ??
                              [];

                      _latestClients = streamedClients;

                      if (!_operationRunning) {
                        _displayedClients = streamedClients;
                      }

                      var clients = _operationRunning
                          ? (_displayedClients ?? streamedClients)
                          : streamedClients;

                      if (AuthService.isSupportAgent) {
                        clients = clients.where((c) => _normalize(c.groupStatus) == 'closed').toList();
                      }

                      final filtered = _applyClientFilters(clients);

                      if (filtered
                          .isEmpty) {
                        return _EmptyClients(
                          hasSearch: _search.trim().isNotEmpty ||
                              _filters.isActive,
                          onCreate:
                          _showCreateClientDialog,
                        );
                      }

                      return ListView
                          .separated(
                        padding: EdgeInsets.only(
                          bottom: _operationRunning ? 90 : 24,
                        ),
                        itemCount:
                        filtered.length,
                        separatorBuilder:
                            (
                            _,
                            __,
                            ) =>
                        const SizedBox(
                          height: 12,
                        ),
                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          final client =
                          filtered[
                          index];

                          return Row(
                            key: ValueKey(client.id),
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Expanded(
                                child:
                                ClientCard(
                                  client:
                                  client,
                                  resolveUserName:
                                  _resolveUserName,
                                  onDelete:
                                  _isSuperAdmin
                                      ? () =>
                                      _deleteClient(
                                        client,
                                      )
                                      : null,
                                ),
                              ),

                              // SUPER ADMIN REASSIGN
                              if (_isSuperAdmin) ...[
                                const SizedBox(
                                  width: 8,
                                ),
                                Tooltip(
                                  message:
                                  'Reassign Client',
                                  child:
                                  Material(
                                    color: theme
                                        .colorScheme
                                        .surface,
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      10,
                                    ),
                                    child:
                                    InkWell(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                        10,
                                      ),
                                      onTap:
                                          () =>
                                          _showReassignClientDialog(
                                            client,
                                          ),
                                      child:
                                      Container(
                                        width:
                                        44,
                                        height:
                                        44,
                                        decoration:
                                        BoxDecoration(
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                            10,
                                          ),
                                          border:
                                          Border.all(
                                            color:
                                            theme.dividerColor,
                                          ),
                                        ),
                                        child:
                                        Icon(
                                          Icons
                                              .edit_outlined,
                                          size:
                                          19,
                                          color: theme
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<_OperationPanelData>(
            valueListenable: _operationPanel,
            builder: (context, data, _) {
              if (!_operationRunning && data.resultMessage == null) {
                return const SizedBox.shrink();
              }

              return Positioned(
                left: 24,
                right: 24,
                bottom: 16,
                child: _buildOperationPanel(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DELETE SINGLE CLIENT
  // ===========================================================================

  Future<void> _deleteClient(ClientModel client) async {
    if (!_isSuperAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
          'Are you sure you want to delete ${client.companyName}? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteClient(client.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client deleted.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===========================================================================
  // BULK DELETE
  // ===========================================================================

  Future<void> _bulkDeleteAll(List<ClientModel> clients) async {
    if (!_isSuperAdmin || clients.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        return AlertDialog(
          title: const Text('Delete all clients?'),
          content: Text(
            'This will permanently delete ${clients.length} client records. '
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete all'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final ids = clients.map((client) => client.id).toList();
    final total = ids.length;

    _startOperationPanel(
      title: 'Deleting clients',
      subtitle: 'Removing client records in batches',
      icon: Icons.delete_sweep_rounded,
      total: total,
    );

    try {
      final deleted = await _repository.bulkDeleteClients(
        ids,
        isCancelled: () => _cancelOperationRequested,
        onProgress: (deletedCount, totalCount) {
          _updateOperationProgress(
            processed: deletedCount,
            total: totalCount,
            status: 'Deleting...',
          );
        },
      );

      if (!mounted) return;

      if (_cancelOperationRequested) {
        _finishOperationPanel(
          title: 'Delete cancelled',
          message:
          '$deleted of $total client records were deleted before the operation was stopped.',
        );
        return;
      }

      _finishOperationPanel(
        title: 'Delete completed',
        message:
        '$deleted client${deleted == 1 ? '' : 's'} deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _finishOperationPanel(
        title: 'Delete failed',
        message: 'Failed to delete clients. Please try again.',
        error: true,
      );
    }
  }

  // ===========================================================================
  // REASSIGN CLIENT
  // ===========================================================================

  Future<void> _showReassignClientDialog(ClientModel client) async {
    if (!_isSuperAdmin) return;

    // Use ONLY the onboarding agents list for the dropdown
    final agents = Map<String, String>.from(_onboardingAgentNames);

    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No onboarding agents are available for reassignment.'),
        ),
      );
      return;
    }

    String selectedUid = client.assignedTo;

    // If the currently assigned user is not in the filtered list, default to unassigned
    if (!agents.containsKey(selectedUid)) {
      selectedUid = '';
    }

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final sortedAgents = agents.entries.toList()
              ..sort(
                    (a, b) => a.value.toLowerCase().compareTo(
                  b.value.toLowerCase(),
                ),
              );

            return AlertDialog(
              title: const Text('Reassign Client'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.companyName.isNotEmpty
                          ? client.companyName
                          : client.accNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ACC: ${client.accNumber}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue:
                      selectedUid.isEmpty ? null : selectedUid,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assigned User',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Unassigned'),
                        ),
                        ...sortedAgents.map(
                              (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUid = value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    selectedUid,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final oldUid = client.assignedTo;
      await _repository.updateAssignedTo(client.id, result);

      if (!mounted) return;

      final oldName = _agentNames[oldUid] ?? (oldUid.isEmpty ? 'Unassigned' : oldUid);
      final assignedName = result.isEmpty
          ? 'Unassigned'
      // Check from the full list in case we re-assigned to someone else somehow
          : (_agentNames[result] ?? result);

      await _repository.addActivity(
        clientId: client.id,
        type: 'assignment',
        action: 'reassign',
        title: 'Client reassigned',
        description: 'Client was reassigned from $oldName to $assignedName.',
        metadata: {
          'oldAssigneeId': oldUid,
          'newAssigneeId': result,
          'oldAssigneeName': oldName,
          'newAssigneeName': assignedName,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${client.companyName} reassigned to $assignedName.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reassignment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Widget _buildSearch(
      AppLocalizations? l10n,
      ThemeData theme,
      ) {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
              decoration: InputDecoration(
                hintText:
                l10n?.translate('search_clients_hint') ??
                    'Search by name, ACC or assignee...',
                prefixIcon: const Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Filters',
              onPressed: _showFiltersDialog,
              icon: const Icon(Icons.tune_outlined),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_filters.activeCount > 0)
              Positioned(
                right: -2,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_filters.activeCount}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<ClientModel> _applyClientFilters(List<ClientModel> clients) {
    final q = _normalize(_search);

    return clients.where((client) {
      // Search remains an AND condition with the structured filters.
      if (q.isNotEmpty) {
        final assigneeName = _normalize(_agentNames[client.assignedTo] ?? '');
        final matchesSearch =
            _normalize(client.companyName).contains(q) ||
                _normalize(client.accNumber).contains(q) ||
                _normalize(client.assignedTo).contains(q) ||
                assigneeName.contains(q);
        if (!matchesSearch) return false;
      }

      final conditions = <bool>[];

      if (_filters.creationDateRange != null) {
        conditions.add(
          _dateInRange(client.createdAt, _filters.creationDateRange!),
        );
      }

      if (_filters.activationDateRange != null) {
        conditions.add(
          _dateInRange(client.activationDate, _filters.activationDateRange!),
        );
      }

      if (_filters.assigneeIds.isNotEmpty) {
        conditions.add(_filters.assigneeIds.contains(client.assignedTo));
      }

      if (_filters.activationStatuses.isNotEmpty) {
        conditions.add(
          _filters.activationStatuses.contains(client.activationStatus),
        );
      }

      if (_filters.verificationStatuses.isNotEmpty) {
        conditions.add(
          _filters.verificationStatuses.contains(client.verificationStatus),
        );
      }

      if (_filters.chatbotStatuses.isNotEmpty) {
        conditions.add(
          _filters.chatbotStatuses.contains(client.chatbotStatus),
        );
      }

      if (_filters.groupStatuses.isNotEmpty) {
        conditions.add(_filters.groupStatuses.contains(client.groupStatus));
      }

      if (conditions.isEmpty) return true;
      return _filters.useAnd
          ? conditions.every((value) => value)
          : conditions.any((value) => value);
    }).toList();
  }

  bool _dateInRange(DateTime? value, DateTimeRange range) {
    if (value == null) return false;
    final date = DateTime(value.year, value.month, value.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    return !date.isBefore(start) && !date.isAfter(end);
  }

  Future<void> _showFiltersDialog() async {
    final result = await showDialog<_ClientFilterState>(
      context: context,
      builder: (dialogContext) {
        return _ClientFiltersDialog(
          initial: _filters.copy(),
          clients: _latestClients,
          agentNames: _agentNames,
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _filters = result;
    });
  }

  // ===========================================================================
  // IMPORT DIALOG
  // ===========================================================================

  Future<void> _showImportDialog() async {
    if (!_isSuperAdmin) return;

    List<List<String>> csvData =
    [];

    List<String> headers = [];

    Map<String, int?> mapping =
    {};

    String fileName = '';

    bool fileLoaded = false;

    // These correspond to the actual CSV columns.
    final fields =
    <String, String>{
      'companyName':
      'Company Name',
      'accNumber':
      'ACC Number',
      'systemType':
      'System Type',
      'activationStatus':
      'Activation Status',
      'groupStatus':
      'Group Status',
      'chatbotStatus':
      'Chatbot Status',
      'verificationStatus':
      'Verification Status',
      'activationDate':
      'Activation Date',
      'groupDuration':
      'Group Duration (Days)',
      'verificationDate':
      'Verification Date',
      'verificationTicket':
      'Verification Ticket Number',
      'crmComment':
      'CRM Comment',
      'eng':
      'Assigned Agent (ENG)',
      'months':
      'Months',
      'enteredDate':
      'Entered Date',
    };

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setS,
              ) {
            void pickFile() {
              final uploadInput =
              html.FileUploadInputElement();

              uploadInput.accept =
              '.csv';

              uploadInput.click();

              uploadInput.onChange
                  .listen((_) {
                final files =
                    uploadInput.files;

                if (files == null ||
                    files.isEmpty) {
                  return;
                }

                final file =
                    files.first;

                final reader =
                html.FileReader();

                reader.onLoadEnd
                    .listen((_) {
                  final result =
                      reader.result;

                  if (result
                  is! String) {
                    return;
                  }

                  final rows =
                  _parseCsv(
                    result,
                  );

                  if (rows.isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger
                        .of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The CSV file is empty.',
                        ),
                        backgroundColor:
                        Colors.red,
                      ),
                    );

                    return;
                  }

                  final detectedHeaders =
                  rows.first
                      .map(
                    _cleanHeader,
                  )
                      .toList();

                  final detectedMapping =
                  _buildExactColumnMapping(
                    detectedHeaders,
                  );

                  setS(() {
                    csvData =
                        rows;

                    headers =
                        detectedHeaders;

                    fileName =
                        file.name;

                    fileLoaded =
                    true;

                    mapping =
                        detectedMapping;
                  });
                });

                reader.readAsText(
                  file,
                );
              });
            }

            final hasRequiredAcc =
                mapping[
                'accNumber'] !=
                    null;

            return AlertDialog(
              title:
              const Text(
                'Import Clients from CSV',
              ),
              content:
              SizedBox(
                width: 680,
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize
                      .min,
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    if (!fileLoaded) ...[
                      const Text(
                        'Select the CSV file exported from Google Sheets.',
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const Text(
                        'ACC Number is required. '
                            'Company Name will be mapped automatically '
                            'when the CSV contains a Company Name column.',
                        style:
                        TextStyle(
                          fontSize:
                          12,
                          color: Colors
                              .grey,
                        ),
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      Center(
                        child:
                        ElevatedButton
                            .icon(
                          onPressed:
                          pickFile,
                          icon:
                          const Icon(
                            Icons
                                .file_upload,
                          ),
                          label:
                          const Text(
                            'Choose CSV File',
                          ),
                          style:
                          ElevatedButton
                              .styleFrom(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              24,
                              vertical:
                              20,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .insert_drive_file,
                            color: Colors
                                .green,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child:
                            Text(
                              fileName,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                              overflow:
                              TextOverflow
                                  .ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () {
                              setS(() {
                                fileLoaded =
                                false;
                                csvData =
                                [];
                                headers =
                                [];
                                mapping =
                                {};
                                fileName =
                                '';
                              });
                            },
                            child:
                            const Text(
                              'Change',
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        height:
                        32,
                      ),
                      const Text(
                        'CSV Column Mapping',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                          fontSize:
                          16,
                        ),
                      ),
                      const SizedBox(
                        height: 6,
                      ),
                      const Text(
                        'Mappings are matched by exact column names. '
                            'ACC only matches ACC/account-number columns, '
                            'so comments cannot accidentally become ACC.',
                        style:
                        TextStyle(
                          fontSize:
                          12,
                          color: Colors
                              .grey,
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Flexible(
                        child:
                        ListView(
                          shrinkWrap:
                          true,
                          children:
                          fields
                              .entries
                              .map(
                                (
                                field,
                                ) {
                              final selected =
                              mapping[
                              field.key];

                              return Padding(
                                padding:
                                const EdgeInsets
                                    .only(
                                  bottom:
                                  9,
                                ),
                                child:
                                Row(
                                  children: [
                                    Expanded(
                                      flex:
                                      2,
                                      child:
                                      Row(
                                        children: [
                                          if (field.key ==
                                              'accNumber')
                                            const Icon(
                                              Icons
                                                  .star,
                                              size:
                                              10,
                                              color:
                                              Colors.red,
                                            ),
                                          if (field.key ==
                                              'accNumber')
                                            const SizedBox(
                                              width:
                                              4,
                                            ),
                                          Expanded(
                                            child:
                                            Text(
                                              field.value,
                                              style:
                                              const TextStyle(
                                                fontSize:
                                                13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width:
                                      12,
                                    ),
                                    Expanded(
                                      flex:
                                      3,
                                      child:
                                      DropdownButtonFormField<
                                          int?>(
                                        initialValue:
                                        selected,
                                        isExpanded:
                                        true,
                                        decoration:
                                        const InputDecoration(
                                          contentPadding:
                                          EdgeInsets
                                              .symmetric(
                                            horizontal:
                                            10,
                                            vertical:
                                            8,
                                          ),
                                          border:
                                          OutlineInputBorder(),
                                        ),
                                        items: [
                                          const DropdownMenuItem<
                                              int?>(
                                            value:
                                            null,
                                            child:
                                            Text(
                                              'None',
                                              style:
                                              TextStyle(
                                                color:
                                                Colors.grey,
                                              ),
                                            ),
                                          ),
                                          ...List.generate(
                                            headers
                                                .length,
                                                (
                                                i,
                                                ) =>
                                                DropdownMenuItem<
                                                    int?>(
                                                  value:
                                                  i,
                                                  child:
                                                  Text(
                                                    headers[i].isEmpty
                                                        ? '(Empty column)'
                                                        : headers[i],
                                                    overflow:
                                                    TextOverflow.ellipsis,
                                                  ),
                                                ),
                                          ),
                                        ],
                                        onChanged:
                                            (
                                            value,
                                            ) {
                                          setS(() {
                                            mapping[
                                            field.key] =
                                                value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),
                      if (!hasRequiredAcc) ...[
                        const SizedBox(
                          height:
                          8,
                        ),
                        Container(
                          padding:
                          const EdgeInsets
                              .all(
                            10,
                          ),
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .red
                                .withValues(
                              alpha:
                              0.08,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              8,
                            ),
                          ),
                          child:
                          const Row(
                            children: [
                              Icon(
                                Icons
                                    .warning_amber,
                                color: Colors
                                    .red,
                                size:
                                18,
                              ),
                              SizedBox(
                                width:
                                8,
                              ),
                              Expanded(
                                child:
                                Text(
                                  'ACC Number is not mapped. '
                                      'Please map the ACC column before importing.',
                                  style:
                                  TextStyle(
                                    color:
                                    Colors.red,
                                    fontSize:
                                    12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                        dialogContext,
                      ),
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),
                if (fileLoaded)
                  ElevatedButton
                      .icon(
                    onPressed:
                    hasRequiredAcc
                        ? () {
                      Navigator
                          .pop(
                        dialogContext,
                      );

                      _startCsvImport(
                        csvData:
                        csvData,
                        mapping:
                        mapping,
                      );
                    }
                        : null,
                    icon:
                    const Icon(
                      Icons
                          .play_arrow,
                    ),
                    label:
                    const Text(
                      'Start Import',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // HEADER CLEANING
  // ===========================================================================

  String _cleanHeader(
      String value,
      ) {
    return value
        .replaceFirst(
      '\uFEFF',
      '',
    )
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  // ===========================================================================
  // EXACT COLUMN MAPPING
  // ===========================================================================

  Map<String, int?>
  _buildExactColumnMapping(
      List<String> headers,
      ) {
    final mapping =
    <String, int?>{
      'companyName':
      null,
      'accNumber':
      null,
      'systemType':
      null,
      'activationStatus':
      null,
      'groupStatus':
      null,
      'chatbotStatus':
      null,
      'verificationStatus':
      null,
      'activationDate':
      null,
      'groupDuration':
      null,
      'verificationDate':
      null,
      'verificationTicket':
      null,
      'crmComment':
      null,
      'eng':
      null,
      'months':
      null,
      'enteredDate':
      null,
    };

    int? findExact(
        List<String> candidates,
        ) {
      for (final candidate
      in candidates) {
        final normalized =
        _cleanHeader(
          candidate,
        );

        final index =
        headers.indexWhere(
              (header) =>
          header ==
              normalized,
        );

        if (index != -1) {
          return index;
        }
      }

      return null;
    }

    // -------------------------------------------------------------------------
    // COMPANY NAME
    // -------------------------------------------------------------------------

    mapping[
    'companyName'] =
        findExact([
          'Company Name',
          'Company',
          'Client Name',
        ]);

    // -------------------------------------------------------------------------
    // ACC
    //
    // IMPORTANT:
    // ACC ONLY MATCHES ACC-STYLE HEADERS.
    // -------------------------------------------------------------------------

    mapping[
    'accNumber'] =
        findExact([
          'ACC',
          'ACC Number',
          'Account Number',
          'Account No',
          'ACC No',
        ]);

    // -------------------------------------------------------------------------
    // SYSTEM
    // -------------------------------------------------------------------------

    mapping[
    'systemType'] =
        findExact([
          'System',
          'System Type',
        ]);

    // -------------------------------------------------------------------------
    // STATUSES
    // -------------------------------------------------------------------------

    mapping[
    'activationStatus'] =
        findExact([
          'Activation Status',
        ]);

    mapping[
    'groupStatus'] =
        findExact([
          'Group Status',
        ]);

    mapping[
    'chatbotStatus'] =
        findExact([
          'Chatbot Status',
        ]);

    mapping[
    'verificationStatus'] =
        findExact([
          'Verification Status',
        ]);

    // -------------------------------------------------------------------------
    // DATES
    // -------------------------------------------------------------------------

    mapping[
    'activationDate'] =
        findExact([
          'Activation Date',
        ]);

    mapping[
    'groupDuration'] =
        findExact([
          'No.Days (Group)',
          'No. Days (Group)',
          'No Days (Group)',
          'Group Duration',
          'Group Duration Days',
        ]);

    mapping[
    'verificationDate'] =
        findExact([
          'Verification Date',
        ]);

    mapping[
    'verificationTicket'] =
        findExact([
          'Verification Ticket Number',
          'Verification Ticket',
          'Ticket Number',
        ]);

    // -------------------------------------------------------------------------
    // CRM COMMENT
    // -------------------------------------------------------------------------

    mapping[
    'crmComment'] =
        findExact([
          'More Information',
          'CRM Comment',
          'Comment',
          'Comments',
          'Notes',
        ]);

    // -------------------------------------------------------------------------
    // AGENT
    // -------------------------------------------------------------------------

    mapping['eng'] =
        findExact([
          'ENG',
          'Agent',
          'Assigned Agent',
        ]);

    // -------------------------------------------------------------------------
    // MONTHS
    // -------------------------------------------------------------------------

    mapping[
    'months'] =
        findExact([
          'Months',
        ]);

    // -------------------------------------------------------------------------
    // ENTERED DATE
    // -------------------------------------------------------------------------

    mapping[
    'enteredDate'] =
        findExact([
          'Entered Date',
          'Entry Date',
        ]);

    return mapping;
  }

  String _normalizeAcc(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  int? _parseIntFlexible(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final direct = int.tryParse(text);
    if (direct != null) return direct;
    return double.tryParse(text)?.round();
  }

  DateTime? _parseCsvDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final direct = DateTime.tryParse(text);
    if (direct != null) return direct;
    final match = RegExp(r'^(\d{1,4})[\/-](\d{1,2})[\/-](\d{1,4})$').firstMatch(text);
    if (match == null) return null;
    final a = int.tryParse(match.group(1)!);
    final b = int.tryParse(match.group(2)!);
    final c = int.tryParse(match.group(3)!);
    if (a == null || b == null || c == null) return null;
    if (a >= 1000) return DateTime(a, b, c);
    final year = c < 100 ? 2000 + c : c;
    return DateTime(year, a, b);
  }

  // ===========================================================================
  // START CSV IMPORT
  // ===========================================================================

  Future<void> _startCsvImport({
    required List<List<String>> csvData,
    required Map<String, int?> mapping,
  }) async {
    if (!_isSuperAdmin) return;

    if (csvData.length <= 1) {
      _finishOperationPanel(
        title: 'Nothing to import',
        message: 'There are no data rows to import.',
      );
      return;
    }

    final totalRows = csvData.length - 1;

    _startOperationPanel(
      title: 'Importing clients',
      subtitle: 'Adding clients from the CSV file in batches',
      icon: Icons.cloud_upload_outlined,
      total: totalRows,
    );

    int imported = 0;
    int skippedExisting = 0;
    int skippedInvalid = 0;
    int failed = 0;
    final unmatchedAgents = <String>{};
    final List<List<String>> skippedRowsData = [];

    // Add headers to skipped rows output file
    if (csvData.isNotEmpty) {
      skippedRowsData.add(csvData[0]);
    }

    try {
      final existingClients = await _repository.watchClients().first;
      final existingAccNumbers = <String>{
        for (final client in existingClients)
          if (_normalizeAcc(client.accNumber).isNotEmpty)
            _normalizeAcc(client.accNumber)
      };

      // 1. Get all agents from DB for Smart Matching
      final agents = await _repository.watchAgents().first;
      final dbAgents = <String, String>{};
      for (final entry in agents.entries) {
        final uid = entry.key.trim();
        final name = entry.value.trim();
        if (uid.isEmpty || name.isEmpty) continue;
        dbAgents[_normalize(name)] = uid;
      }

      final List<Map<String, dynamic>> clientsToCreate = [];

      for (int i = 1; i < csvData.length; i++) {
        if (_cancelOperationRequested) break;
        final row = csvData[i];

        String getValue(String key) {
          final index = mapping[key];
          if (index == null || index < 0 || index >= row.length) return '';
          return row[index].trim();
        }

        final acc = _normalizeAcc(getValue('accNumber'));
        if (acc.isEmpty) {
          skippedInvalid++;
          continue;
        }
        if (existingAccNumbers.contains(acc)) {
          skippedExisting++;
          skippedRowsData.add(row); // Save row for downloading later
          continue;
        }

        final csvCompany = getValue('companyName');
        final company = csvCompany.isNotEmpty ? csvCompany : 'ACC $acc';
        final systemValue = getValue('systemType');
        final system = systemValue.isEmpty ? 'New' : systemValue;
        final activationStatus = getValue('activationStatus');
        final groupStatus = getValue('groupStatus');
        final chatbotStatus = getValue('chatbotStatus');
        final verificationStatus = getValue('verificationStatus');
        final activationDate = _parseCsvDate(getValue('activationDate'));
        final verificationDate = _parseCsvDate(getValue('verificationDate'));
        final enteredDate = _parseCsvDate(getValue('enteredDate'));
        final groupDuration = _parseIntFlexible(getValue('groupDuration'));

        // 2. SMART PARTIAL MATCHING LOGIC
        final agentName = getValue('eng');
        String assignedUid = '';

        if (agentName.isNotEmpty) {
          final normalizedCsvName = _normalize(agentName);
          String? matchedUid = dbAgents[normalizedCsvName]; // Try exact match first

          // Fallback: If exact match fails, try partial match (e.g. "Eslam" matches "Eng. Eslam Mourad")
          if (matchedUid == null) {
            for (final entry in dbAgents.entries) {
              final dbName = entry.key; // The normalized database name
              if (dbName.contains(normalizedCsvName) || normalizedCsvName.contains(dbName)) {
                matchedUid = entry.value;
                break;
              }
            }
          }

          if (matchedUid != null) {
            assignedUid = matchedUid;
          } else {
            unmatchedAgents.add(agentName); // Track names that still couldn't be matched
          }
        }

        clientsToCreate.add({
          'companyName': company,
          'accNumber': acc,
          'systemType': system,
          'activationStatus':
          activationStatus.isEmpty ? 'Not Started' : activationStatus,
          'groupStatus': groupStatus.isEmpty ? 'Not Started' : groupStatus,
          'chatbotStatus':
          chatbotStatus.isEmpty ? 'Not Started' : chatbotStatus,
          'verificationStatus': verificationStatus.isEmpty
              ? 'Not Started'
              : verificationStatus,
          'activationDate': activationDate != null ? Timestamp.fromDate(activationDate) : null,
          'verificationDate': verificationDate != null ? Timestamp.fromDate(verificationDate) : null,
          'createdAt': enteredDate != null ? Timestamp.fromDate(enteredDate) : FieldValue.serverTimestamp(),
          'groupDurationDays': groupDuration,
          'verificationTicketNumber': getValue('verificationTicket'),
          'crmComment': getValue('crmComment'),
          'months': getValue('months'),
          'assignedTo': assignedUid,
        });

        existingAccNumbers.add(acc);
      }

      // 3. FAST BATCH WRITE (Bypasses the repository's auto-assignment constraint)
      const int batchSize = 250;
      final firestore = FirebaseFirestore.instance;

      for (int i = 0; i < clientsToCreate.length; i += batchSize) {
        if (_cancelOperationRequested) break;

        final chunk = clientsToCreate.sublist(
          i,
          i + batchSize > clientsToCreate.length
              ? clientsToCreate.length
              : i + batchSize,
        );

        final batch = firestore.batch();

        for (final clientData in chunk) {
          final docRef = firestore.collection('clients').doc();
          batch.set(docRef, clientData);
        }

        await batch.commit();

        imported += chunk.length;

        if (mounted) {
          _updateOperationProgress(
            processed: i + chunk.length + skippedExisting + skippedInvalid,
            total: totalRows,
            status: 'Importing...',
          );
        }
      }

      if (!mounted) return;

      if (_cancelOperationRequested) {
        _finishOperationPanel(
          title: 'Import cancelled',
          message:
          '$imported client${imported == 1 ? '' : 's'} imported before the operation was stopped.',
        );
        return;
      }

      _updateOperationProgress(
        processed: totalRows,
        total: totalRows,
        status: 'Completed',
      );

      final unmatchedText = unmatchedAgents.isEmpty
          ? ''
          : '\nUnmatched agents: ${unmatchedAgents.join(', ')}';

      _finishOperationPanel(
        title: 'Import completed',
        message:
        'Imported: $imported\n'
            'Skipped existing: $skippedExisting\n'
            'Skipped invalid: $skippedInvalid\n'
            'Failed: $failed'
            '$unmatchedText',
        skippedRows: skippedExisting > 0 ? skippedRowsData : null,
      );
    } catch (e) {
      if (!mounted) return;
      _finishOperationPanel(
        title: 'Import failed',
        message: 'The CSV import could not be completed. Please try again.',
        error: true,
      );
    }
  }

  // ===========================================================================
  // CSV PARSER
  //
  // Supports:
  // - commas inside quoted values
  // - escaped quotes ("")
  // - quoted newlines
  // - CRLF
  // - LF
  // ===========================================================================

  List<List<String>> _parseCsv(
      String input,
      ) {
    final rows =
    <List<String>>[];

    final row =
    <String>[];

    final field =
    StringBuffer();

    bool inQuotes = false;

    for (int i = 0;
    i < input.length;
    i++) {
      final char =
      input[i];

      if (char == '"') {
        // Escaped quote:
        //
        // ""
        if (inQuotes &&
            i + 1 <
                input.length &&
            input[i + 1] ==
                '"') {
          field.write(
            '"',
          );

          i++;
        } else {
          inQuotes =
          !inQuotes;
        }

        continue;
      }

      if (char == ',' &&
          !inQuotes) {
        row.add(
          field.toString(),
        );

        field.clear();

        continue;
      }

      if ((char == '\n' ||
          char == '\r') &&
          !inQuotes) {
        // CRLF
        if (char == '\r' &&
            i + 1 <
                input.length &&
            input[i + 1] ==
                '\n') {
          i++;
        }

        row.add(
          field.toString(),
        );

        field.clear();

        if (row.any(
              (value) =>
          value
              .trim()
              .isNotEmpty,
        )) {
          rows.add(
            List<String>.from(
              row,
            ),
          );
        }

        row.clear();

        continue;
      }

      field.write(
        char,
      );
    }

    // Final row.
    if (field.isNotEmpty ||
        row.isNotEmpty) {
      row.add(
        field.toString(),
      );

      if (row.any(
            (value) =>
        value
            .trim()
            .isNotEmpty,
      )) {
        rows.add(
          List<String>.from(
            row,
          ),
        );
      }
    }

    return rows;
  }

  // ===========================================================================
  // CREATE CLIENT
  // ===========================================================================

  Future<void>
  _showCreateClientDialog() async {
    final l10n =
    AppLocalizations.of(
      context,
    );

    final theme =
    Theme.of(context);

    final cc =
    TextEditingController();

    final ac =
    TextEditingController();

    String st = 'New';

    await showDialog(
      context: context,
      builder:
          (c) => StatefulBuilder(
        builder:
            (
            context,
            setS,
            ) =>
            AlertDialog(
              title: Text(
                l10n?.translate(
                  'create_client',
                ) ??
                    'Create Client',
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                      cc,
                      decoration:
                      InputDecoration(
                        labelText:
                        l10n?.translate(
                          'company_name',
                        ) ??
                            'Company',
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    TextField(
                      controller:
                      ac,
                      decoration:
                      InputDecoration(
                        labelText:
                        l10n?.translate(
                          'acc',
                        ) ??
                            'ACC',
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    DropdownButtonFormField<
                        String>(
                      initialValue:
                      st,
                      decoration:
                      InputDecoration(
                        labelText:
                        l10n?.translate(
                          'system',
                        ) ??
                            'System',
                      ),
                      items:
                      const [
                        DropdownMenuItem(
                          value:
                          'New',
                          child:
                          Text(
                            'New',
                          ),
                        ),
                        DropdownMenuItem(
                          value:
                          'Old',
                          child:
                          Text(
                            'Old',
                          ),
                        ),
                      ],
                      onChanged:
                          (v) {
                        if (v !=
                            null) {
                          setS(
                                () {
                              st =
                                  v;
                            },
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      () =>
                      Navigator.pop(
                        c,
                      ),
                  child:
                  Text(
                    l10n?.translate(
                      'cancel',
                    ) ??
                        'Cancel',
                  ),
                ),
                    ElevatedButton(
                      onPressed:
                          () async {
                        final name = cc.text.trim();
                        final acc = ac.text.trim();
                        
                        if (name.isEmpty || acc.isEmpty) {
                          _showNotification(
                            title: 'Validation Error',
                            message: 'Company Name and ACC Number are required.',
                            error: true,
                          );
                          return;
                        }

                        final navigator =
                        Navigator.of(
                          context,
                        );

                    final messenger =
                    ScaffoldMessenger
                        .of(
                      context,
                    );

                    try {
                      await _repository
                          .createClient(
                        companyName:
                        cc.text
                            .trim(),
                        accNumber:
                        ac.text
                            .trim(),
                        systemType:
                        st,
                      );

                      if (!mounted) {
                        return;
                      }

                      navigator.pop();

                      messenger
                          .showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            'Client created.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }

                      messenger
                          .showSnackBar(
                        SnackBar(
                          content:
                          Text(
                            'Failed: $e',
                          ),
                        ),
                      );
                    }
                  },
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    theme
                        .colorScheme
                        .primary,
                    foregroundColor:
                    theme
                        .colorScheme
                        .onPrimary,
                  ),
                  child:
                  Text(
                    l10n?.translate(
                      'create',
                    ) ??
                        'Create',
                  ),
                ),
              ],
            ),
      ),
    );

    cc.dispose();
    ac.dispose();
  }
}


class _ClientFilterState {
  bool useAnd;
  DateTimeRange? creationDateRange;
  DateTimeRange? activationDateRange;
  Set<String> assigneeIds;
  Set<String> activationStatuses;
  Set<String> verificationStatuses;
  Set<String> chatbotStatuses;
  Set<String> groupStatuses;

  _ClientFilterState({
    this.useAnd = true,
    this.creationDateRange,
    this.activationDateRange,
    Set<String>? assigneeIds,
    Set<String>? activationStatuses,
    Set<String>? verificationStatuses,
    Set<String>? chatbotStatuses,
    Set<String>? groupStatuses,
  }) : assigneeIds = assigneeIds ?? <String>{},
        activationStatuses = activationStatuses ?? <String>{},
        verificationStatuses = verificationStatuses ?? <String>{},
        chatbotStatuses = chatbotStatuses ?? <String>{},
        groupStatuses = groupStatuses ?? <String>{};

  int get activeCount => [
    creationDateRange,
    activationDateRange,
  ].where((value) => value != null).length +
      [
        assigneeIds,
        activationStatuses,
        verificationStatuses,
        chatbotStatuses,
        groupStatuses,
      ].where((value) => value.isNotEmpty).length;

  bool get isActive => activeCount > 0;

  _ClientFilterState copy() {
    return _ClientFilterState(
      useAnd: useAnd,
      creationDateRange: creationDateRange,
      activationDateRange: activationDateRange,
      assigneeIds: {...assigneeIds},
      activationStatuses: {...activationStatuses},
      verificationStatuses: {...verificationStatuses},
      chatbotStatuses: {...chatbotStatuses},
      groupStatuses: {...groupStatuses},
    );
  }
}

class _ClientFiltersDialog extends StatefulWidget {
  final _ClientFilterState initial;
  final List<ClientModel> clients;
  final Map<String, String> agentNames;

  const _ClientFiltersDialog({
    required this.initial,
    required this.clients,
    required this.agentNames,
  });

  @override
  State<_ClientFiltersDialog> createState() => _ClientFiltersDialogState();
}

class _ClientFiltersDialogState extends State<_ClientFiltersDialog> {
  late _ClientFilterState _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial.copy();
  }

  List<String> _statusValues(String Function(ClientModel) getter) {
    final values = <String>{};
    for (final client in widget.clients) {
      final value = getter(client).trim();
      if (value.isNotEmpty) values.add(value);
    }
    final result = values.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  List<MapEntry<String, String>> _assignees() {
    final values = <String, String>{};
    for (final client in widget.clients) {
      final uid = client.assignedTo.trim();
      if (uid.isEmpty) continue;
      values[uid] = widget.agentNames[uid] ?? uid;
    }
    final result = values.entries.toList();
    result.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return result;
  }

  Future<void> _pickDateRange({required bool creation}) async {
    final current = creation
        ? _filters.creationDateRange
        : _filters.activationDateRange;
    final initialStart = current?.start ?? DateTime.now();
    final initialEnd = current?.end ?? initialStart;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd,
      ),
    );

    if (picked == null) return;
    setState(() {
      if (creation) {
        _filters.creationDateRange = picked;
      } else {
        _filters.activationDateRange = picked;
      }
    });
  }

  String _formatRange(DateTimeRange? range) {
    if (range == null) return 'Any date';
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return f(range.start);
    }
    return '${f(range.start)} → ${f(range.end)}';
  }

  Widget _dateFilter({
    required String title,
    required bool creation,
  }) {
    final range = creation
        ? _filters.creationDateRange
        : _filters.activationDateRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDateRange(creation: creation),
                icon: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(_formatRange(range)),
              ),
            ),
            if (range != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Clear',
                onPressed: () => setState(() {
                  if (creation) {
                    _filters.creationDateRange = null;
                  } else {
                    _filters.activationDateRange = null;
                  }
                }),
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _multiChoiceSection({
    required String title,
    required List<String> values,
    required Set<String> selected,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = selected.contains(value);
            return FilterChip(
              label: Text(value),
              selected: isSelected,
              onSelected: (selectedNow) {
                setState(() {
                  if (selectedNow) {
                    selected.add(value);
                  } else {
                    selected.remove(value);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _assigneeSection() {
    final assignees = _assignees();
    if (assignees.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assignee Name', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: assignees.map((entry) {
            final isSelected = _filters.assigneeIds.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selectedNow) {
                setState(() {
                  if (selectedNow) {
                    _filters.assigneeIds.add(entry.key);
                  } else {
                    _filters.assigneeIds.remove(entry.key);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _clear() {
    setState(() {
      _filters = _ClientFilterState(useAnd: _filters.useAnd);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activationStatuses =
    _statusValues((client) => client.activationStatus);
    final verificationStatuses =
    _statusValues((client) => client.verificationStatus);
    final chatbotStatuses =
    _statusValues((client) => client.chatbotStatus);
    final groupStatuses = _statusValues((client) => client.groupStatus);

    return AlertDialog(
      title: const Text('Filter Clients'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter logic',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('AND'),
                    icon: Icon(Icons.join_full),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('OR'),
                    icon: Icon(Icons.alt_route),
                  ),
                ],
                selected: {_filters.useAnd},
                onSelectionChanged: (selection) {
                  setState(() => _filters.useAnd = selection.first);
                },
              ),
              const SizedBox(height: 20),
              _dateFilter(title: 'Date of Creation', creation: true),
              const SizedBox(height: 16),
              _dateFilter(title: 'Date of Activation', creation: false),
              const SizedBox(height: 16),
              if (!AuthService.isSupportAgent) ...[
                if (!AuthService.isSupportAgent) ...[
                _assigneeSection(),
                if (_assignees().isNotEmpty) const SizedBox(height: 16),
              ],
              ],
              _multiChoiceSection(
                title: 'Activation Status',
                values: activationStatuses,
                selected: _filters.activationStatuses,
              ),
              const SizedBox(height: 16),
              _multiChoiceSection(
                title: 'Verification Status',
                values: verificationStatuses,
                selected: _filters.verificationStatuses,
              ),
              const SizedBox(height: 16),
              _multiChoiceSection(
                title: 'Chatbot Status',
                values: chatbotStatuses,
                selected: _filters.chatbotStatuses,
              ),
              const SizedBox(height: 16),
              if (!AuthService.isSupportAgent) ...[
                if (!AuthService.isSupportAgent) ...[
                _multiChoiceSection(
                  title: 'Group Status',
                  values: groupStatuses,
                  selected: _filters.groupStatuses,
                ),
              ],
              ],
              const SizedBox(height: 4),
              Text(
                'Multiple values inside the same field use OR. The AND/OR selector controls how the different filter fields are combined.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _clear,
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _filters),
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}

class _OperationPanelData {
  final String title;
  final int processed;
  final int total;
  final double progress;
  final bool cancelling;
  final String status;
  final String? resultMessage;
  final bool error;
  final List<List<String>>? skippedRows;

  const _OperationPanelData({
    required this.title,
    required this.processed,
    required this.total,
    required this.progress,
    required this.cancelling,
    required this.status,
    required this.resultMessage,
    required this.error,
    this.skippedRows,
  });

  const _OperationPanelData.hidden()
      : title = '',
        processed = 0,
        total = 0,
        progress = 0,
        cancelling = false,
        status = '',
        resultMessage = null,
        error = false,
        skippedRows = null;

  _OperationPanelData copyWith({
    String? title,
    int? processed,
    int? total,
    double? progress,
    bool? cancelling,
    String? status,
    String? resultMessage,
    bool? error,
    List<List<String>>? skippedRows,
  }) {
    return _OperationPanelData(
      title: title ?? this.title,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      progress: progress ?? this.progress,
      cancelling: cancelling ?? this.cancelling,
      status: status ?? this.status,
      resultMessage: resultMessage ?? this.resultMessage,
      error: error ?? this.error,
      skippedRows: skippedRows ?? this.skippedRows,
    );
  }
}

// =============================================================================
// EMPTY CLIENTS
// =============================================================================

class _EmptyClients
    extends StatelessWidget {
  final bool hasSearch;

  final VoidCallback onCreate;

  const _EmptyClients({
    required this.hasSearch,
    required this.onCreate,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off
                : Icons.people_outline,
            size: 60,
            color: theme
                .colorScheme
                .onSurface
                .withValues(
              alpha: 0.3,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            hasSearch
                ? 'No matches.'
                : 'No clients yet.',
            style:
            const TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(
              height: 16,
            ),
            ElevatedButton.icon(
              onPressed:
              onCreate,
              icon:
              const Icon(
                Icons.add,
              ),
              label:
              const Text(
                'Create First Client',
              ),
              style:
              ElevatedButton
                  .styleFrom(
                backgroundColor:
                theme
                    .colorScheme
                    .primary,
                foregroundColor:
                theme
                    .colorScheme
                    .onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
