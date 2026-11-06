import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_state.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_chart.dart';
import '../widgets/token_icon.dart';
import 'create_strategy_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshWalletAssets();
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141722),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF00E599), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label copied to clipboard!',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAquaStrategy({
    required BuildContext pageContext,
    BuildContext? modalContext,
    required AppState state,
    required Map<String, dynamic> strategy,
  }) async {
    final isActive = strategy['status'] == 'active';
    if (isActive) {
      final shouldReplace = await showDialog<bool>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF151924),
          title: const Text(
            'Replace active strategy?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'A shipped Aqua strategy cannot be edited in place. To change it, IdleCash must first dock this strategy, then you can ship a replacement. Docking removes its virtual allocation; your tokens remain in your wallet.',
            style: TextStyle(color: Color(0xFFB2B8C8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep active'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Dock and edit'),
            ),
          ],
        ),
      );
      if (shouldReplace != true || !pageContext.mounted) return;

      try {
        await WalletService.ensureAppKitSession(pageContext);
        await state.dockAquaStrategy(
          strategy['strategyHash']?.toString() ?? '',
        );
      } catch (error) {
        if (pageContext.mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            SnackBar(content: Text(WalletService.describeError(error))),
          );
        }
        rethrow;
      }
    }

    if (!pageContext.mounted) return;
    state.updateStrategyAmount(state.aquaStrategyConfiguredAmount(strategy));
    final activeModalContext = modalContext;
    if (activeModalContext != null && activeModalContext.mounted) {
      Navigator.of(activeModalContext).pop();
    }
    Navigator.of(pageContext).push(
      MaterialPageRoute(builder: (_) => const CreateStrategyScreen()),
    );
  }

  Future<void> _cancelAquaStrategy(
    BuildContext context,
    AppState state,
    Map<String, dynamic> strategy,
  ) async {
    final strategyHash = strategy['strategyHash']?.toString() ?? '';
    final status = strategy['status']?.toString();
    if (status != 'dock_pending') {
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF151924),
          title: const Text(
            'Cancel this strategy?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This docks only the selected strategy and removes its virtual allocation. Your tokens remain in your wallet.',
            style: TextStyle(color: Color(0xFFB2B8C8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep active'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel strategy'),
            ),
          ],
        ),
      );
      if (shouldCancel != true || !context.mounted) return;
    }

    try {
      if (status == 'dock_pending') {
        await state.verifyAquaStrategy(strategyHash, verifyDock: true);
      } else {
        await WalletService.ensureAppKitSession(context);
        await state.dockAquaStrategy(strategyHash);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(WalletService.describeError(error))),
      );
    }
  }

  Widget _buildAquaStrategiesSection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Strategies',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '${state.aquaStrategies.length}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8E95A8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (state.aquaStrategies.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF12141C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1D212E)),
            ),
            child: Text(
              'No strategies yet. Create one to get started.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF8E95A8),
              ),
            ),
          ),
        ...state.aquaStrategies.map((strategy) {
          final status = strategy['status']?.toString() ?? 'unknown';
          final isActive = status == 'active';
          final isDocked = status == 'docked';
          final isPendingDock = status == 'dock_pending';
          final strategyHash = strategy['strategyHash']?.toString() ?? '';
          final displayStatus = isDocked ? 'CANCELLED' : status.toUpperCase();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF12141C),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1D212E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strategyHash.length > 12
                            ? 'WETH / USDC · ${strategyHash.substring(0, 8)}…${strategyHash.substring(strategyHash.length - 4)}'
                            : 'WETH / USDC · $strategyHash',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayStatus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? const Color(0xFF00E599)
                            : const Color(0xFF8E95A8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Strategy value: \$${state.aquaStrategyLiquidityUsd(strategy).toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (isActive || isDocked) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => _editAquaStrategy(
                          pageContext: context,
                          state: state,
                          strategy: strategy,
                        ),
                        child: const Text('Edit'),
                      ),
                      if (isActive)
                        OutlinedButton(
                          onPressed: () =>
                              _cancelAquaStrategy(context, state, strategy),
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ] else if (isPendingDock) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () =>
                        _cancelAquaStrategy(context, state, strategy),
                    child: const Text('Verify cancellation'),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _dispatchMetaMaskWrap(double amountEth) async {
    final wei = BigInt.from((amountEth * 1e18).round());
    final ethUri = Uri.parse(
      'ethereum:${WalletService.activeWethContract}@${WalletService.activeChainId}?value=$wei',
    );
    final metamaskUniversal = Uri.parse(
      'https://metamask.app.link/send/${WalletService.activeWethContract}@${WalletService.activeChainId}?value=$wei',
    );

    try {
      if (await canLaunchUrl(ethUri)) {
        await launchUrl(ethUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(metamaskUniversal)) {
        await launchUrl(metamaskUniversal,
            mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    _openUniswapWrap();
  }

  Future<void> _openUniswapWrap() async {
    final uri = Uri.parse(
      'https://app.uniswap.org/swap?chain=${WalletService.localBaseFork ? 'base' : 'base_sepolia'}&outputCurrency=${WalletService.activeWethContract}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showAquaPoolModal(BuildContext context, AppState state) {
    final proofHashController = TextEditingController();
    Map<String, dynamic>? verifiedProof;
    String? proofError;
    bool isVerifying = false;
    bool isAquaActionPending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Future<void> runAquaAction(
              Future<void> Function() action,
            ) async {
              setModalState(() {
                isAquaActionPending = true;
                proofError = null;
              });
              try {
                await action();
              } catch (error) {
                proofError = error.toString();
              } finally {
                if (modalCtx.mounted) {
                  setModalState(() {
                    isAquaActionPending = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF112238),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(Icons.waves,
                                  color: Color(0xFF38BDF8), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1inch Aqua Liquidity Pool',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Self-Custodial SwapVM Maker Order',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: const Color(0xFF8E95A8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          onPressed: () {
                            if (Navigator.of(modalCtx).canPop()) {
                              Navigator.of(modalCtx).pop();
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Card 1: Docked Liquidity Breakdown
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151924),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF22293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Verified Active Aqua Liquidity',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8E95A8),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: state.activeAquaStrategies.isEmpty
                                      ? const Color(0xFF10131C)
                                      : const Color(0xFF0C241B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: state.activeAquaStrategies.isEmpty
                                        ? const Color(0xFF8E95A8)
                                        : const Color(0xFF00E599),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  state.activeAquaStrategies.isEmpty
                                      ? 'NO ACTIVE STRATEGY'
                                      : 'ACTIVE · ON-CHAIN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: state.activeAquaStrategies.isEmpty
                                        ? const Color(0xFF8E95A8)
                                        : const Color(0xFF00E599),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${state.aquaTotalLiquidityUsd.toStringAsFixed(2)}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (state.aquaDockedStrategyValueUsd > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Saved docked strategy value: \$${state.aquaDockedStrategyValueUsd.toStringAsFixed(2)} · not active liquidity',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10131C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'WETH Share',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: const Color(0xFF8E95A8)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${state.aquaWethLiquidity.toStringAsFixed(4)} WETH',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10131C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'USDC Share',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: const Color(0xFF8E95A8)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '\$${state.aquaUsdcLiquidity.toStringAsFixed(2)} USDC',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Approvals are signed as part of the strategy activation.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151924),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF22293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Token approvals are requested during Sign & Activate. Aqua records virtual balances; tokens stay in your wallet and are pulled only when a permitted taker executes a fill.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No separate WETH approval action is needed here.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF8E95A8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Verified transaction proof and strategy lifecycle.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151924),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF22293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Aqua strategies',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Each card is a separate strategy. Shipped strategies are active; docking cancels that strategy allocation. Editing a shipped strategy docks it first, then lets you ship a replacement.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF8E95A8),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (state.aquaStrategies.isEmpty)
                            Text(
                              'No Aqua strategy saved for this wallet yet.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                          ...state.aquaStrategies.map((strategy) {
                            final strategyHash =
                                strategy['strategyHash']?.toString() ?? '';
                            final shipHash =
                                strategy['shipTxHash']?.toString() ?? '';
                            final dockHash =
                                strategy['dockTxHash']?.toString() ?? '';
                            final status =
                                strategy['status']?.toString() ?? 'unknown';
                            final isDocked = status == 'docked';
                            final isPendingDock = status == 'dock_pending';
                            final isActive = status == 'active';
                            final shipEvents =
                                (strategy['proofEvents'] as List<dynamic>? ??
                                        const [])
                                    .map((event) =>
                                        (event as Map)['name'].toString())
                                    .toList();
                            final dockEvents = (strategy['dockProofEvents']
                                        as List<dynamic>? ??
                                    const [])
                                .map((event) =>
                                    (event as Map)['name'].toString())
                                .toList();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10131C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF283044),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Strategy ${strategyHash.length > 12 ? '${strategyHash.substring(0, 8)}…${strategyHash.substring(strategyHash.length - 4)}' : strategyHash}',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        isDocked
                                            ? 'CANCELLED'
                                            : status.toUpperCase(),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isDocked
                                              ? const Color(0xFF8E95A8)
                                              : status == 'active'
                                                  ? const Color(0xFF00E599)
                                                  : AppTheme.accentRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (shipHash.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _copyToClipboard(
                                        shipHash,
                                        'Aqua ship transaction',
                                      ),
                                      child: Text(
                                        'Ship tx: $shipHash',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: const Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (dockHash.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dock tx: $dockHash',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ],
                                  if (shipEvents.isNotEmpty ||
                                      dockEvents.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Verified Aqua events: ${[
                                        ...shipEvents,
                                        ...dockEvents
                                      ].join(', ')}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF00E599),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Strategy value: \$${state.aquaStrategyLiquidityUsd(strategy).toStringAsFixed(2)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (shipHash.isNotEmpty)
                                        OutlinedButton(
                                          onPressed: isAquaActionPending
                                              ? null
                                              : () => runAquaAction(
                                                    () => state
                                                        .verifyAquaStrategy(
                                                      strategyHash,
                                                    ),
                                                  ),
                                          child: const Text('Verify Shipped'),
                                        ),
                                      if (status == 'active' || isPendingDock)
                                        OutlinedButton(
                                          onPressed: isAquaActionPending
                                              ? null
                                              : () => runAquaAction(() async {
                                                    if (isPendingDock &&
                                                        dockHash.isNotEmpty) {
                                                      await state
                                                          .verifyAquaStrategy(
                                                        strategyHash,
                                                        verifyDock: true,
                                                      );
                                                    } else {
                                                      await WalletService
                                                          .ensureAppKitSession(
                                                              context);
                                                      await state
                                                          .dockAquaStrategy(
                                                        strategyHash,
                                                      );
                                                    }
                                                  }),
                                          child: Text(
                                            isPendingDock
                                                ? 'Verify Cancel'
                                                : 'Cancel Strategy',
                                          ),
                                        ),
                                      if (isActive || isDocked)
                                        OutlinedButton(
                                          onPressed: isAquaActionPending
                                              ? null
                                              : () => runAquaAction(
                                                    () => _editAquaStrategy(
                                                      pageContext: context,
                                                      modalContext: modalCtx,
                                                      state: state,
                                                      strategy: strategy,
                                                    ),
                                                  ),
                                          child: const Text('Edit Strategy'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Color(0xFF283044), height: 20),
                          Text(
                            'Verify any Aqua transaction',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: proofHashController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Paste transaction hash (0x...)',
                              hintStyle: const TextStyle(
                                color: Color(0xFF687086),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF10131C),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isVerifying
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isVerifying = true;
                                        proofError = null;
                                        verifiedProof = null;
                                      });
                                      try {
                                        final proof = await state
                                            .verifyAquaTransactionHash(
                                          proofHashController.text,
                                        );
                                        if (modalCtx.mounted) {
                                          setModalState(() {
                                            verifiedProof = proof;
                                            isVerifying = false;
                                          });
                                        }
                                      } catch (error) {
                                        if (modalCtx.mounted) {
                                          setModalState(() {
                                            proofError = error.toString();
                                            isVerifying = false;
                                          });
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.verified_outlined),
                              label: Text(
                                isVerifying
                                    ? 'Checking ${WalletService.activeNetworkName} receipt…'
                                    : 'Verify transaction receipt',
                              ),
                            ),
                          ),
                          if (verifiedProof != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'CONFIRMED ON ${WalletService.activeNetworkName.toUpperCase()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00E599),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: (verifiedProof!['events']
                                          as List<dynamic>? ??
                                      const [])
                                  .map((event) => Chip(
                                        label: Text(
                                          (event as Map)['name'].toString(),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ))
                                  .toList(),
                            ),
                          ],
                          if (proofError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              proofError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Reconfigure Strategy Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          if (Navigator.of(modalCtx).canPop()) {
                            Navigator.of(modalCtx).pop();
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const CreateStrategyScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2C3955)),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Configure 1inch Aqua Strategy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(proofHashController.dispose);
  }

  void _showWrapModal(BuildContext context, AppState state, double currentEth) {
    double defaultAmount =
        (currentEth > 0.02 ? 0.02 : (currentEth * 0.8)).clamp(0.001, 1000.0);
    final controller =
        TextEditingController(text: defaultAmount.toStringAsFixed(3));
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final parsedAmt = double.tryParse(controller.text) ?? 0.0;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF182338),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt,
                                color: Color(0xFF38BDF8), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Wrap ETH to WETH',
                            style: GoogleFonts.outfit(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                        onPressed: () {
                          if (Navigator.of(modalCtx).canPop()) {
                            Navigator.of(modalCtx).pop();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Wrap native Base Sepolia ETH into canonical WETH (1:1 with zero slippage) to use in 1inch Aqua market making.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF8E95A8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Conversion Input Box (ETH)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151924),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF22293B)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'You Pay (ETH)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                            Text(
                              'Available: ${currentEth.toStringAsFixed(4)} ETH',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00E599),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF202738),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const TokenIcon(symbol: 'ETH', size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ETH',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick Tap Amount Chips
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPresetChip('0.01 ETH', () {
                        controller.text = '0.010';
                        setModalState(() {});
                      }),
                      _buildPresetChip('0.02 ETH', () {
                        controller.text = '0.020';
                        setModalState(() {});
                      }),
                      _buildPresetChip('0.05 ETH', () {
                        controller.text = '0.050';
                        setModalState(() {});
                      }),
                      _buildPresetChip('MAX', () {
                        final maxSafe =
                            (currentEth - 0.005).clamp(0.001, 100.0);
                        controller.text = maxSafe.toStringAsFixed(3);
                        setModalState(() {});
                      }, isHighlighted: true),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Receive Output Box (WETH)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151924),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF22293B)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You Receive (1:1 Ratio)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${parsedAmt.toStringAsFixed(3)} WETH',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A263D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF38BDF8), width: 1),
                          ),
                          child: Row(
                            children: [
                              const TokenIcon(symbol: 'WETH', size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'WETH',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Action Button 1: Sign in MetaMask
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);
                              final amt =
                                  double.tryParse(controller.text) ?? 0.02;
                              await _dispatchMetaMaskWrap(amt);
                              await state.recordWrapTransaction(amt);
                              if (context.mounted) {
                                if (Navigator.of(modalCtx).canPop()) {
                                  Navigator.of(modalCtx).pop();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF0C241B),
                                    duration: const Duration(seconds: 4),
                                    content: Text(
                                      'Dispatched $amt ETH wrap to MetaMask on Base Sepolia! WETH balance will update automatically.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF00E599),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              size: 18, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Sign & Wrap in MetaMask',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Alternate Buttons: Open Uniswap / Instant Testnet Simulation
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (Navigator.of(modalCtx).canPop()) {
                              Navigator.of(modalCtx).pop();
                            }
                            _openUniswapWrap();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF282F40)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            'Open Uniswap',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final amt =
                                double.tryParse(controller.text) ?? 0.02;
                            state.recordWrapTransaction(amt);
                            if (Navigator.of(modalCtx).canPop()) {
                              Navigator.of(modalCtx).pop();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF0C241B),
                                content: Text(
                                  'Wrapped +$amt WETH on Base Sepolia!',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF00E599),
                                  ),
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00E599)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            'Instant Confirm (Demo)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00E599),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap,
      {bool isHighlighted = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B202E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF38BDF8)
                : const Color(0xFF283044),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            color: isHighlighted ? const Color(0xFF38BDF8) : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Resolve assets with fallbacks
    final ethAsset = state.walletAssets.firstWhere(
      (a) => a.symbol == 'ETH',
      orElse: () => WalletAsset(
        symbol: 'ETH',
        name: 'Ethereum (Gas)',
        contractAddress: 'Native Asset',
        decimals: 18,
        balance: 0,
        usdPrice: 0,
      ),
    );

    final usdcAsset = state.walletAssets.firstWhere(
      (a) => a.symbol == 'USDC',
      orElse: () => WalletAsset(
        symbol: 'USDC',
        name: 'USD Coin (Circle)',
        contractAddress: WalletService.activeUsdcContract,
        decimals: 6,
        balance: 0,
        usdPrice: 1.00,
      ),
    );

    final wethAsset = state.walletAssets.firstWhere(
      (a) => a.symbol == 'WETH',
      orElse: () => WalletAsset(
        symbol: 'WETH',
        name: 'Wrapped Ether (1inch)',
        contractAddress: WalletService.activeWethContract,
        decimals: 18,
        balance: 0,
        usdPrice: state.ethSpotPrice,
      ),
    );
    final portfolioHistory =
        state.portfolioSnapshots.map((snapshot) => snapshot.totalUsd).toList();
    final portfolioChange = state.portfolioChangePercent;

    return Container(
      color: Colors.black, // Pure pitch black OLED background
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header: Notification Bell ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF141722),
                        content: Text(
                          'Check your Aqua strategy and transaction activity here.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF11141C),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF1F2433), width: 1),
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── Card 1: Total Portfolio (Squarish Proportion) ───────────────
            Container(
              height: 205,
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF161924),
                    Color(0xFF0F1118),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Portfolio',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E95A8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    !state.isConnected
                        ? 'Connect wallet'
                        : state.walletAssetsError != null &&
                                state.walletAssets.isEmpty
                            ? 'Unavailable'
                            : '\$${state.totalPortfolioUsd.toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    portfolioChange == null
                        ? 'Balance history collecting'
                        : '${portfolioChange >= 0 ? '+' : ''}${portfolioChange.toStringAsFixed(2)}% balance change',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: portfolioChange == null
                          ? const Color(0xFF8E95A8)
                          : portfolioChange >= 0
                              ? const Color(0xFF00E599)
                              : AppTheme.accentRed,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: SparklineChart(
                      data: portfolioHistory,
                      height: 48,
                      width: double.infinity,
                      lineColor: Colors.white,
                      showFill: true,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── Card: Connected Wallet Assets (Base Sepolia) ────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Network Indicator & Sync Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Wallet Assets',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C241B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00E599)
                                    .withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00E599),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  WalletService.activeNetworkName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF00E599),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: state.isLoadingAssets
                            ? null
                            : () => state.refreshWalletAssets(),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: state.isLoadingAssets
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E599),
                                  ),
                                )
                              : const Icon(
                                  Icons.sync,
                                  size: 18,
                                  color: Color(0xFF38BDF8),
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Asset 1: ETH (Gas)
                  _buildTokenRow(
                    iconWidget: const TokenIcon(symbol: 'ETH'),
                    symbol: 'ETH',
                    subtitle: 'Native Gas',
                    balanceText: state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? '-- ETH'
                        : '${ethAsset.balance.toStringAsFixed(4)} ETH',
                    usdText: 'Gas-only · excluded from token total',
                    onCopy: null,
                    trailingAction: null,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFF1B202D), height: 1),
                  ),

                  // Asset 2: Circle USDC
                  _buildTokenRow(
                    iconWidget: const TokenIcon(symbol: 'USDC'),
                    symbol: 'USDC',
                    subtitle: 'Circle Testnet',
                    balanceText: state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? '-- USDC'
                        : '${usdcAsset.balance.toStringAsFixed(2)} USDC',
                    usdText: state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? 'Balance unavailable'
                        : '\$${usdcAsset.balance.toStringAsFixed(2)} est.',
                    onCopy: () => _copyToClipboard(
                      WalletService.activeUsdcContract,
                      'Circle USDC Contract Address',
                    ),
                    trailingAction: null,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFF1B202D), height: 1),
                  ),

                  // Asset 3: Wrapped Ether (WETH) with Wrap Shortcut
                  _buildTokenRow(
                    iconWidget: const TokenIcon(symbol: 'WETH'),
                    symbol: 'WETH',
                    subtitle: '1inch Aqua LP',
                    balanceText: state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? '-- WETH'
                        : '${wethAsset.balance.toStringAsFixed(4)} WETH',
                    usdText: state.walletAssetsError != null &&
                            state.walletAssets.isEmpty
                        ? 'Balance unavailable'
                        : '≈ \$${(wethAsset.balance * state.ethSpotPrice).toStringAsFixed(2)} est.',
                    onCopy: () => _copyToClipboard(
                      WalletService.activeWethContract,
                      'WETH Contract Address',
                    ),
                    trailingAction: InkWell(
                      onTap: () =>
                          _showWrapModal(context, state, ethAsset.balance),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10283E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt,
                                size: 12, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 3),
                            Text(
                              'Wrap',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Primary Wrap Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showWrapModal(context, state, ethAsset.balance),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2538),
                        foregroundColor: const Color(0xFF38BDF8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFF2C3955)),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(
                        'Wrap ETH → WETH (Sign in MetaMask)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Secondary Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(
                            WalletService.activeUsdcContract,
                            'USDC Contract (Paste in MetaMask Import Tokens)',
                          ),
                          icon: const Icon(Icons.copy,
                              size: 12, color: Colors.white70),
                          label: Text(
                            'Copy USDC Address',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF282E40)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isLoadingAssets
                              ? null
                              : () => state.refreshWalletAssets(),
                          icon: const Icon(Icons.refresh,
                              size: 13, color: Color(0xFF38BDF8)),
                          label: Text(
                            'Refresh balances',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF282E40)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.walletAssetsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.walletAssetsError!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── Card 2: Active Position (1inch Aqua Liquidity Pool) ─────────
            InkWell(
              onTap: () {
                if (state.aquaStrategies.isNotEmpty) {
                  _showAquaPoolModal(context, state);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CreateStrategyScreen()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFF1D212E),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              state.aquaStrategies.isNotEmpty
                                  ? 'Aqua Strategies'
                                  : 'Aqua Strategy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8E95A8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF122238),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '1inch Aqua',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: state.isStrategyActive
                                ? const Color(0xFF0D281E)
                                : const Color(0xFF10131C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: state.isStrategyActive
                                  ? const Color(0xFF00E599)
                                      .withValues(alpha: 0.35)
                                  : const Color(0xFF8E95A8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            state.isStrategyActive
                                ? 'Active'
                                : state.aquaStrategies.isNotEmpty
                                    ? 'No active strategy'
                                    : 'Not created',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: state.isStrategyActive
                                  ? const Color(0xFF00E599)
                                  : const Color(0xFF8E95A8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'WETH / USDC',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.isStrategyActive
                          ? '\$${state.activePositionUsd.toStringAsFixed(2)}'
                          : 'No active position',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            state.isStrategyActive
                                ? '${state.activeAllocationPercent}% allocation · SwapVM'
                                : state.aquaStrategies.isNotEmpty
                                    ? 'Manage, verify, or dock a saved strategy'
                                    : 'Create a strategy to allocate Aqua liquidity',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.aquaStrategies.isNotEmpty
                                  ? 'Manage'
                                  : 'Create Strategy',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right,
                                size: 14, color: Color(0xFF38BDF8)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildAquaStrategiesSection(context, state),
            const SizedBox(height: 14),

            // ─── Card 4: Verified Aqua Fees ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF12141C),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1D212E), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verified Aqua fees (30d)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E95A8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Not tracked yet',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No verified fee events are available. Strategy value is not earnings.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF8E95A8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenRow({
    required Widget iconWidget,
    required String symbol,
    required String subtitle,
    required String balanceText,
    required String usdText,
    required VoidCallback? onCopy,
    required Widget? trailingAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (onCopy != null) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: onCopy,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.copy,
                                      size: 12, color: Color(0xFF8E95A8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          balanceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          usdText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF8E95A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (trailingAction != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: trailingAction,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
