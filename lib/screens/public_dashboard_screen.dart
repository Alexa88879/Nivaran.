import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PublicDashboardScreen extends StatelessWidget {
  const PublicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resolution Times & Satisfaction Rates (by Employee)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('employees').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No employee data available.'));
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unknown';
                      final department = data['department'] ?? 'Unknown';
                      final avgResolutionTime = data['avgResolutionTime'] ?? 'N/A';
                      final satisfactionRate = data['satisfactionRate'] ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(name.isNotEmpty ? name[0] : '?'),
                        ),
                        title: Text(name),
                        subtitle: Text('Dept: $department\nAvg. Resolution: $avgResolutionTime'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Satisfaction'),
                            Text(
                              '$satisfactionRate%',
                              style: TextStyle(
                                color: satisfactionRate > 80 ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This dashboard provides transparency on issue resolution and citizen satisfaction for each government employee.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}