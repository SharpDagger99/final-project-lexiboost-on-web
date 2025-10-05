// ignore_for_file: unused_field, prefer_final_fields, deprecated_member_use

import 'package:flutter/material.dart';

class MyReport extends StatefulWidget {
  const MyReport({super.key});

  @override
  State<MyReport> createState() => _MyReportState();
}

class _MyReportState extends State<MyReport> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All';
  String _selectedPriority = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    final isMediumScreen = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1E201E),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 8,
          radius: const Radius.circular(20),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(isWideScreen),
                const SizedBox(height: 24),

                // Stats Overview
                _buildStatsOverview(isWideScreen, isMediumScreen),
                const SizedBox(height: 24),

                // Filter Section
                _buildFilters(isWideScreen),
                const SizedBox(height: 24),

                // Tabs Section
                _buildTabBar(),
                const SizedBox(height: 20),

                // Tab Content
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReportsTab(isWideScreen, isMediumScreen),
                      _buildNotificationsTab(isWideScreen, isMediumScreen),
                      _buildConfigurationTab(isWideScreen, isMediumScreen),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateReportDialog(context);
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildHeader(bool isWideScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Management',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor and manage system reports',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (isWideScreen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '5 Urgent',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatsOverview(bool isWideScreen, bool isMediumScreen) {
    int crossAxisCount = isWideScreen ? 4 : (isMediumScreen ? 2 : 2);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isWideScreen ? 1.5 : 1.3,
      children: [
        _buildStatCard(
          icon: Icons.report_problem,
          title: 'Total Reports',
          value: '248',
          change: '+12%',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.pending_actions,
          title: 'Pending',
          value: '42',
          change: '+5%',
          color: Colors.yellow,
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          title: 'Resolved',
          value: '189',
          change: '+18%',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.notifications,
          title: 'Notifications',
          value: '67',
          change: '+8%',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isWideScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildFilterChip('All', _selectedFilter),
          _buildFilterChip('Students', _selectedFilter),
          _buildFilterChip('Teachers', _selectedFilter),
          const SizedBox(width: 20),
          _buildPriorityChip('Low', Colors.green),
          _buildPriorityChip('Medium', Colors.orange),
          _buildPriorityChip('High', Colors.red),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected) {
    final isSelected = selected == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        tabs: const [
          Tab(text: 'Reports'),
          Tab(text: 'Notifications'),
          Tab(text: 'Configuration'),
        ],
      ),
    );
  }

  Widget _buildReportsTab(bool isWideScreen, bool isMediumScreen) {
    return ListView(
      children: [
        _buildReportItem(
          'Inappropriate Behavior',
          'Student John Doe reported for...',
          'Student',
          'High',
          Colors.red,
          '2 hours ago',
        ),
        _buildReportItem(
          'Technical Issue',
          'Game loading error reported by...',
          'Teacher',
          'Medium',
          Colors.orange,
          '5 hours ago',
        ),
        _buildReportItem(
          'Content Concern',
          'Review flagged for inappropriate...',
          'Student',
          'Low',
          Colors.green,
          '1 day ago',
        ),
        _buildReportItem(
          'Account Access',
          'Teacher unable to access dashboard...',
          'Teacher',
          'High',
          Colors.red,
          '3 hours ago',
        ),
        _buildReportItem(
          'Spam Activity',
          'Multiple spam messages detected...',
          'Student',
          'Medium',
          Colors.orange,
          '6 hours ago',
        ),
      ],
    );
  }

  Widget _buildReportItem(
    String title,
    String description,
    String type,
    String priority,
    Color priorityColor,
    String time,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priority,
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                    onPressed: () {},
                    tooltip: 'View Details',
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    onPressed: () {},
                    tooltip: 'Resolve',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () {},
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab(bool isWideScreen, bool isMediumScreen) {
    return ListView(
      children: [
        _buildNotificationItem(
          'New Report Submitted',
          'A student has submitted a new report regarding...',
          Icons.report,
          Colors.orange,
          '10 min ago',
          true,
        ),
        _buildNotificationItem(
          'Report Resolved',
          'Report #1234 has been successfully resolved',
          Icons.check_circle,
          Colors.green,
          '1 hour ago',
          false,
        ),
        _buildNotificationItem(
          'Urgent Action Required',
          'High priority report needs immediate attention',
          Icons.warning,
          Colors.red,
          '30 min ago',
          true,
        ),
        _buildNotificationItem(
          'System Update',
          'Report system has been updated with new features',
          Icons.system_update,
          Colors.blue,
          '2 hours ago',
          false,
        ),
        _buildNotificationItem(
          'Weekly Summary',
          'You have resolved 15 reports this week',
          Icons.analytics,
          Colors.purple,
          '1 day ago',
          false,
        ),
      ],
    );
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    IconData icon,
    Color color,
    String time,
    bool isUnread,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? color.withOpacity(0.1) : const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationTab(bool isWideScreen, bool isMediumScreen) {
    return ListView(
      children: [
        _buildConfigSection(
          'Report Categories',
          'Manage available report categories',
          Icons.category,
          Colors.blue,
        ),
        _buildConfigSection(
          'Priority Levels',
          'Configure priority level thresholds',
          Icons.flag,
          Colors.orange,
        ),
        _buildConfigSection(
          'Auto-Response',
          'Set up automatic responses for reports',
          Icons.auto_awesome,
          Colors.purple,
        ),
        _buildConfigSection(
          'Email Notifications',
          'Configure email notification settings',
          Icons.email,
          Colors.green,
        ),
        _buildConfigSection(
          'User Permissions',
          'Manage admin and moderator permissions',
          Icons.security,
          Colors.red,
        ),
        _buildConfigSection(
          'Report Templates',
          'Create and edit report templates',
          Icons.description,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildConfigSection(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: color, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  void _showCreateReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Create New Report',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report creation dialog will be implemented here',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}