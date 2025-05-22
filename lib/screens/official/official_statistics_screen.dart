// lib/screens/official/official_statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/user_profile_service.dart';
import '../../models/issue_model.dart'; // Import Issue model for type safety
import 'dart:developer' as developer;

class OfficialStatisticsScreen extends StatelessWidget {
  const OfficialStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProfileService = Provider.of<UserProfileService>(context, listen: false);
    final department = userProfileService.currentUserProfile?.department;

    if (department == null || department.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Department Statistics'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Your account is not assigned to a department. Cannot display statistics.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

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
            developer.log("Error fetching stats: ${snapshot.error}", name: "OfficialStatisticsScreen");
            return Center(child: Text('Error loading statistics: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No issues found for $department department.'),
            );
          }

          final issues = snapshot.data!.docs;
          final totalIssues = issues.length;

          // Count issues by status
          // int reportedCount = 0; // We still count it for accuracy of total, but won't display it directly
          int acknowledgedCount = 0;
          int inProgressCount = 0;
          int resolvedCount = 0;
          int rejectedCount = 0;

          for (var issueDoc in issues) {
            final data = issueDoc.data() as Map<String, dynamic>;
            final issue = Issue.fromFirestore(data, issueDoc.id); // Use model for safety
            
            final status = issue.status.toLowerCase();
            
            switch (status) {
              case 'reported':
                // reportedCount++; // Not displayed directly, but contributes to totalIssues
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
              default:
                developer.log("Unknown status encountered: $status for issue ${issueDoc.id}", name: "OfficialStatisticsScreen");
                break;
            }
          }

          List<PieChartSectionData> pieSections = [];
          // Total for pie chart should be the sum of the 4 displayed categories,
          // or totalIssues if you want percentages relative to all issues.
          // Let's use sum of the 4 for clearer pie chart representation of these 4.
          double displayedTotalForPie = (acknowledgedCount + inProgressCount + resolvedCount + rejectedCount).toDouble();


          if (displayedTotalForPie > 0) { 
            if (acknowledgedCount > 0) {
               pieSections.add(_buildPieSection(acknowledgedCount.toDouble(), 'Acknowledged', Colors.lightBlue.shade300, context, displayedTotalForPie));
            }
            if (inProgressCount > 0) {
               pieSections.add(_buildPieSection(inProgressCount.toDouble(), 'In Progress', Colors.orange.shade400, context, displayedTotalForPie));
            }
            if (resolvedCount > 0) {
              pieSections.add(_buildPieSection(resolvedCount.toDouble(), 'Resolved', Colors.green.shade400, context, displayedTotalForPie));
            }
            if (rejectedCount > 0) {
              pieSections.add(_buildPieSection(rejectedCount.toDouble(), 'Rejected', Colors.red.shade300, context, displayedTotalForPie));
            }
          }
          
          // If pieSections is still empty (e.g., all issues are 'Reported' or other uncounted statuses)
          // and totalIssues > 0, show a message or a generic pie.
          // For strict 4-status display, if all are 0, the pie chart section below will be skipped.
          // If you want a pie chart even if all are 'Reported', that logic would be different.
          // Given "remove reported from all file", we will not show a pie for 'Reported'.


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          department, 
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Assigned Issues: $totalIssues', // This still reflects ALL issues
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, 
                  childAspectRatio: 1.8, 
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    // Only display the 4 requested status cards
                    _buildStatusCard(context, 'Acknowledged', acknowledgedCount, Icons.visibility_outlined, Colors.lightBlue.shade500),
                    _buildStatusCard(context, 'In Progress', inProgressCount, Icons.hourglass_top_rounded, Colors.orange.shade700),
                    _buildStatusCard(context, 'Resolved', resolvedCount, Icons.check_circle_outline, Colors.green.shade600),
                    _buildStatusCard(context, 'Rejected', rejectedCount, Icons.cancel_outlined, Colors.red.shade600),
                  ],
                ),
                const SizedBox(height: 32),
                if (pieSections.isNotEmpty) ...[ // Only show pie chart if there's data for the 4 categories
                  Text("Issue Status Distribution (Active & Closed)", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
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
                      // Legend for the 4 displayed statuses
                      if (acknowledgedCount > 0) _buildLegendItem('Acknowledged', Colors.lightBlue.shade300),
                      if (inProgressCount > 0) _buildLegendItem('In Progress', Colors.orange.shade400),
                      if (resolvedCount > 0) _buildLegendItem('Resolved', Colors.green.shade400),
                      if (rejectedCount > 0) _buildLegendItem('Rejected', Colors.red.shade300),
                    ],
                  ),
                ] else if (totalIssues > 0) ...[ // If no data for the 4 categories, but other issues exist
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 20.0),
                     child: Text(
                        "No issues currently in 'Acknowledged', 'In Progress', 'Resolved', or 'Rejected' states.", 
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]), 
                        textAlign: TextAlign.center
                      ),
                   ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
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
}
