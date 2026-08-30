import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/scanner_overlay.dart';

const _accentTeal = Color(0xFF2DD4BF);
const _accentIndigo = Color(0xFF6366F1);
const _surfaceDark = Color(0xFF14132B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final ProductService _productService = ProductService();
  final ImagePicker _imagePicker = ImagePicker();

  // The item currently being assembled. All three parts are collected
  // before a single combined upload is sent.
  ProductModel? _draftDetails;
  File? _draftProductPhoto;
  File? _draftBarcodePhoto;

  bool _isFetchingDetails = false;
  bool _isUploading = false;
  String? _lastBarcode;
  bool _cameraPermissionDenied = false;

  // null means "Auto" — try every source in priority order.
  ProductSource? _selectedSource;

  // The live scanner keeps detecting continuously until a barcode has been
  // captured for the current item; tapping "Rescan" clears it to reactivate.
  bool get _isScanningForBarcode => _draftDetails == null;

  bool get _isItemComplete =>
      _draftDetails != null && _draftProductPhoto != null && _draftBarcodePhoto != null;

  int get _completedSteps =>
      (_draftDetails != null ? 1 : 0) +
      (_draftProductPhoto != null ? 1 : 0) +
      (_draftBarcodePhoto != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _cameraPermissionDenied = !status.isGranted);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanningForBarcode || _isFetchingDetails) return;
    final code = capture.barcodes.firstOrNullRawValue;
    if (code == null || code.isEmpty || code == _lastBarcode) return;

    setState(() {
      _isFetchingDetails = true;
      _lastBarcode = code;
    });

    try {
      final product = await _productService.fetchProduct(code, source: _selectedSource);
      if (!mounted) return;
      setState(() => _draftDetails = product);
      _showSnack('Captured details for "${product.name}" via ${product.source.label}');
    } on ProductNotFoundException {
      if (!mounted) return;
      _showSnack('No product found for barcode $code in ${_selectedSource?.label ?? "any source"}.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not fetch product details. Check your connection.');
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _startBarcodeScan() {
    setState(() {
      _draftDetails = null;
      _lastBarcode = null;
    });
    _showSnack('Point the camera at the barcode');
  }

  Future<void> _capturePhoto({required bool isBarcodePhoto}) async {
    try {
      final XFile? shot = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (shot == null || !mounted) return;

      setState(() {
        if (isBarcodePhoto) {
          _draftBarcodePhoto = File(shot.path);
        } else {
          _draftProductPhoto = File(shot.path);
        }
      });
    } catch (e) {
      _showSnack('Could not open the camera.');
    }
  }

  Future<void> _uploadItem() async {
    if (!_isItemComplete || _isUploading) return;
    setState(() => _isUploading = true);
    try {
      final ok = await _productService.uploadItem(
        details: _draftDetails!,
        productPhoto: _draftProductPhoto!,
        barcodePhoto: _draftBarcodePhoto!,
      );
      if (!mounted) return;
      if (ok) {
        _showSnack('Item uploaded: ${_draftDetails!.name}');
        setState(() {
          _draftDetails = null;
          _draftProductPhoto = null;
          _draftBarcodePhoto = null;
          _lastBarcode = null;
        });
      } else {
        _showSnack('Upload failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearDraft() {
    setState(() {
      _draftDetails = null;
      _draftProductPhoto = null;
      _draftBarcodePhoto = null;
      _lastBarcode = null;
    });
  }

  Widget _sourceSelector() {
    return PopupMenuButton<ProductSource?>(
      initialValue: _selectedSource,
      color: _surfaceDark,
      tooltip: 'Product data source',
      onSelected: (value) => setState(() => _selectedSource = value),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: null,
          checked: _selectedSource == null,
          child: const Text('Auto (try all)', style: TextStyle(color: Colors.white)),
        ),
        for (final source in ProductSource.values)
          CheckedPopupMenuItem(
            value: source,
            checked: _selectedSource == source,
            child: Text(source.label, style: const TextStyle(color: Colors.white)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore, size: 13, color: _accentTeal),
            const SizedBox(width: 5),
            Text(
              _selectedSource?.label ?? 'Auto',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 55,
              child: _buildScannerSection(),
            ),
            Expanded(
              flex: 45,
              child: _buildActionsSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraPermissionDenied)
            _permissionDeniedView()
          else
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              errorBuilder: (context, error, child) => _scannerErrorView(error),
            ),
          if (!_cameraPermissionDenied) const ScannerOverlay(),
          if (_isFetchingDetails)
            const Positioned(
              top: 16,
              right: 16,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: _accentTeal),
              ),
            ),
          if (_isScanningForBarcode && !_isFetchingDetails)
            Positioned(
              top: 16,
              left: 16,
              child: _pill('Scanning for barcode…', _accentIndigo),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _scannerErrorView(MobileScannerException error) {
    return Container(
      color: _surfaceDark,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Text(
            'Camera error: ${error.errorCode.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _permissionDeniedView() {
    return Container(
      color: _surfaceDark,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Camera permission is required to scan products.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              final status = await Permission.camera.request();
              if (status.isPermanentlyDenied) {
                await openAppSettings();
              } else if (mounted) {
                setState(() => _cameraPermissionDenied = !status.isGranted);
              }
            },
            child: const Text('Grant permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Current item',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($_completedSteps/3 ready)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              const Spacer(),
              _sourceSelector(),
              if (_completedSteps > 0)
                TextButton(
                  onPressed: _isUploading ? null : _clearDraft,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _ItemStepTile(
                    icon: Icons.qr_code_2,
                    label: 'Barcode Details',
                    pendingSubtitle: 'Point the camera at a barcode',
                    busy: _isFetchingDetails,
                    busyLabel: 'Fetching…',
                    captured: _draftDetails != null,
                    actionLabel: _draftDetails != null ? 'Rescan' : 'Scan',
                    onTap: _startBarcodeScan,
                    capturedPreview: _draftDetails == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _draftDetails!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                '${_draftDetails!.brand} · ${_draftDetails!.quantity} · via ${_draftDetails!.source.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                  _ItemStepTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Product Photo',
                    pendingSubtitle: 'Capture a photo of the product',
                    captured: _draftProductPhoto != null,
                    actionLabel: _draftProductPhoto != null ? 'Retake' : 'Capture',
                    onTap: () => _capturePhoto(isBarcodePhoto: false),
                    capturedPreview: _draftProductPhoto == null
                        ? null
                        : _thumbnail(_draftProductPhoto!),
                  ),
                  const SizedBox(height: 8),
                  _ItemStepTile(
                    icon: Icons.crop_free,
                    label: 'Barcode Photo',
                    pendingSubtitle: 'Capture a photo of the barcode / QR',
                    captured: _draftBarcodePhoto != null,
                    actionLabel: _draftBarcodePhoto != null ? 'Retake' : 'Capture',
                    onTap: () => _capturePhoto(isBarcodePhoto: true),
                    capturedPreview: _draftBarcodePhoto == null
                        ? null
                        : _thumbnail(_draftBarcodePhoto!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentTeal,
                foregroundColor: const Color(0xFF0A0A1A),
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isItemComplete && !_isUploading ? _uploadItem : null,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF0A0A1A)),
                    )
                  : Text(_isItemComplete
                      ? 'Upload item'
                      : 'Upload item ($_completedSteps/3 ready)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(File file) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 36, height: 36, fit: BoxFit.cover),
        ),
        const SizedBox(width: 8),
        const Text(
          'Captured',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _ItemStepTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String pendingSubtitle;
  final bool captured;
  final String actionLabel;
  final VoidCallback onTap;
  final Widget? capturedPreview;
  final bool busy;
  final String? busyLabel;

  const _ItemStepTile({
    required this.icon,
    required this.label,
    required this.pendingSubtitle,
    required this.captured,
    required this.actionLabel,
    required this.onTap,
    this.capturedPreview,
    this.busy = false,
    this.busyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: captured
                  ? [
                      _accentTeal.withValues(alpha: 0.18),
                      _accentTeal.withValues(alpha: 0.06),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.04),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: captured ? _accentTeal.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: captured
                          ? [_accentTeal, _accentTeal]
                          : [_accentIndigo, _accentTeal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    captured ? Icons.check : icon,
                    color: captured ? const Color(0xFF0A0A1A) : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (busy)
                        Text(
                          busyLabel ?? 'Working…',
                          style: TextStyle(color: _accentTeal, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (captured && capturedPreview != null)
                        capturedPreview!
                      else
                        Text(
                          pendingSubtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accentTeal),
                  )
                else
                  Text(
                    actionLabel,
                    style: TextStyle(color: _accentTeal.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstBarcodeExt on List<Barcode> {
  String? get firstOrNullRawValue => isEmpty ? null : first.rawValue;
}
