import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Executions', 'Updates'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final filteredList = state.activities.where((act) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Executions') {
        return act.type == 'execution' || act.type == 'fee';
      }
      if (_selectedFilter == 'Updates') {
        return act.type == 'update';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Filter Pills
            Row(
              children: _filters.map((filter) {
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedFilter = filter),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppTheme.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? Colors.white : AppTheme.cardBorder,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Activity Items
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: filteredList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filteredList[index];
                  return _buildActivityCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityItem item) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (item.type) {
      case 'execution':
        icon = Icons.shield_outlined;
        iconColor = AppTheme.accentGreen;
        bgColor = AppTheme.accentGreen.withValues(alpha: 0.15);
        break;
      case 'fee':
        icon = Icons.trending_up;
        iconColor = AppTheme.accentGreen;
        bgColor = AppTheme.accentGreen.withValues(alpha: 0.15);
        break;
      case 'update':
      default:
        icon = Icons.settings_outlined;
        iconColor = Colors.white70;
        bgColor = Colors.white.withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: !item.isPositive
                  ? AppTheme.accentRed
                  : item.type == 'fee'
                      ? AppTheme.accentGreen
                      : Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
