// lib/widgets/issue_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/issue_model.dart';
import '../services/firestore_service.dart';
import '../screens/full_screen_image_view.dart';
import '../widgets/comments_dialog.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/risk_prediction_service.dart';
import 'dart:developer' as developer;

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
  String? _riskPredictionText;
  bool _isFetchingRisk = false;
  bool _showFullOriginalText = false; // State for toggling original text

  // Define a threshold for "short" description (e.g., characters or lines)
  static const int shortDescriptionLengthThreshold = 70; // Characters
  // static const int shortDescriptionLineThreshold = 2; // Lines

  @override
  void initState() {
    super.initState();
    _updateOptimisticStateFromWidget();
    // Determine initial state of _showFullOriginalText based on main description length
    _showFullOriginalText = widget.issue.description.length <= shortDescriptionLengthThreshold;
  }

  void _updateOptimisticStateFromWidget() {
    _optimisticUpvotes = widget.issue.upvotes;
    _optimisticDownvotes = widget.issue.downvotes;
    if (_currentUser != null && widget.issue.voters.containsKey(_currentUser!.uid)) {
      _optimisticVote = widget.issue.voters[_currentUser!.uid];
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
        widget.issue.status != oldWidget.issue.status ||
        widget.issue.urgency != oldWidget.issue.urgency ||
        !_listEquals(widget.issue.tags, oldWidget.issue.tags) ||
        widget.issue.description != oldWidget.issue.description || // Check description change
        widget.issue.originalSpokenText != oldWidget.issue.originalSpokenText ) {
      setStateIfMounted(() {
        _updateOptimisticStateFromWidget();
        _riskPredictionText = null;
        _isFetchingRisk = false;
        // Reset _showFullOriginalText based on the new issue's description length
        _showFullOriginalText = widget.issue.description.length <= shortDescriptionLengthThreshold;
      });
    }
  }

  void setStateIfMounted(VoidCallback f) {
    if (mounted) {
      setState(f);
    }
  }

  bool _mapEquals<T, U>(Map<T, U> a, Map<T, U> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return DateFormat('dd MMM').format(dateTime);
  }

  Color _getStatusPillBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Colors.green.shade50;
      case 'in progress': case 'acknowledged': return Colors.orange.shade50;
      case 'rejected': return Colors.red.shade100;
      case 'reported': default: return Colors.blue.shade50;
    }
  }

  Color _getStatusPillTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Colors.green.shade700;
      case 'in progress': case 'acknowledged': return Colors.orange.shade700;
      case 'rejected': return Colors.red.shade700;
      case 'reported': default: return Colors.blue.shade700;
    }
  }

  IconData _getStatusPillIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved': return Icons.check_circle_outline_rounded;
      case 'in progress': return Icons.hourglass_top_rounded;
      case 'acknowledged': return Icons.visibility_outlined;
      case 'rejected': return Icons.cancel_outlined;
      case 'reported': default: return Icons.report_problem_outlined;
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high': return Colors.red.shade600;
      case 'medium': return Colors.orange.shade600;
      case 'low': return Colors.blue.shade600;
      default: return Colors.grey.shade500;
    }
  }

  Future<void> _handleVote(VoteType voteType) async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need to be logged in to vote.')));
      }
      return;
    }

    final String userId = _currentUser!.uid;
    final VoteType? previousOptimisticVote = _optimisticVote;
    final int previousOptimisticUpvotes = _optimisticUpvotes;
    final int previousOptimisticDownvotes = _optimisticDownvotes;

    VoteType? newLocalVoteState;
    int newOptimisticUpvotes = _optimisticUpvotes;
    int newOptimisticDownvotes = _optimisticDownvotes;

    if (_optimisticVote == voteType) {
      newLocalVoteState = null;
      if (voteType == VoteType.upvote) newOptimisticUpvotes--;
      else newOptimisticDownvotes--;
    } else {
      newLocalVoteState = voteType;
      if (_optimisticVote == VoteType.upvote) newOptimisticUpvotes--;
      if (_optimisticVote == VoteType.downvote) newOptimisticDownvotes--;
      if (voteType == VoteType.upvote) newOptimisticUpvotes++;
      else newOptimisticDownvotes++;
    }

    setStateIfMounted(() {
      _optimisticVote = newLocalVoteState;
      _optimisticUpvotes = newOptimisticUpvotes.clamp(0, 999999);
      _optimisticDownvotes = newOptimisticDownvotes.clamp(0, 999999);
    });

    try {
      await _firestoreService.voteIssue(widget.issue.id, userId, voteType);
    } catch (e) {
      developer.log("Error voting: $e", name: "IssueCard");
      if (mounted) {
        setState(() {
          _optimisticVote = previousOptimisticVote;
          _optimisticUpvotes = previousOptimisticUpvotes;
          _optimisticDownvotes = previousOptimisticDownvotes;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register vote: ${e.toString()}')));
      }
    }
  }

  Future<void> _fetchAndDisplayRiskPrediction(String imageUrl) async {
    if (imageUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image not available for risk prediction.')));
      }
      return;
    }
    setStateIfMounted(() => _isFetchingRisk = true);

    try {
      final http.Response imageResponse = await http.get(Uri.parse(imageUrl));
      if (!mounted) return;

      if (imageResponse.statusCode == 200) {
        final Uint8List imageBytes = imageResponse.bodyBytes;
        final String? prediction = await RiskPredictionService.getRiskPredictionFromImage(imageBytes);
        if (!mounted) return;
        setState(() => _riskPredictionText = prediction ?? "No specific risks identified or unable to analyze.");
      } else {
        setStateIfMounted(() => _riskPredictionText = "Failed to load image (Error: ${imageResponse.statusCode}).");
      }
    } catch (e) {
      developer.log("Error fetching risk prediction: $e", name: "IssueCard");
      setStateIfMounted(() => _riskPredictionText = "Error predicting risk. Please try again.");
    } finally {
      setStateIfMounted(() => _isFetchingRisk = false);
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
                      Icon(Icons.auto_awesome_outlined, size: 17, color: _isFetchingRisk ? Colors.grey.shade500 : Theme.of(context).primaryColor),
                      const SizedBox(width: 5),
                      Text("AI Risk Analysis", style: TextStyle(fontSize: 12.5, color: _isFetchingRisk ? Colors.grey.shade500 : Theme.of(context).primaryColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              if (_isFetchingRisk) const Padding(padding: EdgeInsets.only(left: 10.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.0))),
            ],
          ),
          if (_riskPredictionText != null && !_isFetchingRisk)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 6.0),
              child: Text(_riskPredictionText!, style: textTheme.bodySmall?.copyWith(color: Colors.black.withAlpha((0.75 * 255).round()), fontSize: 12.5, fontStyle: FontStyle.italic), maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }

  Widget _buildOriginalTextSection() {
    final issue = widget.issue;
    final theme = Theme.of(context);
    bool shouldDisplayOriginal = issue.originalSpokenText != null &&
                                 issue.originalSpokenText!.isNotEmpty &&
                                 issue.userInputLanguage != null &&
                                 !issue.userInputLanguage!.toLowerCase().startsWith('en');

    if (!shouldDisplayOriginal) {
      return const SizedBox.shrink();
    }

    bool isDescriptionLong = issue.description.length > shortDescriptionLengthThreshold;

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Original Report (in ${issue.userInputLanguage!.split('-')[0]}):", // Displaying base language
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.blueGrey[700],
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _showFullOriginalText || !isDescriptionLong
                ? issue.originalSpokenText!
                : issue.originalSpokenText!.split('\n').first, // Show first line or full if short desc
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 13.0,
              color: Colors.black.withAlpha(200),
            ),
            maxLines: _showFullOriginalText || !isDescriptionLong ? null : 1,
            overflow: _showFullOriginalText || !isDescriptionLong ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (isDescriptionLong && issue.originalSpokenText!.contains('\n') || issue.originalSpokenText!.length > 70 ) // only show toggle if original text might be truncated
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 20),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              onPressed: () {
                setStateIfMounted(() {
                  _showFullOriginalText = !_showFullOriginalText;
                });
              },
              child: Text(
                _showFullOriginalText ? "Show less" : "Show more",
                style: TextStyle(color: theme.primaryColor, fontSize: 12.0),
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
      shadowColor: Colors.grey.withAlpha((0.2 * 255).round()),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_circle, size: 38, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.issue.username.isNotEmpty ? widget.issue.username : 'Anonymous', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text(_formatTimestamp(widget.issue.timestamp), style: textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _getStatusPillBackgroundColor(widget.issue.status), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusPillIcon(widget.issue.status), size: 11, color: _getStatusPillTextColor(widget.issue.status)),
                      const SizedBox(width: 3),
                      Text(widget.issue.status, style: TextStyle(color: _getStatusPillTextColor(widget.issue.status), fontWeight: FontWeight.w600, fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.issue.description.isNotEmpty ? 8 : 4),
            if (widget.issue.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 0), // Reduced bottom padding
                child: Text(widget.issue.description, style: textTheme.bodyMedium?.copyWith(fontSize: 14.0, color: Colors.black.withAlpha((0.8 * 255).round())), maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            _buildOriginalTextSection(), // Display original text section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                children: [
                  Chip(
                    avatar: Icon(Icons.category_outlined, size: 14, color: Theme.of(context).colorScheme.secondary),
                    label: Text(widget.issue.category, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500)),
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha((0.3 * 255).round()),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (widget.issue.urgency != null && widget.issue.urgency!.isNotEmpty)
                    Chip(
                      avatar: Icon(Icons.priority_high_rounded, size: 14, color: _getUrgencyColor(widget.issue.urgency)),
                      label: Text(widget.issue.urgency!, style: TextStyle(fontSize: 11, color: _getUrgencyColor(widget.issue.urgency), fontWeight: FontWeight.w500)),
                      backgroundColor: _getUrgencyColor(widget.issue.urgency).withAlpha((0.1 * 255).round()),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (widget.issue.tags != null && widget.issue.tags!.isNotEmpty)
                    ...widget.issue.tags!.map((tag) => Chip(
                          label: Text(tag, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                          backgroundColor: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )),
                ],
              ),
            ),
            if (widget.issue.location.address.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(widget.issue.location.address, style: textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontSize: 12.5, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            SizedBox(height: widget.issue.imageUrl.isNotEmpty ? 12 : 8),
            if (widget.issue.imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageView(imageUrl: widget.issue.imageUrl))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      widget.issue.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      errorBuilder: (context, error, stackTrace) {
                        developer.log("Error loading image in IssueCard: $error", name: "IssueCard");
                        return Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 40));
                      },
                    ),
                  ),
                ),
              ),
            if (widget.issue.imageUrl.isNotEmpty) _buildRiskPredictionSection(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _ActionChipButton(icon: Icons.arrow_upward_rounded, label: _optimisticUpvotes.toString(), isActive: userHasUpvoted, activeColor: Colors.green.shade600, onTap: () => _handleVote(VoteType.upvote)),
                const SizedBox(width: 8),
                _ActionChipButton(icon: Icons.arrow_downward_rounded, label: _optimisticDownvotes.toString(), isActive: userHasDownvoted, activeColor: Colors.red.shade600, onTap: () => _handleVote(VoteType.downvote)),
                const SizedBox(width: 8),
                _ActionChipButton(icon: Icons.chat_bubble_outline_rounded, label: widget.issue.commentsCount.toString(), onTap: () => showDialog(context: context, builder: (context) => CommentsDialog(issueId: widget.issue.id, issueDescription: widget.issue.description))),
                const SizedBox(width: 8),
                _ActionChipButton(icon: Icons.share_outlined, label: "Share", onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share Issue - Coming Soon!')))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;
  const _ActionChipButton({required this.icon, required this.label, required this.onTap, this.isActive = false, this.activeColor});

  @override
  Widget build(BuildContext context) {
    const Color defaultColorForElements = Colors.black54;
    final Color effectiveIconColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark) : defaultColorForElements;
    final Color effectiveTextColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark) : defaultColorForElements;
    final Color effectiveBorderColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark).withAlpha((0.7 * 255).round()) : Colors.grey[350]!;
    final Color effectiveFillColor = isActive ? (activeColor ?? Theme.of(context).primaryColorDark).withAlpha((0.08 * 255).round()) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(color: effectiveFillColor, border: Border.all(color: effectiveBorderColor, width: 1.2), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: effectiveIconColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12.5, color: effectiveTextColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}