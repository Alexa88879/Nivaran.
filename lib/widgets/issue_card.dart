import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/issue_model.dart'; // Assuming your model path
import '../services/firestore_service.dart'; // Assuming your service path
import '../screens/full_screen_image_view.dart'; // Assuming your screen path

// Import necessary packages for AI risk prediction
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/risk_prediction_service.dart'; // Path to your RiskPredictionService

class IssueCard extends StatefulWidget {
  final Issue issue;

  const IssueCard({super.key, required this.issue});

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  VoteType? _optimisticVote;
  int _optimisticUpvotes = 0;
  int _optimisticDownvotes = 0;

  // State variables for AI Risk Prediction
  String? _riskPredictionText;
  bool _isFetchingRisk = false;

  @override
  void initState() {
    super.initState();
    _updateOptimisticStateFromWidget();
  }

  void _updateOptimisticStateFromWidget() {
    _optimisticUpvotes = widget.issue.upvotes;
    _optimisticDownvotes = widget.issue.downvotes;
    if (_currentUser != null &&
        widget.issue.voters.containsKey(_currentUser.uid)) { // Removed '!'
      _optimisticVote = widget.issue.voters[_currentUser.uid]; // Removed '!'
    } else {
      _optimisticVote = null;
    }
  }

  @override
  void didUpdateWidget(covariant IssueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.issue.id != oldWidget.issue.id ||
        widget.issue.upvotes != oldWidget.issue.upvotes ||
        widget.issue.downvotes != oldWidget.issue.downvotes ||
        !_mapEquals(widget.issue.voters, oldWidget.issue.voters) ||
        widget.issue.status != oldWidget.issue.status) {
      setState(() {
        _updateOptimisticStateFromWidget();
        // Reset AI prediction if issue changes significantly
        _riskPredictionText = null;
        _isFetchingRisk = false;
      });
    }
  }

  bool _mapEquals<T, U>(Map<T, U> a, Map<T, U> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    return DateFormat('dd MMM').format(dateTime);
  }

  Color _getStatusPillBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green.shade50;
      case 'addressed':
        return Colors.orange.shade50;
      case 'reported':
      default:
        return Colors.red.shade50;
    }
  }

  Color _getStatusPillTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green.shade700;
      case 'addressed':
        return Colors.orange.shade700;
      case 'reported':
      default:
        return Colors.red.shade700;
    }
  }

  IconData _getStatusPillIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle_outline_rounded;
      case 'addressed':
        return Icons.task_alt_rounded;
      case 'reported':
      default:
        return Icons.error_outline_rounded;
    }
  }

  Future<void> _handleVote(VoteType voteType) async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to vote.')),
        );
      }
      return;
    }

    final String userId = _currentUser.uid; // Removed '!'

    int previousOptimisticUpvotes = _optimisticUpvotes;
    int previousOptimisticDownvotes = _optimisticDownvotes;
    VoteType? previousOptimisticVote = _optimisticVote;

    int newOptimisticUpvotes = _optimisticUpvotes;
    int newOptimisticDownvotes = _optimisticDownvotes;
    VoteType? newLocalVoteState;

    if (_optimisticVote == voteType) {
      newLocalVoteState = null;
      if (voteType == VoteType.upvote) { // Added curly braces
        newOptimisticUpvotes--;
      } else { // Added curly braces
        newOptimisticDownvotes--;
      }
    } else {
      newLocalVoteState = voteType;
      if (_optimisticVote == VoteType.upvote) {
        newOptimisticUpvotes--;
      }
      if (_optimisticVote == VoteType.downvote) {
        newOptimisticDownvotes--;
      }

      if (voteType == VoteType.upvote) { // Added curly braces
        newOptimisticUpvotes++;
      } else { // Added curly braces
        newOptimisticDownvotes++;
      }
    }

    if (mounted) {
      setState(() {
        _optimisticVote = newLocalVoteState;
        _optimisticUpvotes = newOptimisticUpvotes.clamp(0, 999999);
        _optimisticDownvotes = newOptimisticDownvotes.clamp(0, 999999);
      });
    }

    try {
      await _firestoreService.voteIssue(widget.issue.id, userId, voteType);
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticUpvotes = previousOptimisticUpvotes;
          _optimisticDownvotes = previousOptimisticDownvotes;
          _optimisticVote = previousOptimisticVote;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register vote: ${e.toString()}')),
        );
      }
    }
  }

  // Method to fetch and display AI risk prediction
  Future<void> _fetchAndDisplayRiskPrediction(String imageUrl) async {
    if (imageUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image not available for risk prediction.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFetchingRisk = true;
        _riskPredictionText = null; // Clear previous prediction
      });
    }

    try {
      final http.Response imageResponse = await http.get(Uri.parse(imageUrl));
      if (imageResponse.statusCode == 200) {
        final Uint8List imageBytes = imageResponse.bodyBytes;
        final String? prediction = await RiskPredictionService.getRiskPredictionFromImage(imageBytes);

        if (mounted) {
          setState(() {
            _riskPredictionText = prediction ?? "No specific risks identified or unable to analyze.";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _riskPredictionText = "Failed to load image (Error: ${imageResponse.statusCode}).";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _riskPredictionText = "Error predicting risk. Please try again.";
        });
      }
      // print("Error fetching risk prediction: $e"); // Commented out avoid_print
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRisk = false;
        });
      }
    }
  }

  Widget _buildRiskPredictionSection() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _isFetchingRisk ? null : () => _fetchAndDisplayRiskPrediction(widget.issue.imageUrl),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                   decoration: BoxDecoration(
                     border: Border.all(color: _isFetchingRisk ? Colors.grey.shade300 : Theme.of(context).primaryColor.withAlpha(180), width: 1.2),
                     borderRadius: BorderRadius.circular(20),
                     color: _isFetchingRisk ? Colors.grey.shade100 : Theme.of(context).primaryColor.withAlpha(20)
                   ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined, // AI/Insight icon
                        size: 17,
                        color: _isFetchingRisk ? Colors.grey.shade500 : Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "AI Risk Analysis",
                        style: TextStyle(fontSize: 12.5, color: _isFetchingRisk ? Colors.grey.shade500 : Theme.of(context).primaryColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isFetchingRisk)
                const Padding(
                  padding: EdgeInsets.only(left: 10.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                ),
            ],
          ),
          if (_riskPredictionText != null && !_isFetchingRisk)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 6.0),
              child: Text(
                _riskPredictionText!,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.black.withAlpha((255 * 0.75).round()), // Replaced withOpacity
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool userHasUpvoted = _optimisticVote == VoteType.upvote;
    final bool userHasDownvoted = _optimisticVote == VoteType.downvote;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 1.5,
      shadowColor: Colors.grey.withAlpha(51),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info and Status Pill Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_circle, size: 38, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.issue.username.isNotEmpty ? widget.issue.username : 'Anonymous',
                        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15.5),
                      ),
                      Text(
                        _formatTimestamp(widget.issue.timestamp),
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusPillBackgroundColor(widget.issue.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusPillIcon(widget.issue.status), size: 11, color: _getStatusPillTextColor(widget.issue.status)),
                      const SizedBox(width: 3),
                      Text(
                        widget.issue.status,
                        style: TextStyle(
                            color: _getStatusPillTextColor(widget.issue.status),
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.issue.description.isNotEmpty ? 8 : 4),

            // Description and Location
            if (widget.issue.description.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.issue.description,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.black.withAlpha(204)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (widget.issue.location.address.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 15, color: Colors.red[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.issue.location.address,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            SizedBox(height: widget.issue.imageUrl.isNotEmpty ? 12 : 8),

            // Image Display
            if (widget.issue.imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageView(imageUrl: widget.issue.imageUrl),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      widget.issue.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        } 
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40));
                      },
                    ),
                  ),
                ),
              ),
            
            // AI Risk Prediction Section - NEW
            if (widget.issue.imageUrl.isNotEmpty)
              _buildRiskPredictionSection(),

            const SizedBox(height: 10), // Spacing before action buttons

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _ActionChipButton(
                  icon: Icons.arrow_upward_rounded,
                  label: _optimisticUpvotes.toString(),
                  isActive: userHasUpvoted,
                  activeColor: Colors.green.shade600,
                  onTap: () => _handleVote(VoteType.upvote),
                ),
                const SizedBox(width: 8),
                _ActionChipButton(
                  icon: Icons.arrow_downward_rounded,
                  label: _optimisticDownvotes.toString(),
                  isActive: userHasDownvoted,
                  activeColor: Colors.red.shade600,
                  onTap: () => _handleVote(VoteType.downvote),
                ),
                const SizedBox(width: 8),
                _ActionChipButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: widget.issue.commentsCount.toString(),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View Comments - Coming Soon!')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _ActionChipButton(
                  icon: Icons.share_outlined,
                  label: "Share",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share Issue - Coming Soon!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// _ActionChipButton class
class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    const Color defaultColorForElements = Colors.black54;

    final Color effectiveIconColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark) : defaultColorForElements;
    final Color effectiveTextColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark) : defaultColorForElements;
    final Color effectiveBorderColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark).withAlpha(178) : Colors.grey[350]!;
    final Color effectiveFillColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark).withAlpha(20) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: effectiveFillColor,
          border: Border.all(color: effectiveBorderColor, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: effectiveIconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, color: effectiveTextColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}