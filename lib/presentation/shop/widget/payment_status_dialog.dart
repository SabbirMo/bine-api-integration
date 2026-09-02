import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:binetatour/data/models/payment_status_model.dart';
import 'package:binetatour/providers/order_provider.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';

class PaymentStatusDialog extends StatefulWidget {
  final int transactionId;
  final String providerName; // "Orange Money" or "Wave"
  final String? qrCodeBase64;
  final String? deepLink;
  final Map<String, dynamic>? deepLinks;
  final String? message;
  final int validitySeconds;
  final Function(PaymentStatusModel statusModel) onPaymentSuccess;
  final VoidCallback? onPaymentFailed;

  const PaymentStatusDialog({
    super.key,
    required this.transactionId,
    required this.providerName,
    this.qrCodeBase64,
    this.deepLink,
    this.deepLinks,
    this.message,
    this.validitySeconds = 300,
    required this.onPaymentSuccess,
    this.onPaymentFailed,
  });

  /// Static helper to display the popup dialog easily
  static Future<void> show({
    required BuildContext context,
    required int transactionId,
    required String providerName,
    String? qrCodeBase64,
    String? deepLink,
    Map<String, dynamic>? deepLinks,
    String? message,
    int validitySeconds = 300,
    required Function(PaymentStatusModel statusModel) onPaymentSuccess,
    VoidCallback? onPaymentFailed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentStatusDialog(
        transactionId: transactionId,
        providerName: providerName,
        qrCodeBase64: qrCodeBase64,
        deepLink: deepLink,
        deepLinks: deepLinks,
        message: message,
        validitySeconds: validitySeconds,
        onPaymentSuccess: onPaymentSuccess,
        onPaymentFailed: onPaymentFailed,
      ),
    );
  }

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  late int _remainingSeconds;
  Uint8List? _qrBytes;
  bool _isSuccess = false;
  bool _isFailed = false;
  PaymentStatusModel? _currentStatus;
  bool _isManualChecking = false;

  bool get _isOrange =>
      widget.providerName.toLowerCase().contains("orange");

  @override
  void initState() {
    super.initState();
    _remainingSeconds =
        widget.validitySeconds > 0 ? widget.validitySeconds : 300;

    // Decode QR base64 if present
    if (widget.qrCodeBase64 != null && widget.qrCodeBase64!.isNotEmpty) {
      try {
        final cleanBase64 =
            widget.qrCodeBase64!.replaceAll(RegExp(r'\s+'), '');
        _qrBytes = base64Decode(cleanBase64);
      } catch (e) {
        _qrBytes = null;
      }
    }

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _stopPolling();
        setState(() {
          _isFailed = true;
        });
      }
    });

    // Start live status polling every 3 seconds
    _startPolling();

    // Check status immediately on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkStatus();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkStatus({bool manual = false}) async {
    if (!mounted || _isSuccess || _isFailed) return;

    if (manual) {
      setState(() => _isManualChecking = true);
    }

    final orderProvider = context.read<OrderProvider>();
    final result = await orderProvider.checkPaymentStatus(widget.transactionId);

    if (!mounted) return;

    if (manual) {
      setState(() => _isManualChecking = false);
    }

    if (result != null) {
      setState(() {
        _currentStatus = result;
      });

      if (result.isSuccess) {
        _stopPolling();
        _countdownTimer?.cancel();
        setState(() {
          _isSuccess = true;
        });
        // Auto trigger success callback after short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            widget.onPaymentSuccess(result);
          }
        });
      } else if (result.isFailed) {
        _stopPolling();
        _countdownTimer?.cancel();
        setState(() {
          _isFailed = true;
        });
        widget.onPaymentFailed?.call();
      }
    }
  }

  Future<void> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    bool launched = false;

    // 1️⃣ Try launching directly in native app
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      launched = false;
    }

    // 2️⃣ Fallback: open in external web browser
    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }
    }

    // 3️⃣ Fallback: platformDefault
    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d'ouvrir l'application ou la page de paiement",
          ),
        ),
      );
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor =
        _isOrange ? const Color(0xFFFF6900) : const Color(0xFF1EA6D6);
    final logoAsset =
        _isOrange ? "assets/images/money.png" : "assets/images/wave.png";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          logoAsset,
                          height: 28,
                          width: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.payment,
                            color: themeColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.providerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "Transaction #${widget.transactionId}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!_isSuccess)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const Divider(height: 24),

              // Status Views
              if (_isSuccess)
                _buildSuccessView(themeColor)
              else if (_isFailed)
                _buildFailedView()
              else
                _buildPendingView(themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingView(Color themeColor) {
    final String? paymentUrl =
        (widget.deepLinks?['OM']?.toString().isNotEmpty == true)
            ? widget.deepLinks!['OM'].toString()
            : (widget.deepLink?.isNotEmpty == true
                ? widget.deepLink
                : widget.deepLinks?['MAXIT']?.toString());

    final buttonLabel = _isOrange
        ? "Payer avec Orange Money"
        : "Payer avec ${widget.providerName}";

    return Column(
      children: [
        // Countdown Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 6),
              Text(
                "Expire dans: ${_formatDuration(_remainingSeconds)}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // QR Code if available
        if (_qrBytes != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _qrBytes!,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message ??
                "Scannez ce QR code avec votre application pour payer.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // App / Web Launch Button
        if (paymentUrl != null && paymentUrl.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchPaymentUrl(paymentUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Realtime Polling Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const CoolShimmer(
                child: CoolShimmerBone.circle(size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "En attente de confirmation...",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _currentStatus?.status.isNotEmpty == true
                          ? "Statut : ${_currentStatus!.status}"
                          : "Vérification automatique en cours",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Manual Verify Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isManualChecking
                ? null
                : () => _checkStatus(manual: true),
            icon: _isManualChecking
                ? const CoolShimmer(
                    child: CoolShimmerBone.circle(size: 16),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text(
              "Vérifier le paiement",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: themeColor,
              side: BorderSide(color: themeColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(Color themeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF81C784), width: 2),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFF2E7D32),
            size: 64,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Paiement Réussi !",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Votre paiement a été validé avec succès.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        if (_currentStatus?.orderNumber.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Commande : ${_currentStatus!.orderNumber}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_currentStatus != null) {
                widget.onPaymentSuccess(_currentStatus!);
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Continuer",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE57373), width: 2),
          ),
          child: const Icon(
            Icons.error_outline,
            color: Color(0xFFC62828),
            size: 64,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Paiement Non Validé",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC62828),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _remainingSeconds == 0
              ? "Le délai de validité du paiement a expiré."
              : "Le paiement n'a pas pu aboutir ou a été annulé.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Fermer"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isFailed = false;
                    _remainingSeconds = widget.validitySeconds > 0
                        ? widget.validitySeconds
                        : 300;
                  });
                  _startPolling();
                  _checkStatus(manual: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6900),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Réessayer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
