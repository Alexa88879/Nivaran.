// lib/widgets/issue_collaborations_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class IssueCollaborationsWidget extends StatelessWidget {
  final String issueId;

  const IssueCollaborationsWidget({super.key, required this.issueId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('issue_collaborations')
          .where('issueId', isEqualTo: issueId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No collaborations yet. Be the first to contribute!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCollaborationItem(context, data);
          },
        );
      },
    );
  }

  Widget _buildCollaborationItem(BuildContext context, Map<String, dynamic> data) {
    final contributionType = data['contributionType'] as String;
    final username = data['username'] as String;
    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate())
        : 'Recently';

    // Get icon and color based on contribution type
    IconData icon;
    Color color;
    String title;

    switch (contributionType) {
      case 'additional_info':
        icon = Icons.info_outline;
        color = Colors.blue;
        title = '$username added information';
        break;
      case 'affected_user':
        icon = Icons.person_add_outlined;
        color = Colors.orange;
        title = '$username is also affected';
        break;
      case 'update':
        icon = Icons.update_outlined;
        color = Colors.green;
        title = '$username provided an update';
        break;
      case 'evidence':
        icon = Icons.photo_camera_outlined;
        color = Colors.purple;
        title = '$username added evidence';
        break;
      default:
        icon = Icons.comment_outlined;
        color = Colors.grey;
        title = '$username contributed';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (data.containsKey('text') && data['text'] != null) ...[  
              const SizedBox(height: 12),
              Text(data['text'] as String),
            ],
            if (data.containsKey('imageUrls') && data['imageUrls'] != null) ...[  
              const SizedBox(height: 12),
              _buildImageGallery(data['imageUrls'] as List<dynamic>),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<dynamic> imageUrls) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showFullScreenImage(context, imageUrls[index]),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
