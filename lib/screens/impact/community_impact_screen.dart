// lib/screens/impact/community_impact_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/issue_model.dart';
import '../../models/category_model.dart';
import 'dart:developer' as developer;

class CommunityImpactScreen extends StatefulWidget {
  const CommunityImpactScreen({super.key});

  @override
  State<CommunityImpactScreen> createState() => _CommunityImpactScreenState();
}

class _CommunityImpactScreenState extends State<CommunityImpactScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Issue> _allIssues = [];
  List<CategoryModel> _categories = [];
  Map<String, int> _issuesByCategory = {};
  Map<String, int> _issuesByStatus = {};
  Map<String, int> _issuesByMonth = {};
  int _totalReportedIssues = 0;
  int _totalResolvedIssues = 0;
  int _totalAffectedUsers = 0;
  double _averageResolutionTime = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all issues
      final issuesSnapshot = await FirebaseFirestore.instance.collection('issues').get();
      final issues = issuesSnapshot.docs.map((doc) {
        return Issue.fromFirestore(doc.data(), doc.id);
      }).toList();
      _allIssues = issues;

      // Fetch categories
      final categoriesSnapshot = await FirebaseFirestore.instance.collection('categories').get();
      _categories = categoriesSnapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), doc.id);
      }).toList();

      // Process data
      _processIssueData();
    } catch (e) {
      developer.log('Error fetching impact data: ${e.toString()}', name: 'CommunityImpactScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading impact data. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processIssueData() {
    // Reset counters
    _issuesByCategory = {};
    _issuesByStatus = {};
    _issuesByMonth = {};
    _totalReportedIssues = _allIssues.length;
    _totalResolvedIssues = 0;
    _totalAffectedUsers = 0;
    double totalResolutionTime = 0;
    int resolvedIssuesCount = 0;

    for (var issue in _allIssues) {
      // Count by category
      _issuesByCategory[issue.category] = (_issuesByCategory[issue.category] ?? 0) + 1;
      
      // Count by status
      _issuesByStatus[issue.status] = (_issuesByStatus[issue.status] ?? 0) + 1;
      
      // Count by month
      final month = DateFormat('MMM yyyy').format(issue.timestamp.toDate());
      _issuesByMonth[month] = (_issuesByMonth[month] ?? 0) + 1;
      
      // Count resolved issues
      if (issue.status.toLowerCase() == 'resolved') {
        _totalResolvedIssues++;
        
        // Calculate resolution time if available
        if (issue.resolutionTimestamp != null) {
          final reportTime = issue.timestamp.toDate();
          final resolveTime = issue.resolutionTimestamp!.toDate();
          final resolutionTimeHours = resolveTime.difference(reportTime).inHours;
          totalResolutionTime += resolutionTimeHours;
          resolvedIssuesCount++;
        }
      }
      
      // Count affected users
      _totalAffectedUsers += issue.affectedUsersCount;
    }
    
    // Calculate average resolution time
    _averageResolutionTime = resolvedIssuesCount > 0 ? totalResolutionTime / resolvedIssuesCount : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Impact'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Categories'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildCategoriesTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImpactCard(
            title: 'Total Issues Reported',
            value: _totalReportedIssues.toString(),
            icon: Icons.report_problem_outlined,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildImpactCard(
            title: 'Issues Resolved',
            value: _totalResolvedIssues.toString(),
            subtitle: _totalReportedIssues > 0
                ? '${(_totalResolvedIssues / _totalReportedIssues * 100).toStringAsFixed(1)}% resolution rate'
                : 'No issues reported yet',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _buildImpactCard(
            title: 'People Impacted',
            value: _totalAffectedUsers.toString(),
            icon: Icons.people_outline,
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildImpactCard(
            title: 'Avg. Resolution Time',
            value: _averageResolutionTime > 0
                ? _averageResolutionTime < 24
                    ? '${_averageResolutionTime.toStringAsFixed(1)} hours'
                    : '${(_averageResolutionTime / 24).toStringAsFixed(1)} days'
                : 'N/A',
            icon: Icons.timer_outlined,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          const Text(
            'Status Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildStatusDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issues by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _buildCategoryPieChart(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Category Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._issuesByCategory.entries.map((entry) {
            final categoryName = entry.key;
            final count = entry.value;
            final percentage = _totalReportedIssues > 0
                ? (count / _totalReportedIssues * 100).toStringAsFixed(1)
                : '0';
            
            return ListTile(
              title: Text(categoryName),
              trailing: Text('$count issues ($percentage%)'),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    // Sort months chronologically
    final sortedMonths = _issuesByMonth.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMM yyyy').parse(a);
        final dateB = DateFormat('MMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Reporting Trends',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: _buildMonthlyTrendsChart(sortedMonths),
          ),
          const SizedBox(height: 24),
          const Text(
            'Monthly Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...sortedMonths.map((month) {
            return ListTile(
              title: Text(month),
              trailing: Text('${_issuesByMonth[month]} issues'),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildImpactCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (subtitle != null) ...[  
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistributionChart() {
    if (_issuesByStatus.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _issuesByStatus.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final statuses = _issuesByStatus.keys.toList();
                  if (value >= 0 && value < statuses.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        statuses[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 5 == 0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          barGroups: List.generate(
            _issuesByStatus.length,
            (index) {
              final status = _issuesByStatus.keys.elementAt(index);
              final count = _issuesByStatus[status]!;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: count.toDouble(),
                    color: _getStatusColor(status),
                    width: 20,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (_issuesByCategory.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return PieChart(
      PieChartData(
        sections: _issuesByCategory.entries.map((entry) {
          final categoryName = entry.key;
          final count = entry.value;
          final percentage = _totalReportedIssues > 0
              ? (count / _totalReportedIssues * 100)
              : 0.0;
          
          return PieChartSectionData(
            color: _getCategoryColor(categoryName),
            value: percentage,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: -90,
      ),
    );
  }

  Widget _buildMonthlyTrendsChart(List<String> sortedMonths) {
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value >= 0 && value < sortedMonths.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedMonths[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 5 == 0) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (sortedMonths.length - 1).toDouble(),
        minY: 0,
        maxY: _issuesByMonth.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(sortedMonths.length, (index) {
              final month = sortedMonths[index];
              final count = _issuesByMonth[month] ?? 0;
              return FlSpot(index.toDouble(), count.toDouble());
            }),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reported':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'under review':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    // Create a deterministic color based on the category name
    final colorIndex = category.hashCode % _categoryColors.length;
    return _categoryColors[colorIndex];
  }

  // Predefined colors for categories
  final List<Color> _categoryColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lightBlue,
    Colors.lime,
    Colors.deepPurple,
    Colors.brown,
  ];
}
