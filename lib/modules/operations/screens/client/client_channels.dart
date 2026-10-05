import 'package:flutter/material.dart';

import '../../models/channel_model.dart';
import '../../models/client_model.dart';
import '../../repositories/onboarding_repository.dart';

class ClientChannelsScreen extends StatefulWidget {
  const ClientChannelsScreen({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  State<ClientChannelsScreen> createState() => _ClientChannelsScreenState();
}

class _ClientChannelsScreenState extends State<ClientChannelsScreen> {
  String? _message;
  bool _messageIsError = false;

  void _showMessage(
      String message, {
        bool error = false,
      }) {
    if (!mounted) return;

    setState(() {
      _message = message;
      _messageIsError = error;
    });
  }

  void _clearMessage() {
    if (!mounted) return;

    setState(() {
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<ClientModel?>(
      stream: OnboardingRepository().watchClient(widget.clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: colors.primary,
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const _Msg(
            icon: Icons.error_outline,
            title: 'Error',
            message: 'Client not found.',
          );
        }

        return _Content(
          client: snapshot.data!,
          clientId: widget.clientId,
          message: _message,
          messageIsError: _messageIsError,
          onDismissMessage: _clearMessage,
          onMessage: _showMessage,
        );
      },
    );
  }
}

// ============================================================
// CONTENT
// ============================================================

class _Content extends StatelessWidget {
  const _Content({
    required this.client,
    required this.clientId,
    required this.message,
    required this.messageIsError,
    required this.onDismissMessage,
    required this.onMessage,
  });

  final ClientModel client;
  final String clientId;
  final String? message;
  final bool messageIsError;
  final VoidCallback onDismissMessage;
  final void Function(
      String message, {
      bool error,
      }) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Channels',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage channels for ${client.companyName}.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CountBadge(
                      count: client.channels.length,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showChannelEditor(
                        context,
                        clientId,
                        onMessage: onMessage,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Expanded(
                  child: SingleChildScrollView(
                    child: _MainCard(
                      client: client,
                      clientId: clientId,
                      onMessage: onMessage,
                    ),
                  ),
                ),

                if (message != null) ...[
                  const SizedBox(height: 16),
                  _EmbeddedMessage(
                    message: message!,
                    isError: messageIsError,
                    onDismiss: onDismissMessage,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMBEDDED MESSAGE
// ============================================================

class _EmbeddedMessage extends StatelessWidget {
  const _EmbeddedMessage({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final accent = isError
        ? colors.error
        : colors.primary;

    return Material(
      color: colors.surfaceContainerHighest,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 19,
                color: colors.onSurface.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAIN CARD
// ============================================================

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.client,
    required this.clientId,
    required this.onMessage,
  });

  final ClientModel client;
  final String clientId;
  final void Function(
      String message, {
      bool error,
      }) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.hub_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrated Channels',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Connected communication channels',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (client.channels.isEmpty)
              const _EmptyChannels()
            else
              ...List.generate(
                client.channels.length,
                    (index) {
                  return _ChannelTile(
                    channel: client.channels[index],
                    clientId: clientId,
                    isLast: index == client.channels.length - 1,
                    onMessage: onMessage,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CHANNEL TILE
// ============================================================

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.clientId,
    required this.isLast,
    required this.onMessage,
  });

  final ChannelModel channel;
  final String clientId;
  final bool isLast;
  final void Function(
      String message, {
      bool error,
      }) onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final type = channel.channelType.trim().toLowerCase();

    final isWhatsApp = type == 'whatsapp';
    final isCallCenter = type == 'call center';

    final icon = _channelIcon(channel.channelType);

    return Container(
      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 12,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(
          alpha: 0.025,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HEADER
          // ============================================================

          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            channel.name.isNotEmpty
                                ? channel.name
                                : channel.channelType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ChannelTypeBadge(
                          type: channel.channelType,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    if (isWhatsApp &&
                        channel.phoneNumber.isNotEmpty)
                      Text(
                        channel.phoneNumber,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      )
                    else if (channel.channelValue.isNotEmpty)
                      Text(
                        channel.channelValue,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      )
                    else if (isCallCenter &&
                          channel.callCenterValue.isNotEmpty)
                        Text(
                          channel.callCenterValue,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              _StatusChip(
                status: channel.status,
              ),

              const SizedBox(width: 4),

              IconButton(
                tooltip: 'Edit channel',
                onPressed: () => _showChannelEditor(
                  context,
                  clientId,
                  channel: channel,
                  onMessage: onMessage,
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  color: colors.primary,
                  size: 20,
                ),
              ),

              IconButton(
                tooltip: 'Delete channel',
                onPressed: () => _showDel(
                  context,
                  clientId,
                  channel,
                  onMessage: onMessage,
                ),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 20,
                ),
              ),
            ],
          ),

          // ============================================================
          // DETAILS
          // ============================================================

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outlineVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;

                final details = <Widget>[
                  if (channel.name.isNotEmpty)
                    _ChannelDetail(
                      label: 'Channel Name',
                      value: channel.name,
                    ),

                  _ChannelDetail(
                    label: 'Channel Type',
                    value: channel.channelType,
                  ),

                  _ChannelDetail(
                    label: 'Status',
                    value: channel.status,
                  ),

                  if (channel.whatsappType.isNotEmpty)
                    _ChannelDetail(
                      label: 'WhatsApp Type',
                      value: channel.whatsappType,
                    ),

                  if (channel.channelValue.isNotEmpty)
                    _ChannelDetail(
                      label: 'Channel Value',
                      value: channel.channelValue,
                    ),

                  if (channel.phoneNumber.isNotEmpty)
                    _ChannelDetail(
                      label: 'Phone Number',
                      value: channel.phoneNumber,
                    ),

                  if (channel.phoneNumberId.isNotEmpty)
                    _ChannelDetail(
                      label: 'Phone Number ID',
                      value: channel.phoneNumberId,
                    ),

                  if (channel.fbmId.isNotEmpty)
                    _ChannelDetail(
                      label: 'FBM ID',
                      value: channel.fbmId,
                    ),

                  if (channel.wabaId.isNotEmpty)
                    _ChannelDetail(
                      label: 'WABA ID',
                      value: channel.wabaId,
                    ),

                  if (channel.callCenterValue.isNotEmpty)
                    _ChannelDetail(
                      label: 'Call Center',
                      value: channel.callCenterValue,
                    ),

                  if (channel.whatsappChannelToLogCalls.isNotEmpty)
                    _ChannelDetail(
                      label: 'WhatsApp Channel to Log Calls',
                      value:
                      channel.whatsappChannelToLogCalls,
                    ),
                ];

                if (details.isEmpty) {
                  return Text(
                    'No additional channel information.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  );
                }

                if (!isWide) {
                  return Column(
                    children: [
                      for (int i = 0;
                      i < details.length;
                      i++) ...[
                        details[i],
                        if (i != details.length - 1)
                          Divider(
                            height: 18,
                            color: colors.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 24,
                  runSpacing: 18,
                  children: details
                      .map(
                        (detail) => SizedBox(
                      width:
                      (constraints.maxWidth - 24) / 2,
                      child: detail,
                    ),
                  )
                      .toList(),
                );
              },
            ),
          ),

          // ============================================================
          // CALL CENTER AI
          // ============================================================

          if (isCallCenter &&
              channel.aiCallSummaryEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'AI Call Summary enabled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// CHANNEL DETAIL
// ============================================================

class _ChannelDetail extends StatelessWidget {
  const _ChannelDetail({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(
                alpha: 0.85,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CHANNEL TYPE BADGE
// ============================================================

class _ChannelTypeBadge extends StatelessWidget {
  const _ChannelTypeBadge({
    required this.type,
  });

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final normalized = status.trim().toLowerCase();

    final isPositive = [
      'active',
      'enabled',
      'connected',
    ].contains(normalized);

    final isWarning = [
      'pending',
      'processing',
    ].contains(normalized);

    final Color color;

    if (isPositive) {
      color = colors.primary;
    } else if (isWarning) {
      color = colors.tertiary;
    } else {
      color = colors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ============================================================
// COUNT BADGE
// ============================================================

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count Channels',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 48,
          horizontal: 24,
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hub_outlined,
                size: 30,
                color: colors.primary.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No channels yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a channel to start configuring integrations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE
// ============================================================

class _Msg extends StatelessWidget {
  const _Msg({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: colors.error,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: colors.onSurface.withValues(
                alpha: 0.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD CHANNEL
// ============================================================

Future<void> _showChannelEditor(
    BuildContext context,
    String clientId, {
      ChannelModel? channel,
      required void Function(
          String message, {
          bool error,
          }) onMessage,
    }) async {
  final nameCtrl = TextEditingController();
  final channelValueCtrl = TextEditingController();
  final phoneNumberCtrl = TextEditingController();
  final phoneNumberIdCtrl = TextEditingController();
  final fbmIdCtrl = TextEditingController();
  final wabaIdCtrl = TextEditingController();
  final callCenterValueCtrl = TextEditingController();
  final whatsappChannelToLogCallsCtrl =
  TextEditingController();
  final existing = channel;

  nameCtrl.text = existing?.name ?? '';
  channelValueCtrl.text = existing?.channelValue ?? '';
  phoneNumberCtrl.text = existing?.phoneNumber ?? '';
  phoneNumberIdCtrl.text = existing?.phoneNumberId ?? '';
  fbmIdCtrl.text = existing?.fbmId ?? '';
  wabaIdCtrl.text = existing?.wabaId ?? '';
  callCenterValueCtrl.text = existing?.callCenterValue ?? '';
  whatsappChannelToLogCallsCtrl.text =
      existing?.whatsappChannelToLogCalls ?? '';

  String channelType = existing?.channelType.isNotEmpty == true
      ? existing!.channelType
      : 'WhatsApp';
  String status =
  existing?.status.isNotEmpty == true ? existing!.status : 'Active';
  String whatsappType =
  existing?.whatsappType.isNotEmpty == true
      ? existing!.whatsappType
      : 'WA Cloud';
  bool aiCallSummaryEnabled =
      existing?.aiCallSummaryEnabled ?? false;
  bool saving = false;

  try {
    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colors = theme.colorScheme;

            final isWhatsApp =
                channelType.toLowerCase() == 'whatsapp';

            final isCallCenter =
                channelType.toLowerCase() == 'call center';

            final usesGenericValue = [
              'instagram',
              'facebook',
              'tiktok',
              'telegram',
              'website',
            ].contains(
              channelType.toLowerCase(),
            );

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                8,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                8,
              ),
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      existing == null
                          ? Icons.add_link_rounded
                          : Icons.edit_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existing == null
                        ? 'Add Channel'
                        : 'Edit Channel',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SectionTitle(
                        title: 'Basic Information',
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: nameCtrl,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Channel Name',
                          hintText: 'e.g. Main WhatsApp',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child:
                            DropdownButtonFormField<String>(
                              value: channelType,
                              decoration:
                              const InputDecoration(
                                labelText: 'Channel Type',
                                border:
                                OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'WhatsApp',
                                  child: Text('WhatsApp'),
                                ),
                                DropdownMenuItem(
                                  value: 'Instagram',
                                  child: Text('Instagram'),
                                ),
                                DropdownMenuItem(
                                  value: 'Facebook',
                                  child: Text('Facebook'),
                                ),
                                DropdownMenuItem(
                                  value: 'TikTok',
                                  child: Text('TikTok'),
                                ),
                                DropdownMenuItem(
                                  value: 'Telegram',
                                  child: Text('Telegram'),
                                ),
                                DropdownMenuItem(
                                  value: 'Website',
                                  child: Text('Website'),
                                ),
                                DropdownMenuItem(
                                  value: 'Call Center',
                                  child: Text('Call Center'),
                                ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  channelType = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                            DropdownButtonFormField<String>(
                              value: status,
                              decoration:
                              const InputDecoration(
                                labelText: 'Status',
                                border:
                                OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Active',
                                  child: Text('Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Inactive',
                                  child: Text('Inactive'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pending',
                                  child: Text('Pending'),
                                ),
                              ],
                              onChanged: saving
                                  ? null
                                  : (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  status = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // WHATSAPP
                      // ==================================================

                      if (isWhatsApp) ...[
                        const _SectionTitle(
                          title: 'WhatsApp Configuration',
                          icon: Icons.chat_rounded,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: whatsappType,
                          decoration:
                          const InputDecoration(
                            labelText: 'WhatsApp Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'WA Business API',
                              child: Text('WA Business API'),
                            ),
                            DropdownMenuItem(
                              value: 'WA Cloud',
                              child: Text('WA Cloud'),
                            ),
                            DropdownMenuItem(
                              value: 'WA Business APP',
                              child: Text('WA Business APP'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              whatsappType = value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: phoneNumberCtrl,
                          enabled: !saving,
                          keyboardType:
                          TextInputType.phone,
                          decoration:
                          const InputDecoration(
                            labelText: 'Phone Number',
                            hintText:
                            'e.g. +201xxxxxxxxx',
                            border:
                            OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: phoneNumberIdCtrl,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Phone Number ID (Optional)',
                            border:
                            OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fbmIdCtrl,
                                enabled: !saving,
                                decoration:
                                const InputDecoration(
                                  labelText: 'FBM ID',
                                  border:
                                  OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: wabaIdCtrl,
                                enabled: !saving,
                                decoration:
                                const InputDecoration(
                                  labelText: 'WABA ID',
                                  border:
                                  OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ==================================================
                      // GENERIC CHANNEL
                      // ==================================================

                      if (usesGenericValue) ...[
                        const _SectionTitle(
                          title: 'Channel Details',
                          icon: Icons.link_rounded,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: channelValueCtrl,
                          enabled: !saving,
                          decoration: InputDecoration(
                            labelText:
                            _channelValueLabel(
                              channelType,
                            ),
                            hintText:
                            _channelValueHint(
                              channelType,
                            ),
                            border:
                            const OutlineInputBorder(),
                          ),
                        ),
                      ],

                      // ==================================================
                      // CALL CENTER
                      // ==================================================

                      if (isCallCenter) ...[
                        const _SectionTitle(
                          title:
                          'Call Center Configuration',
                          icon:
                          Icons.phone_in_talk_rounded,
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller:
                          callCenterValueCtrl,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Call Center Number / Name',
                            hintText:
                            'Enter the call center number or name',
                            border:
                            OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller:
                          whatsappChannelToLogCallsCtrl,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'WhatsApp Channel to Log Calls',
                            hintText:
                            'WhatsApp channel name / identifier',
                            border:
                            OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: colors.onSurface
                                .withValues(
                              alpha: 0.025,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              10,
                            ),
                            border: Border.all(
                              color:
                              colors.outlineVariant,
                            ),
                          ),
                          child: SwitchListTile(
                            value:
                            aiCallSummaryEnabled,
                            onChanged: saving
                                ? null
                                : (value) {
                              setState(() {
                                aiCallSummaryEnabled =
                                    value;
                              });
                            },
                            title: Text(
                              'AI Call Summary',
                              style: TextStyle(
                                fontWeight:
                                FontWeight.w600,
                                color:
                                colors.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Enable AI-generated summaries for calls.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface
                                    .withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            activeColor:
                            colors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                20,
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                    final name =
                    nameCtrl.text.trim();

                    if (name.isEmpty) {
                      onMessage(
                        'Please enter a channel name.',
                        error: true,
                      );
                      return;
                    }

                    setState(() {
                      saving = true;
                    });

                    final now = DateTime.now();

                    final newChannel =
                    ChannelModel(
                      id: existing?.id ??
                          DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                      channelType:
                      channelType,
                      name: name,
                      status: status,
                      whatsappType:
                      isWhatsApp
                          ? whatsappType
                          : '',
                      channelValue:
                      usesGenericValue
                          ? channelValueCtrl
                          .text
                          .trim()
                          : '',
                      phoneNumber:
                      isWhatsApp
                          ? phoneNumberCtrl
                          .text
                          .trim()
                          : '',
                      phoneNumberId:
                      isWhatsApp
                          ? phoneNumberIdCtrl
                          .text
                          .trim()
                          : '',
                      fbmId:
                      isWhatsApp
                          ? fbmIdCtrl.text
                          .trim()
                          : '',
                      wabaId:
                      isWhatsApp
                          ? wabaIdCtrl.text
                          .trim()
                          : '',
                      callCenterValue:
                      isCallCenter
                          ? callCenterValueCtrl
                          .text
                          .trim()
                          : '',
                      whatsappChannelToLogCalls:
                      isCallCenter
                          ? whatsappChannelToLogCallsCtrl
                          .text
                          .trim()
                          : '',
                      aiCallSummaryEnabled:
                      isCallCenter
                          ? aiCallSummaryEnabled
                          : false,
                      externalId:
                      existing?.externalId ?? '',
                      createdAt:
                      existing?.createdAt,
                      updatedAt:
                      DateTime.now(),
                    );

                    try {
                      if (existing == null) {
                        await OnboardingRepository()
                            .addChannel(
                          clientId,
                          newChannel,
                        );
                      } else {
                        await OnboardingRepository()
                            .updateChannel(
                          clientId,
                          newChannel,
                        );
                      }

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );

                      onMessage(
                        existing == null
                            ? 'Channel added successfully.'
                            : 'Channel updated successfully.',
                      );
                    } catch (e) {
                      if (!context.mounted) {
                        return;
                      }

                      setState(() {
                        saving = false;
                      });

                      onMessage(
                        existing == null
                            ? 'Failed to add channel: $e'
                            : 'Failed to update channel: $e',
                        error: true,
                      );
                    }
                  },
                  icon: saving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : Icon(
                    existing == null
                        ? Icons.add_rounded
                        : Icons.save_outlined,
                  ),
                  label: Text(
                    saving
                        ? (existing == null
                        ? 'Adding...'
                        : 'Saving...')
                        : (existing == null
                        ? 'Add Channel'
                        : 'Save Changes'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    colors.primary,
                    foregroundColor:
                    colors.onPrimary,
                    elevation: 0,
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    nameCtrl.dispose();
    channelValueCtrl.dispose();
    phoneNumberCtrl.dispose();
    phoneNumberIdCtrl.dispose();
    fbmIdCtrl.dispose();
    wabaIdCtrl.dispose();
    callCenterValueCtrl.dispose();
    whatsappChannelToLogCallsCtrl.dispose();
  }
}

// ============================================================
// SECTION TITLE
// ============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: colors.primary,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DELETE CHANNEL
// ============================================================

Future<void> _showDel(
    BuildContext context,
    String clientId,
    ChannelModel ch, {
      required void Function(
          String message, {
          bool error,
          }) onMessage,
    }) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colors = theme.colorScheme;

      final channelName = ch.name.isNotEmpty
          ? ch.name
          : ch.channelType;

      return AlertDialog(
        title: Text(
          'Delete Channel',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the channel '
              '"$channelName"? This action cannot be undone.',
          style: TextStyle(
            color: colors.onSurface.withValues(
              alpha: 0.75,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                false,
              );
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(
                dialogContext,
                true,
              );
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
            ),
            label: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    await OnboardingRepository().deleteChannel(
      clientId,
      ch.id,
    );

    if (!context.mounted) return;

    onMessage(
      'Channel deleted successfully.',
    );
  } catch (e) {
    if (!context.mounted) return;

    onMessage(
      'Failed to delete channel: $e',
      error: true,
    );
  }
}

// ============================================================
// CHANNEL IDENTIFIER
// ============================================================

String _channelIdentifier(
    ChannelModel channel,
    ) {
  final type = channel.channelType
      .trim()
      .toLowerCase();

  if (type == 'whatsapp') {
    if (channel.phoneNumber.isNotEmpty) {
      return channel.phoneNumber;
    }

    if (channel.phoneNumberId.isNotEmpty) {
      return 'Phone ID: ${channel.phoneNumberId}';
    }

    if (channel.wabaId.isNotEmpty) {
      return 'WABA: ${channel.wabaId}';
    }

    return '';
  }

  if (type == 'call center') {
    return channel.callCenterValue;
  }

  if (channel.channelValue.isNotEmpty) {
    return channel.channelValue;
  }

  return '';
}

// ============================================================
// CHANNEL ICON
// ============================================================

IconData _channelIcon(
    String type,
    ) {
  switch (type.trim().toLowerCase()) {
    case 'whatsapp':
      return Icons.chat_rounded;

    case 'instagram':
      return Icons.camera_alt_rounded;

    case 'facebook':
      return Icons.facebook_rounded;

    case 'tiktok':
      return Icons.music_note_rounded;

    case 'telegram':
      return Icons.send_rounded;

    case 'website':
      return Icons.language_rounded;

    case 'call center':
      return Icons.phone_in_talk_rounded;

    default:
      return Icons.hub_rounded;
  }
}

// ============================================================
// GENERIC VALUE LABEL
// ============================================================

String _channelValueLabel(
    String type,
    ) {
  switch (type.trim().toLowerCase()) {
    case 'instagram':
      return 'Instagram Account Name';

    case 'facebook':
      return 'Facebook Page Name';

    case 'tiktok':
      return 'TikTok Account Name';

    case 'telegram':
      return 'Telegram Bot URL / Username';

    case 'website':
      return 'Website URL';

    default:
      return 'Channel Value';
  }
}

// ============================================================
// GENERIC VALUE HINT
// ============================================================

String _channelValueHint(
    String type,
    ) {
  switch (type.trim().toLowerCase()) {
    case 'instagram':
      return 'e.g. @company';

    case 'facebook':
      return 'e.g. Company Page';

    case 'tiktok':
      return 'e.g. @company';

    case 'telegram':
      return 'e.g. https://t.me/company';

    case 'website':
      return 'e.g. https://example.com';

    default:
      return '';
  }
}
