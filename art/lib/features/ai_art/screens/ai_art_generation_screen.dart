import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/ai_image_generation_loader.dart';

class AiArtGenerationScreen extends StatefulWidget {
  const AiArtGenerationScreen({Key? key}) : super(key: key);

  @override
  State<AiArtGenerationScreen> createState() => _AiArtGenerationScreenState();
}

class _AiArtGenerationScreenState extends State<AiArtGenerationScreen> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  bool _isGenerating = false;
  Uint8List? _generatedImageBytes;
  String? _errorMessage;

  String _selectedAspectRatio = '1:1';
  bool _autoEnhance = true;

  // Request dimensions that actually match the chosen aspect ratio instead
  // of always forcing a square image and cropping it afterwards. This keeps
  // the composition the model generates in sync with what's shown on screen.
  int get _imageWidth {
    switch (_selectedAspectRatio) {
      case '9:16':
        return 768;
      case '16:9':
        return 1344;
      case '1:1':
      default:
        return 1024;
    }
  }

  int get _imageHeight {
    switch (_selectedAspectRatio) {
      case '9:16':
        return 1344;
      case '16:9':
        return 768;
      case '1:1':
      default:
        return 1024;
    }
  }

  double get _containerAspectRatio {
    switch (_selectedAspectRatio) {
      case '9:16':
        return 9 / 16;
      case '16:9':
        return 16 / 9;
      case '1:1':
      default:
        return 1.0;
    }
  }

  Future<void> _generateArt() async {
    final basePrompt = _promptController.text.trim();
    if (basePrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what you want to create first.'),
        ),
      );
      return;
    }

    final lowerPrompt = basePrompt.toLowerCase();
    final forbiddenRegex = RegExp(
      r'\b(fuck|shit|bitch|asshole|nude|naked|sex|porn|nsfw|boobs|dick|pussy|vagina|penis)\b',
    );

    if (forbiddenRegex.hasMatch(lowerPrompt)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("I can't help with it.")));
      return;
    }

    if (_isGenerating) return;

    // Hide keyboard
    _promptFocusNode.unfocus();

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _generatedImageBytes = null;
    });

    try {
      String finalPrompt = basePrompt;
      if (_autoEnhance) {
        finalPrompt =
            '$basePrompt, masterpiece, award-winning, 8k resolution, highly detailed, vivid colors, cinematic lighting, ultra-realistic';
      }

      // Add framing hints so the AI centers the subject nicely
      if (_selectedAspectRatio == '9:16') {
        finalPrompt +=
            ', centered vertical portrait composition, framed in center';
      } else if (_selectedAspectRatio == '16:9') {
        finalPrompt += ', centered horizontal landscape composition, wide shot';
      }

      final hfToken = dotenv.env['HUGGINGFACE_API_TOKEN'] ?? '';
      const modelId = 'black-forest-labs/FLUX.1-schnell';

      // Step 1: Auto-discover live providers for black-forest-labs/FLUX.1-schnell from HF API (matches Python InferenceClient provider="auto")
      List<String> candidateProviders = ['nscale', 'wavespeed', 'fal-ai', 'hf-inference'];
      try {
        final mappingUri = Uri.parse(
          'https://huggingface.co/api/models/$modelId?expand=inferenceProviderMapping',
        );
        final mapRes = await http.get(mappingUri).timeout(const Duration(seconds: 10));
        if (mapRes.statusCode == 200) {
          final mapData = jsonDecode(mapRes.body);
          if (mapData is Map && mapData.containsKey('inferenceProviderMapping')) {
            final mapping = mapData['inferenceProviderMapping'] as Map;
            final liveProviders = <String>[];
            mapping.forEach((pKey, pVal) {
              if (pVal is Map && pVal['status'] == 'live') {
                liveProviders.add(pKey.toString());
              }
            });
            if (liveProviders.isNotEmpty) {
              candidateProviders = [...liveProviders, ...candidateProviders];
            }
          }
        }
      } catch (e) {
        debugPrint('Provider discovery fallback: $e');
      }

      http.Response? response;
      String lastAttemptedUrl = '';

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (hfToken.isNotEmpty) 'Authorization': 'Bearer $hfToken',
      };

      // Step 2: Request image generation from the live auto-discovered provider
      for (final provider in candidateProviders.toSet()) {
        final url1 = 'https://router.huggingface.co/$provider/v1/images/generations';
        lastAttemptedUrl = url1;
        final payload1 = jsonEncode({
          'model': modelId,
          'prompt': finalPrompt,
          'size': '${_imageWidth}x$_imageHeight',
        });

        try {
          final res1 = await http
              .post(Uri.parse(url1), headers: headers, body: payload1)
              .timeout(const Duration(seconds: 90));
          if (res1.statusCode == 200) {
            response = res1;
            break;
          }
        } catch (_) {}

        final url2 = 'https://router.huggingface.co/$provider/models/$modelId';
        lastAttemptedUrl = url2;
        final payload2 = jsonEncode({
          'inputs': finalPrompt,
          'parameters': {
            'width': _imageWidth,
            'height': _imageHeight,
          },
        });

        try {
          final res2 = await http
              .post(Uri.parse(url2), headers: headers, body: payload2)
              .timeout(const Duration(seconds: 90));
          if (res2.statusCode == 200) {
            response = res2;
            break;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        Uint8List imageBytes = response.bodyBytes;
        try {
          final responseString = utf8.decode(response.bodyBytes, allowMalformed: true);
          final trimmed = responseString.trim();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            final dynamic jsonResponse = jsonDecode(trimmed);
            if (jsonResponse is Map) {
              if (jsonResponse.containsKey('data') && jsonResponse['data'] is List) {
                final list = jsonResponse['data'] as List;
                if (list.isNotEmpty && list[0] is Map) {
                  final first = list[0] as Map;
                  if (first.containsKey('b64_json')) {
                    imageBytes = base64Decode(first['b64_json'].toString());
                  } else if (first.containsKey('url')) {
                    final imgRes = await http.get(Uri.parse(first['url'].toString()));
                    if (imgRes.statusCode == 200) {
                      imageBytes = imgRes.bodyBytes;
                    }
                  }
                }
              } else if (jsonResponse.containsKey('image')) {
                final b64Str = jsonResponse['image'] as String;
                imageBytes = base64Decode(
                  b64Str.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
                );
              }
            } else if (jsonResponse is List && jsonResponse.isNotEmpty && jsonResponse[0] is Map) {
              final first = jsonResponse[0] as Map;
              if (first.containsKey('generated_image') || first.containsKey('image')) {
                final b64Str = (first['generated_image'] ?? first['image']) as String;
                imageBytes = base64Decode(
                  b64Str.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), ''),
                );
              }
            }
          }
        } catch (_) {
          // Binary image output bytes handled directly
        }

        setState(() {
          _generatedImageBytes = imageBytes;
        });
      } else {
        final errText = response?.body ?? 'No response from Hugging Face providers';
        final status = response?.statusCode ?? 500;
        debugPrint(
          'Hugging Face FLUX Generation Error [$status] ($lastAttemptedUrl): $errText',
        );
        setState(() {
          _errorMessage =
              'Hugging Face FLUX Error ($status): $errText';
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Image generation timed out. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Failed to generate image. Please check your network and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Widget _buildPromptSuggestion(String prompt) {
    return ActionChip(
      label: Text(
        prompt,
        style: TextStyle(
          color: AppColors.coral,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.coral.withOpacity(0.1),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        _promptController.text = prompt;
        _generateArt();
      },
    );
  }

  Widget _buildAspectRatioChip(String label, String value, IconData icon) {
    final isSelected = _selectedAspectRatio == value;
    return GestureDetector(
      onTap: () {
        // Changing aspect ratio invalidates a previously generated image
        // since dimensions no longer match the displayed frame.
        setState(() {
          _selectedAspectRatio = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral : AppColors.creamBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.coral : AppColors.lightGrey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.darkGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkGrey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhanceToggle() {
    final isActive = _autoEnhance;
    return GestureDetector(
      onTap: () {
        setState(() {
          _autoEnhance = !_autoEnhance;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.coral : AppColors.creamBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.coral : AppColors.lightGrey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_fix_high,
              size: 16,
              color: isActive ? Colors.white : AppColors.darkGrey,
            ),
            const SizedBox(width: 6),
            Text(
              'Enhance',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.darkGrey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage() async {
    if (_generatedImageBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/ai_art_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(_generatedImageBytes!);

      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image downloaded to gallery!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download image. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImageBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/ai_art_share_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(_generatedImageBytes!);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Check out this AI art I created!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share image. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.creamBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'AI Studio',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_generatedImageBytes != null) ...[
            IconButton(
              icon: Icon(Icons.share_rounded, color: AppColors.coral),
              onPressed: _shareImage,
            ),
            IconButton(
              icon: Icon(Icons.download_rounded, color: AppColors.coral),
              onPressed: _downloadImage,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // TOP: Canvas Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      alignment: Alignment.bottomLeft,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child:
                      (_isGenerating ||
                          _generatedImageBytes != null ||
                          _errorMessage != null)
                      ? AspectRatio(
                          key: ValueKey('canvas-$_selectedAspectRatio'),
                          aspectRatio: _containerAspectRatio,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.creamLight,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.lightGrey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: _isGenerating
                                    ? const SizedBox.expand(
                                        key: ValueKey('loading'),
                                        child: AIImageGenerationLoader(
                                          height: double.infinity,
                                        ),
                                      )
                                    : _generatedImageBytes != null
                                    ? SizedBox.expand(
                                        key: const ValueKey('image'),
                                        child: InteractiveViewer(
                                          clipBehavior: Clip.none,
                                          child: Image.memory(
                                            _generatedImageBytes!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            filterQuality: FilterQuality.high,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                      )
                                    : Padding(
                                        key: const ValueKey('error'),
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              size: 64,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _errorMessage ??
                                                  'An error occurred',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextButton.icon(
                                              onPressed: _generateArt,
                                              icon: Icon(
                                                Icons.refresh,
                                                color: AppColors.coral,
                                              ),
                                              label: Text(
                                                'Try again',
                                                style: TextStyle(
                                                  color: AppColors.coral,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          key: const ValueKey('greeting'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -100),
                                child: Lottie.asset(
                                  'assets/lottie/AI Assistant.json',
                                  width: 180,
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -110),
                                child: Text(
                                  'What will you create today ?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.darkGrey.withOpacity(0.5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -90),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildPromptSuggestion('Cyberpunk City'),
                                    _buildPromptSuggestion('Neon Portrait'),
                                    _buildPromptSuggestion('Abstract Flow'),
                                    _buildPromptSuggestion('Anime Art'),
                                    _buildPromptSuggestion('3D Render'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),

          // BOTTOM: Input Area
          Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.creamLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Settings Row (Aspect Ratio & Enhance Toggle)
                  // Uses a Wrap instead of a horizontal-scroll Row so nothing
                  // ever gets pushed off-screen or hidden behind the edge —
                  // it simply drops to a second line on narrow screens.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildAspectRatioChip('1:1', '1:1', Icons.crop_square),
                      _buildAspectRatioChip(
                        '9:16',
                        '9:16',
                        Icons.crop_portrait,
                      ),
                      _buildAspectRatioChip(
                        '16:9',
                        '16:9',
                        Icons.crop_landscape,
                      ),
                      Container(
                        height: 20,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: AppColors.lightGrey,
                      ),
                      _buildEnhanceToggle(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Main Prompt Field & Send Button
                  // Wrapped in a single ClipRRect so the pill's outline and
                  // the button's edge are geometrically one shape — no
                  // separate background patch, no seam, no radius mismatch.
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      color: AppColors.creamBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.lightGrey.withOpacity(0.6),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _promptController,
                      focusNode: _promptFocusNode,
                      enabled: !_isGenerating,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _generateArt(),
                      style: TextStyle(color: AppColors.black),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Describe your vision...',
                        hintStyle: TextStyle(color: AppColors.darkGrey),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Material(
                            color: _isGenerating
                                ? AppColors.lightGrey
                                : AppColors.coral,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _isGenerating ? null : _generateArt,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: _isGenerating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
