import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/sleek_background.dart';
import '../widgets/wallet_brand_logos.dart';
import '../services/wallet_service.dart';
import 'main_nav_screen.dart';

class WalletConnectScreen extends StatefulWidget {
  const WalletConnectScreen({super.key});

  @override
  State<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends State<WalletConnectScreen>
    with WidgetsBindingObserver {
  bool _isConnecting = false;
  String? _selectedWallet;
  ReownAppKitModal? _appKitModal;
  Timer? _connectionTimeout;
  bool _connectionHandled = false;
  bool _navigationStarted = false;

  static const _projectId = String.fromEnvironment(
    'PROJECT_ID',
    defaultValue: '0c9bf0658ee6794b73bbc18599a3c8e9',
  );

  PairingMetadata get _metadata => const PairingMetadata(
        name: 'IdleCash',
        description: 'Self-custodial market making on Base',
        url: 'https://idlecash.app',
        icons: ['https://idlecash.app/icon.png'],
        redirect: Redirect(native: 'idlecash://'),
      );

  Future<void> _initializeWalletKit() async {
    if (_appKitModal != null) return;
    if (_projectId.isEmpty) {
      throw StateError(
        'WalletConnect is not configured. Run with --dart-define=PROJECT_ID=your_reown_project_id.',
      );
    }

    // Aqua uses Base Sepolia by default, or the local Base fork in fork mode.
    // AppKit does not include this test chain in every default network set.
    ReownAppKitModalNetworks.addSupportedNetworks(
      'eip155',
      [
        ReownAppKitModalNetworkInfo(
          name: WalletService.activeNetworkName,
          chainId: WalletService.activeChainId,
          currency: 'ETH',
          rpcUrl: WalletService.activeRpcUrl,
          explorerUrl:
              WalletService.localBaseFork ? '' : 'https://sepolia.basescan.org',
          isTestNetwork: true,
        ),
      ],
    );

    final modal = ReownAppKitModal(
      context: Navigator.of(context, rootNavigator: true).context,
      projectId: _projectId,
      metadata: _metadata,
      disconnectOnDispose: false,
      optionalNamespaces: {
        'eip155': RequiredNamespace.fromJson({
          'chains': [WalletService.activeChainNamespace],
          'methods': NetworkUtils.defaultNetworkMethods['eip155']!.toList(),
          'events': NetworkUtils.defaultNetworkEvents['eip155']!.toList(),
        }),
      },
    );
    modal.onModalConnect.subscribe(_onWalletConnected);
    modal.onModalError.subscribe(_onWalletError);
    await modal.init();
    _appKitModal = modal;
    WalletService.attachAppKitModal(modal);
    if (modal.isConnected) {
      final approvedChains =
          modal.session?.getApprovedChains(namespace: 'eip155') ?? [];
      if (approvedChains.contains(WalletService.activeChainNamespace)) {
        await _onWalletConnected(ModalConnect(modal.session!));
      } else {
        await modal.disconnect();
      }
    }
  }

  Future<void> _onWalletConnected(ModalConnect? event) async {
    final address = event?.session.getAddress('eip155');
    if (address == null || address.isEmpty || !mounted) return;
    if (_connectionHandled) return;
    _connectionHandled = true;
    _connectionTimeout?.cancel();

    try {
      await context.read<AppState>().connectWallet(address, 'WalletConnect');
    } catch (error) {
      _connectionHandled = false;
      _onWalletError(ModalError(error.toString()));
      return;
    }
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _selectedWallet = null;
    });
    if (_appKitModal?.isOpen == true) {
      _appKitModal!.closeModal();
    }
  }

  void _navigateToApp() {
    if (!mounted || _navigationStarted) return;
    _navigationStarted = true;
    // Pop back to the root (OnboardingScreen), then replace it with MainNavScreen.
    // This keeps the navigator history valid (never clears to zero routes).
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavScreen()),
    );
  }

  Future<void> _connectWithWallet(String name, String address) async {
    setState(() {
      _isConnecting = true;
      _selectedWallet = name;
    });
    _connectionHandled = false;
    _connectionTimeout?.cancel();

    try {
      await _initializeWalletKit().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'WalletConnect setup timed out. Check your internet connection and try again.',
        ),
      );
      if (!mounted) return;
      if (_connectionHandled) {
        _navigateToApp();
        return;
      }
      _connectionTimeout = Timer(const Duration(seconds: 45), () {
        if (!mounted || !_isConnecting) return;
        _onWalletError(ModalError(
          'MetaMask did not complete the connection. Return to MetaMask, approve the request, then try again.',
        ));
      });
      await _appKitModal!.openModalView();
      if (_connectionHandled) {
        _navigateToApp();
      }
    } catch (error) {
      if (!mounted) return;
      _onWalletError(ModalError(error.toString()));
    }
  }

  void _onWalletError(ModalError? event) {
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _selectedWallet = null;
    });
    _connectionTimeout?.cancel();
    _connectionHandled = false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(event?.message ?? 'Wallet connection was not completed.'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionTimeout?.cancel();
    final modal = _appKitModal;
    if (modal != null) {
      modal.onModalConnect.unsubscribe(_onWalletConnected);
      modal.onModalError.unsubscribe(_onWalletError);
      // Keep the connected session alive for transaction requests after this
      // screen is removed from the navigation stack.
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final modal = _appKitModal;
    final session = modal?.session;
    if (modal?.isConnected == true && session != null) {
      unawaited(_onWalletConnected(ModalConnect(session)));
    }
  }

  Future<void> _showWalletSelectionSheet() async {
    final wallet = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: const Color(0xFF10131B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Wallet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect to ${WalletService.activeNetworkName} without surrendering custody.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildWalletOption(
                    name: 'MetaMask',
                    address: '0x71C839...39Ac',
                    logo: const MetaMaskLogo(size: 28),
                    onTap: () {
                      Navigator.of(ctx).pop({
                        'name': 'MetaMask',
                        'address': '0x71C839...39Ac',
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildWalletOption(
                    name: 'Coinbase Wallet',
                    address: '0x84DB21...B21F',
                    logo: const CoinbaseWalletLogo(size: 28),
                    onTap: () {
                      Navigator.of(ctx).pop({
                        'name': 'Coinbase',
                        'address': '0x84DB21...B21F',
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildWalletOption(
                    name: 'WalletConnect',
                    address: '0x39E581...5810',
                    logo: const WalletConnectLogo(size: 28),
                    onTap: () {
                      Navigator.of(ctx).pop({
                        'name': 'WalletConnect',
                        'address': '0x39E581...5810',
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildWalletOption(
                    name: 'Self-Custody Active LP',
                    address: '0x12A49F...9F40 (Base)',
                    logo: const RainbowWalletLogo(size: 28),
                    onTap: () {
                      Navigator.of(ctx).pop({
                        'name': 'Self-Custody',
                        'address': '0x12A49F4032d8495E4cbB98592E8b4F3a9c79F40',
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildWalletOption(
                    name: 'Generate New Base Wallet',
                    address: 'Creates fresh on-chain self-custody key',
                    logo: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E2638),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_moderator_outlined,
                          color: AppTheme.accentCyan, size: 16),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop({
                        'name': 'Base Key',
                        'address': WalletService.generateRealEvmAddress(),
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || wallet == null) return;
    await _connectWithWallet(wallet['name']!, wallet['address']!);
  }

  Widget _buildWalletOption({
    required String name,
    required String address,
    required Widget logo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    address,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SleekBackground(
        backgroundImage: 'assets/images/wallet_con_page.jpg',
        overlayOpacity: 0.1, // Clean, zero darkening over the metallic logo
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Clear space below the metallic logo in background (moved up to close gap)
                const SizedBox(height: 200),

                // Title matching design screenshot
                Text(
                  'Connect Your Wallet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.7,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Secure. Non-Custodial. Always Yours.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: -0.1,
                  ),
                ),

                if (_projectId.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'WalletConnect needs a Reown project ID.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.amberAccent.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Run with --dart-define=PROJECT_ID=your_project_id',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],

                const SizedBox(height: 36),

                // Sleek horizontal wallet card with real logos
                InkWell(
                  onTap: _showWalletSelectionSheet,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141722).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF242A3B),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Real MetaMask Fox Logo
                        _buildLogoCircle(
                          child: const MetaMaskLogo(size: 24),
                          onTap: () =>
                              _connectWithWallet('MetaMask', '0x71C839...39Ac'),
                        ),
                        // 2. Real Coinbase Wallet Logo
                        _buildLogoCircle(
                          child: const CoinbaseWalletLogo(size: 34),
                          onTap: () =>
                              _connectWithWallet('Coinbase', '0x84DB21...B21F'),
                        ),
                        // 3. Real WalletConnect Logo
                        _buildLogoCircle(
                          child: const WalletConnectLogo(size: 34),
                          onTap: () => _connectWithWallet(
                              'WalletConnect', '0x39E581...5810'),
                        ),
                        // 4. Clean More (...) Circle
                        _buildLogoCircle(
                          child: const Icon(Icons.more_horiz,
                              color: Colors.white70, size: 20),
                          onTap: _showWalletSelectionSheet,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Connect Wallet White Pill Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _showWalletSelectionSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    child: _isConnecting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Connecting $_selectedWallet...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          )
                        : const Text('Connect Wallet'),
                  ),
                ),

                const SizedBox(height: 32),

                // Footer: Your keys. Your control.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your keys. Your control.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoCircle({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1B202D),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF2C3449),
            width: 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
