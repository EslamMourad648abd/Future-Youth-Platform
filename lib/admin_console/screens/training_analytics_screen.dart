import 'package:bbc_api_tool/admin_console/services/training_analytics_service.dart';
import 'package:flutter/material.dart';

import '../../modules/training/models/agent_training_analytics_model.dart';

import 'agent_training_details_screen.dart';

class TrainingAnalyticsScreen extends StatefulWidget {
  const TrainingAnalyticsScreen({
    super.key,
  });

  @override
  State<TrainingAnalyticsScreen> createState() =>
      _TrainingAnalyticsScreenState();
}

class _TrainingAnalyticsScreenState
    extends State<TrainingAnalyticsScreen> {
  // ============================================================
  // SERVICE
  // ============================================================

  final TrainingAnalyticsService service =
  TrainingAnalyticsService();

  // ============================================================
  // STATE
  // ============================================================

  List<AgentTrainingAnalyticsModel> agents = [];

  bool loading = true;

  bool refreshing = false;

  String? error;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadAnalytics();
  }

  // ============================================================
  // INITIAL / CACHED LOAD
  // ============================================================

  Future<void> _loadAnalytics() async {
    try {
      final result =
      await service.getAllTraineeAnalytics();

      if (!mounted) return;

      setState(() {
        agents = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      debugPrint(
        'ANALYTICS ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });

      if (agents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load analytics',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // FORCE REFRESH
  // ============================================================

  Future<void> _refreshAnalytics() async {
    if (refreshing) return;

    setState(() {
      refreshing = true;
    });

    try {
      final result =
      await service.getAllTraineeAnalytics(
        forceRefresh: true,
      );

      if (!mounted) return;

      setState(() {
        agents = result;
        refreshing = false;
        error = null;
      });
    } catch (e) {
      debugPrint(
        'ANALYTICS REFRESH ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        refreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to refresh analytics',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ANALYTICS CARD
  // ============================================================

  Widget _analyticsCard(
      AgentTrainingAnalyticsModel agent,
      ) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius:
      BorderRadius.circular(16),

      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AgentTrainingDetailsScreen(
                  agent: agent,
                ),
          ),
        );
      },

      child: Card(
        elevation: 0,
        color: theme.cardTheme.color,
        margin: const EdgeInsets.only(
          bottom: 16,
        ),

        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor),
        ),

        child: Padding(
          padding:
          const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // ==================================================
              // USER HEADER
              // ==================================================

              Row(
                children: [
                  CircleAvatar(
                    radius: 25,

                    backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),

                    child: Text(
                      agent.userName.isNotEmpty
                          ? agent.userName[0]
                          .toUpperCase()
                          : '?',

                      style:
                      TextStyle(
                        color:
                        theme.colorScheme.primary,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  Expanded(
                    child: Text(
                      agent.userName,

                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // STATISTICS
              // ==================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

                children: [
                  _stat(
                    'Courses',
                    agent.totalCourses
                        .toString(),
                    theme,
                  ),

                  _stat(
                    'Completed',
                    agent.completedCourses
                        .toString(),
                    theme,
                  ),

                  _stat(
                    'Progress',
                    '${agent.overallProgress.toStringAsFixed(0)}%',
                    theme,
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // QUIZ SCORE
              // ==================================================

              Text(
                'Average Quiz Score',

                style: TextStyle(
                  color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              LinearProgressIndicator(
                value:
                (agent.averageQuizScore /
                    100)
                    .clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                color: theme.colorScheme.primary,
                minHeight: 10,
              ),

              const SizedBox(
                height: 8,
              ),

              Align(
                alignment:
                Alignment.centerRight,

                child: Text(
                  '${agent.averageQuizScore.toStringAsFixed(1)}%',

                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,

                    color:
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STAT
  // ============================================================

  Widget _stat(
      String title,
      String value,
      ThemeData theme,
      ) {
    return Column(
      children: [
        Text(
          value,

          style:
          TextStyle(
            fontSize: 18,
            fontWeight:
            FontWeight.bold,
            color:
            theme.colorScheme.primary,
          ),
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          title,

          style:
          TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _refreshAnalytics,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children: const [
          SizedBox(
            height: 250,
          ),

          Center(
            child: Text(
              'No trainee data available',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _errorState() {
    return RefreshIndicator(
      onRefresh: _refreshAnalytics,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children: [
          const SizedBox(
            height: 180,
          ),

          const Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red,
          ),

          const SizedBox(
            height: 16,
          ),

          const Center(
            child: Text(
              'Failed to load analytics',
              style:
              TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 30,
            ),

            child: Text(
              error ?? '',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Center(
            child: ElevatedButton(
              onPressed:
              _loadAnalytics,
              child:
              const Text(
                'Try Again',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title:
        const Text(
          'Training Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        actions: [
          IconButton(
            tooltip:
            'Refresh analytics',

            onPressed:
            refreshing
                ? null
                : _refreshAnalytics,

            icon: refreshing
                ? SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
                : const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: loading

      // ====================================================
      // FIRST LOAD
      // ====================================================

          ? const Center(
        child:
        CircularProgressIndicator(),
      )

      // ====================================================
      // ERROR WITH NO DATA
      // ====================================================

          : error != null &&
          agents.isEmpty

          ? _errorState()

      // ==================================================
      // EMPTY
      // ==================================================

          : agents.isEmpty

          ? _emptyState()

      // ==============================================
      // DATA
      // ==============================================

          : LayoutBuilder(builder: (context, constraints) {
              int columns;
              if (constraints.maxWidth >= 1100) {
                columns = 3;
              } else if (constraints.maxWidth >= 700) {
                columns = 2;
              } else {
                columns = 1;
              }

              return RefreshIndicator(
                onRefresh: _refreshAnalytics,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    mainAxisExtent: 310,
                  ),
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    return _analyticsCard(agents[index]);
                  },
                ),
              );
            }),
    );
  }
}
