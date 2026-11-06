import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idlecash_frontend/screens/main_nav_screen.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../widgets/token_icon.dart';
import 'strategy_ready_screen.dart';

class CreateStrategyScreen extends StatelessWidget {
  const CreateStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.black, // Pure pitch black OLED
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header: Back Arrow + Centered Title ────────────────────────
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const MainNavScreen()),
                        );
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Create Strategy',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Optical center balance
                ],
              ),

              const SizedBox(height: 8),

              // ─── Subtitle ───────────────────────────────────────────────────
              Center(
                child: Text(
                  'Configure your market making strategy for WETH/USDC.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF8E95A8),
                    height: 1.45,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ─── Token Selector Card (Overlapping Icons) ────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: const Color(0xFF1D212E), width: 1.1),
                ),
                child: Row(
                  children: [
                    // Overlapping ETH + USDC Token Icons
                    const SizedBox(
                      width: 52,
                      height: 32,
                      child: Stack(
                        children: [
                          // ETH Token
                          Positioned(
                            left: 0,
                            top: 0,
                            child: TokenIcon(symbol: 'ETH', size: 30),
                          ),
                          // USDC Token (overlapping)
                          Positioned(
                            left: 20,
                            top: 0,
                            child: TokenIcon(symbol: 'USDC', size: 30),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WETH / USDC',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF8E95A8),
                      size: 22,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ─── Section Header: Strategy Amount ────────────────────────────
              Text(
                'Strategy Amount',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E95A8),
                ),
              ),

              const SizedBox(height: 10),

              // ─── Card 1: Strategy Amount & Slider ───────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: const Color(0xFF1D212E), width: 1.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${state.strategyAmount.toInt()}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '≈ ${state.strategyWeth.toStringAsFixed(4)} WETH + '
                      '${state.newStrategyUsdcAmount.toStringAsFixed(2)} USDC',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Slider with Glowing Blue/Cyan Thumb
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF38BDF8),
                        inactiveTrackColor: const Color(0xFF222838),
                        thumbColor: const Color(0xFF38BDF8),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 9),
                        overlayColor:
                            const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: state.strategyAmount,
                        min: 50.0,
                        max: 2000.0,
                        divisions: 39,
                        onChanged: (val) {
                          context.read<AppState>().updateStrategyAmount(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Card 2: Aqua allocation ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: const Color(0xFF1D212E), width: 1.1),
                ),
                child: Row(
                  children: [
                    const TokenIcon(symbol: 'WETH', size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100% to 1inch Aqua',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'WETH / USDC strategy allocation',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${state.aquaStrategyUsd.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ─── Next -> Silvery/White Pill Stadium Button ──────────────────
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StrategyReadyScreen(),
                    ),
                  );
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          size: 18, color: Colors.black),
                    ],
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
}
