import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';

class StrategyReadyScreen extends StatelessWidget {
  const StrategyReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final signing = state.aquaTransactionStatus != AquaTransactionStatus.idle &&
        state.aquaTransactionStatus != AquaTransactionStatus.complete &&
        state.aquaTransactionStatus != AquaTransactionStatus.failed;
    final complete =
        state.aquaTransactionStatus == AquaTransactionStatus.complete;
    final failed = state.aquaTransactionStatus == AquaTransactionStatus.failed;

    return Scaffold(
      backgroundColor: Colors.black, // Pure pitch black OLED
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // ─── Glowing Circular Checkmark Badge ───────────────────────────
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF091F18),
                  border: Border.all(
                    color: const Color(0xFF00E599),
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E599).withValues(alpha: 0.45),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 34),

              // ─── Title ──────────────────────────────────────────────────────
              Text(
                complete ? 'Strategy Ready!' : 'Review Strategy',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 8),

              // ─── Subtitle ───────────────────────────────────────────────────
              Text(
                complete
                    ? 'Your market making strategy\nis now active.'
                    : 'Review the details, then sign each\ntransaction in MetaMask.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8E95A8),
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 38),

              // ─── Summary Card ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(26),
                  border:
                      Border.all(color: const Color(0xFF1D212E), width: 1.1),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      label: 'Amount',
                      value: '\$${state.strategyAmount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 18),
                    _buildSummaryRow(
                      label: 'Allocation',
                      value: '100% to 1inch Aqua',
                    ),
                    const SizedBox(height: 18),
                    _buildSummaryRow(
                      label: 'Status',
                      value: complete
                          ? 'Active'
                          : failed
                              ? 'Failed'
                              : signing
                                  ? 'In progress'
                                  : 'Ready to sign',
                      isStatus: true,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              if (!complete) ...[
                Text(
                  failed
                      ? (state.aquaTransactionError ??
                          'Transaction failed. Tap retry.')
                      : signing
                          ? _statusText(state.aquaTransactionStatus)
                          : 'No transaction has been signed yet.',
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.4,
                    color: signing
                        ? const Color(0xFF38BDF8)
                        : failed
                            ? Colors.redAccent
                            : const Color(0xFF8E95A8),
                  ),
                ),
                if (state.aquaLastTransactionHash != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Submitted: ${state.aquaLastTransactionHash!.substring(0, 10)}...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF687086),
                    ),
                  ),
                ],
                if (state.aquaVerificationStatus != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.aquaVerificationStatus!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF00E599),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              // ─── Done Silvery/White Pill Stadium Button ─────────────────────
              InkWell(
                onTap: signing
                    ? null
                    : () async {
                        final appState = context.read<AppState>();
                        if (complete) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          return;
                        }
                        if (failed) {
                          appState.resetAquaTransaction();
                        }
                        try {
                          await appState.activateStrategyWithWallet(context);
                        } catch (_) {
                          // Keep the failure visible inline for retry.
                          return;
                        }
                        if (!context.mounted) return;

                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEDEDED), Color(0xFFD0D4DC)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      complete ? 'Done' : 'Sign & Activate',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(AquaTransactionStatus status) {
    switch (status) {
      case AquaTransactionStatus.preparing:
        return 'Preparing official 1inch Aqua transaction...';
      case AquaTransactionStatus.signingWethApproval:
        return 'Sign WETH approval in MetaMask.';
      case AquaTransactionStatus.confirmingWethApproval:
        return 'MetaMask closed after WETH approval. Waiting for the local fork receipt...';
      case AquaTransactionStatus.signingUsdcApproval:
        return 'Sign USDC approval in MetaMask.';
      case AquaTransactionStatus.confirmingUsdcApproval:
        return 'MetaMask closed after USDC approval. Waiting for the local fork receipt...';
      case AquaTransactionStatus.signingShip:
        return 'Sign Aqua ship transaction in MetaMask.';
      case AquaTransactionStatus.confirmingShip:
        return 'MetaMask closed after Aqua ship. Waiting for the local fork receipt...';
      case AquaTransactionStatus.signingDock:
        return 'Sign the Aqua dock transaction in MetaMask.';
      case AquaTransactionStatus.confirmingDock:
        return 'Dock submitted. Waiting for its on-chain event...';
      case AquaTransactionStatus.complete:
        return 'All Aqua transactions confirmed.';
      case AquaTransactionStatus.failed:
        return 'Transaction failed. Review the error and retry.';
      case AquaTransactionStatus.idle:
        return 'No transaction has been signed yet.';
    }
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isStatus = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8E95A8),
          ),
        ),
        Text(
          value,
          style: isStatus
              ? GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00E599),
                )
              : GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
        ),
      ],
    );
  }
}
