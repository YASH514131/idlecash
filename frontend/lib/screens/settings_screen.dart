import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Settings Menu Container
            Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet Management',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.walletAddress != null
                              ? '${state.walletAddress!.substring(0, min(6, state.walletAddress!.length))}... (${state.sessionDaysRemaining}d remaining)'
                              : 'Connected',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  _buildMenuItem(
                    icon: Icons.language,
                    title: 'Network',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Base',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  _buildMenuItem(
                    icon: Icons.shield_outlined,
                    title: 'Security & Privacy',
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  _buildMenuItem(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    trailing: Switch.adaptive(
                      value: _notifications,
                      activeColor: AppTheme.accentGreen,
                      onChanged: (val) => setState(() => _notifications = val),
                    ),
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: 'About IdleCash',
                    subtitle: '1inch Aqua strategy management',
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Disconnect Wallet Button
            InkWell(
              onTap: () async {
                final appState = context.read<AppState>();
                await appState.disconnectWallet();
                if (!context.mounted) return;
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Disconnect Wallet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
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
