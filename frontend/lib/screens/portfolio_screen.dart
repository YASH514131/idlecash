import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/donut_chart.dart';
import '../widgets/mini_chart.dart';
import '../widgets/token_icon.dart';

class PortfolioScreen extends StatefulWidget {
  final bool showBackButton;

  const PortfolioScreen({super.key, this.showBackButton = false});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _selectedRange = '1M';
  final List<String> _ranges = ['1D', '1W', '1M', '3M', '1Y'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rangeDuration = switch (_selectedRange) {
      '1D' => const Duration(days: 1),
      '1W' => const Duration(days: 7),
      '3M' => const Duration(days: 90),
      '1Y' => const Duration(days: 365),
      _ => const Duration(days: 30),
    };
    final rangeStart = DateTime.now().subtract(rangeDuration);
    final snapshots = state.portfolioSnapshots
        .where((snapshot) =>
            snapshot.capturedAt.isAfter(rangeStart) && snapshot.totalUsd > 0)
        .toList();
    final historyValues =
        snapshots.map((snapshot) => snapshot.totalUsd).toList();
    final hasTokenValue = state.totalPortfolioUsd > 0;
    final rangeChange = historyValues.length < 2
        ? null
        : ((historyValues.last - historyValues.first) /
            historyValues.first *
            100);

    return Scaffold(
      backgroundColor: Colors.black, // Pure pitch black OLED
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 18, color: Colors.white),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              )
            : null,
        title: Text(
          'Portfolio',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh wallet balances',
            onPressed: state.isLoadingAssets
                ? null
                : () => state.refreshWalletAssets(),
            icon: state.isLoadingAssets
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF38BDF8)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ─── Center Donut Chart ──────────────────────────────────────────
            Center(
              child: hasTokenValue
                  ? DonutChart(
                      percentage: state.portfolioWethPercent,
                      size: 160,
                    )
                  : SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          state.walletAssetsError != null
                              ? 'Balances unavailable'
                              : 'No token balance',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF8E95A8),
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 4),
            Text(
              hasTokenValue ? 'WETH share of token portfolio' : '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF8E95A8),
              ),
            ),
            const SizedBox(height: 18),

            // ─── Token Breakdown Legend ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  imagePath: 'lib/assets/images/weth.png',
                  name: 'WETH',
                  percent: hasTokenValue
                      ? '${state.portfolioWethPercent.toInt()}%'
                      : '--',
                ),
                const SizedBox(width: 32),
                _buildLegendItem(
                  imagePath: 'lib/assets/images/usdc.png',
                  name: 'USDC',
                  percent: hasTokenValue
                      ? '${state.portfolioUsdcPercent.toInt()}%'
                      : '--',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── Total Value Card ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token Portfolio Value · USD estimate',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E95A8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? 'Unavailable'
                        : !state.isConnected
                            ? 'Connect wallet'
                            : '\$${state.totalPortfolioUsd.toStringAsFixed(2)}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rangeChange == null
                        ? 'Balance history is collecting snapshots'
                        : '${rangeChange >= 0 ? '+' : ''}${rangeChange.toStringAsFixed(2)}% balance change over $_selectedRange',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: rangeChange == null
                          ? const Color(0xFF8E95A8)
                          : rangeChange >= 0
                              ? const Color(0xFF00E599)
                              : AppTheme.accentRed,
                    ),
                  ),
                  if (state.walletAssetsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.walletAssets.isEmpty
                          ? state.walletAssetsError!
                          : 'Could not refresh balances; showing the last successful read. ${state.walletAssetsError!}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Testnet/local-fork ETH is gas-only and excluded. WETH uses the ETH market price; test-token USD values are estimates, not redeemable cash. Aqua allocation is already represented in these wallet balances.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF8E95A8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildActiveAquaCard(state),
            const SizedBox(height: 20),

            _buildAssetBreakdown(state),
            const SizedBox(height: 20),

            // ─── Balance History Card with Area Chart & Time Ranges ────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance History',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SparklineChart(
                    data: historyValues,
                    height: 100,
                    width: double.infinity,
                    lineColor: Colors.white,
                    showFill: true,
                  ),
                  if (historyValues.length < 2) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.walletAssetsError != null
                          ? 'Refresh balances after the RPC connection is restored.'
                          : 'History appears after another wallet snapshot. Balance changes include deposits and withdrawals; they are not investment returns.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF8E95A8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _ranges.map((range) {
                      final isSelected = range == _selectedRange;
                      return InkWell(
                        onTap: () => setState(() => _selectedRange = range),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            range,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAquaCard(AppState state) {
    final activeValue = state.aquaTotalLiquidityUsd;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Aqua allocation',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${activeValue.toStringAsFixed(2)}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.activeAquaStrategies.length} active ${state.activeAquaStrategies.length == 1 ? 'strategy' : 'strategies'} · virtual allocation, not an additional wallet balance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.4,
              color: const Color(0xFF8E95A8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetBreakdown(AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet assets',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (state.isLoadingAssets && state.walletAssets.isEmpty)
            const LinearProgressIndicator()
          else if (state.walletAssetsError != null &&
              state.walletAssets.isEmpty)
            Text(
              'Balances unavailable. Check your selected network and RPC, then refresh.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.accentRed,
              ),
            )
          else ...[
            ...state.walletAssets.map((asset) {
              final isGas = asset.symbol == 'ETH';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    TokenIcon(symbol: asset.symbol, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.symbol,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isGas
                                ? 'Gas balance · excluded from token value'
                                : asset.contractAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFF8E95A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${asset.balance.toStringAsFixed(asset.symbol == 'USDC' ? 2 : 6)} ${asset.symbol}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (!isGas)
                            Text(
                              '\$${asset.usdValue.toStringAsFixed(2)} est.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String imagePath,
    required String name,
    required String percent,
  }) {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            imagePath,
            width: 18,
            height: 18,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                TokenIcon(symbol: name, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percent,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
