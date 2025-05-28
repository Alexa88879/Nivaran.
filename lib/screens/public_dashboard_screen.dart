// lib/screens/public_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // Add this import for pie chart
import '../../models/issue_model.dart'; // Add this import for Issue model
import 'dart:developer' as developer; // For logging
import '../services/predictive_maintenance_service.dart';
// Removed: import 'dart:math' show sqrt;
class PublicDashboardScreen extends StatelessWidget {
  const PublicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Dashboard'),
        centerTitle: true,
        // Adding a back button if this screen is pushed onto the stack
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Cards Row
            _buildStatusCardsRow(context, textTheme),
            const SizedBox(height: 32),
            // Issue Status Distribution Section
            _buildIssueStatusDistribution(context, textTheme),
            const SizedBox(height: 32),
            // Add the Predictive Maintenance Section
            _buildPredictiveMaintenance(context, textTheme),
            const SizedBox(height: 32),
            Text(
              'Resolution Times & Satisfaction Rates', // Simplified title
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '(Data by Employee/Department)', // Subtitle for clarity
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300, // Fixed height for employee list
              child: _buildEmployeeList(context, textTheme),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'This dashboard provides transparency on issue resolution and citizen satisfaction.',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCardsRow(BuildContext context, TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('issues').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          developer.log('Error loading issues: ${snapshot.error}', name: 'PublicDashboard');
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }
        
        final issues = snapshot.data?.docs ?? [];
        
        // Count issues by status
        int totalReported = issues.length;
        int acknowledgedCount = 0;
        int inProgressCount = 0;
        int resolvedCount = 0;
        int rejectedCount = 0;
        
        for (var issueDoc in issues) {
          final data = issueDoc.data() as Map<String, dynamic>;
          final issue = Issue.fromFirestore(data, issueDoc.id);
          
          final status = issue.status.toLowerCase();
          
          switch (status) {
            case 'acknowledged':
              acknowledgedCount++;
              break;
            case 'in progress':
              inProgressCount++;
              break;
            case 'resolved':
              resolvedCount++;
              break;
            case 'rejected':
              rejectedCount++;
              break;
          }
        }
        
        // Calculate currently pending (in progress only)
        int pendingCount = inProgressCount;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatusCard(context, 'Total Reported', totalReported, Icons.flag_outlined, Colors.blue.shade600),
            _buildStatusCard(context, 'Total Resolved', resolvedCount, Icons.check_circle_outline, Colors.green.shade600),
            _buildStatusCard(context, 'Currently Pending', pendingCount, Icons.hourglass_empty_outlined, Colors.orange.shade600),
            _buildStatusCard(context, 'Acknowledged', acknowledgedCount, Icons.visibility_outlined, Colors.lightBlue.shade500),
            _buildStatusCard(context, 'Total Rejected', rejectedCount, Icons.cancel_outlined, Colors.red.shade600),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueStatusDistribution(BuildContext context, TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('issues').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          developer.log('Error loading issues: ${snapshot.error}', name: 'PublicDashboard');
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }
        
        final issues = snapshot.data?.docs ?? [];
        
        // Count issues by status
        int reportedCount = 0;
        int acknowledgedCount = 0;
        int inProgressCount = 0;
        int resolvedCount = 0;
        int rejectedCount = 0;
        
        for (var issueDoc in issues) {
          final data = issueDoc.data() as Map<String, dynamic>;
          final issue = Issue.fromFirestore(data, issueDoc.id);
          
          final status = issue.status.toLowerCase();
          
          switch (status) {
            case 'reported':
              reportedCount++;
              break;
            case 'acknowledged':
              acknowledgedCount++;
              break;
            case 'in progress':
              inProgressCount++;
              break;
            case 'resolved':
              resolvedCount++;
              break;
            case 'rejected':
              rejectedCount++;
              break;
          }
        }
        
        List<PieChartSectionData> pieSections = [];
        double totalIssues = issues.length.toDouble();
        
        if (totalIssues > 0) {
          if (reportedCount > 0) {
            pieSections.add(_buildPieSection(reportedCount.toDouble(), 'Reported', Colors.blue.shade400, context, totalIssues));
          }
          if (acknowledgedCount > 0) {
            pieSections.add(_buildPieSection(acknowledgedCount.toDouble(), 'Acknowledged', Colors.lightBlue.shade300, context, totalIssues));
          }
          if (inProgressCount > 0) {
            pieSections.add(_buildPieSection(inProgressCount.toDouble(), 'Pending', Colors.orange.shade400, context, totalIssues));
          }
          if (resolvedCount > 0) {
            pieSections.add(_buildPieSection(resolvedCount.toDouble(), 'Solved', Colors.green.shade400, context, totalIssues));
          }
          if (rejectedCount > 0) {
            pieSections.add(_buildPieSection(rejectedCount.toDouble(), 'Rejected', Colors.red.shade300, context, totalIssues));
          }
        }
        
        if (pieSections.isEmpty) {
          return const Center(child: Text('No issue data available'));
        }
        
        return Column(
          children: [
            Text(
              "Issue Status Distribution", 
              style: textTheme.titleLarge, 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: pieSections,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      // Handle touch events if needed
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16.0,
              runSpacing: 8.0,
              children: [
                if (reportedCount > 0) _buildLegendItem('Reported', Colors.blue.shade400),
                if (acknowledgedCount > 0) _buildLegendItem('Acknowledged', Colors.lightBlue.shade300),
                if (inProgressCount > 0) _buildLegendItem('Pending', Colors.orange.shade400),
                if (resolvedCount > 0) _buildLegendItem('Solved', Colors.green.shade400),
                if (rejectedCount > 0) _buildLegendItem('Rejected', Colors.red.shade300),
              ],
            ),
          ],
        );
      },
    );
  }

  PieChartSectionData _buildPieSection(double value, String title, Color color, BuildContext context, double total) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    final String displayTitle = value > 0 ? '${percentage.toStringAsFixed(0)}%' : '';

    return PieChartSectionData(
      color: color,
      value: value,
      title: displayTitle,
      radius: 100,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildEmployeeList(BuildContext context, TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('employees').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          developer.log('Error loading employee data: ${snapshot.error}', name: 'PublicDashboard');
          return Center(child: Text('Error loading employee data: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No employee performance data available at the moment.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This section will show statistics once employee data is populated in the "employees" collection in Firestore.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>? ?? {};
            final name = data['name'] as String? ?? 'N/A';
            final department = data['department'] as String? ?? 'N/A';
            final avgResolutionTime = data['avgResolutionTime']?.toString() ?? 'N/A';
            final satisfactionRateNum = data['satisfactionRate'];
            double satisfactionRate = 0.0;
            if (satisfactionRateNum is num) {
              satisfactionRate = satisfactionRateNum.toDouble();
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              ),
              title: Text(name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Department: $department\nAvg. Resolution Time: $avgResolutionTime',
                style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${satisfactionRate.toStringAsFixed(0)}%',
                    style: textTheme.titleMedium?.copyWith(
                      color: satisfactionRate >= 80
                          ? Colors.green.shade700
                          : satisfactionRate >= 60
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Satisfaction', style: textTheme.bodySmall),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}

// Add this import at the top of the file


// Inside the PublicDashboardScreen class, add this method
Widget _buildPredictiveMaintenance(BuildContext context, TextTheme textTheme) {
  return FutureBuilder<List<PredictionCluster>>(
    future: PredictiveMaintenance().getPredictions(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasError) {
        developer.log('Error loading predictions: ${snapshot.error}', name: 'PublicDashboard');
        return Center(child: Text('Error loading prediction data: ${snapshot.error}'));
      }
      
      final predictions = snapshot.data ?? [];
      
      if (predictions.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Not enough historical data for predictions yet',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'As more issues are reported, we\'ll identify patterns to predict where problems might recur.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Predictive Maintenance Insights',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Areas where issues are likely to reoccur based on historical patterns',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: predictions.length > 5 ? 5 : predictions.length, // Show top 5 predictions
            itemBuilder: (context, index) {
              final prediction = predictions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(prediction.category),
                              color: Theme.of(context).primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prediction.category,
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prediction.address,
                                  style: textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getRiskColor(prediction.riskScore).withAlpha(26), // Changed from withValues
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _getRiskColor(prediction.riskScore), width: 1),
                            ),
                            child: Text(
                              'Risk: ${prediction.formattedRiskScore}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getRiskColor(prediction.riskScore),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoChip(
                            context,
                            Icons.repeat,
                            'Pattern: ${prediction.recurrencePattern}',
                            Colors.blue.shade700,
                          ),
                          _buildInfoChip(
                            context,
                            Icons.history,
                            '${prediction.issueCount} past issues',
                            Colors.orange.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Proactive maintenance in this area could prevent recurring issues.',
                        style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benefit: Enables proactive government action',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Addressing these areas before new issues are reported can save resources and improve citizen satisfaction.',
                          style: textTheme.bodySmall?.copyWith(color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildInfoChip(BuildContext context, IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withAlpha(26), // Changed back to withOpacity as it's the correct method
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

IconData _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'road':
      return Icons.add_road; // Changed from Icons.road to Icons.add_road
    case 'water':
      return Icons.water_drop;
    case 'electricity':
      return Icons.electric_bolt;
    case 'garbage':
      return Icons.delete;
    case 'sewage':
      return Icons.water_damage;
    case 'public property':
      return Icons.domain;
    default:
      return Icons.warning_amber;
  }
}

Color _getRiskColor(double riskScore) {
  if (riskScore > 20) {
    return Colors.red.shade700;
  } else if (riskScore > 10) {
    return Colors.orange.shade700;
  } else {
    return Colors.blue.shade700;
  }
}
