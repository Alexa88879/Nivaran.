import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';

class OfficialStatisticsScreen extends StatelessWidget {
  const OfficialStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final department = userProfileService.currentUserProfile?.department;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Statistics'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('issues')
            .where('assignedDepartment', isEqualTo: department)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No issues found for ${department ?? "your department"}'),
            );
          }

          final issues = snapshot.data!.docs;
          final totalIssues = issues.length;

          // Count issues by status
          int resolved = 0;
          int inProgress = 0;
          int pending = 0;

          for (var issue in issues) {
            final data = issue.data() as Map<String, dynamic>;
            final status = (data['status'] as String).toLowerCase();
            
            if (status == 'resolved') {
              resolved++;
            } else if (status == 'addressed') {
              inProgress++;
            } else {
              pending++;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Department Name Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          department ?? 'Your Department',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Issues: $totalIssues',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusCard(context, 'Resolved', resolved, Colors.green),
                    _buildStatusCard(context, 'In Progress', inProgress, Colors.orange),
                    _buildStatusCard(context, 'Pending', pending, Colors.red),
                  ],
                ),
                const SizedBox(height: 32),

                // Pie Chart
                if (totalIssues > 0) ...[
                  SizedBox(
                    height: 300,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            color: Colors.red.shade400,
                            value: pending.toDouble(),
                            title: '${((pending / totalIssues) * 100).toStringAsFixed(1)}%',
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.yellow.shade400,
                            value: resolved.toDouble(),
                            title: '${((resolved / totalIssues) * 100).toStringAsFixed(1)}%',
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.green.shade400,
                            value: inProgress.toDouble(),
                            title: '${((inProgress / totalIssues) * 100).toStringAsFixed(1)}%',
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Pending', Colors.red.shade400),
                      const SizedBox(width: 16),
                      _buildLegendItem('Resolved', Colors.yellow.shade400),
                      const SizedBox(width: 16),
                      _buildLegendItem('In Progress', Colors.green.shade400),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String title, int count, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 100,
        child: Column(
          children: [
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(title),
      ],
    );
  }
}