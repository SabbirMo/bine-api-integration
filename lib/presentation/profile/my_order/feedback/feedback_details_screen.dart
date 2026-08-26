import 'package:binetatour/presentation/common/widgets/product_thumbnail_or_video_frame.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/feedback_provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:binetatour/data/models/order_detail_model.dart';

class FeedbackDetailsScreen extends StatefulWidget {
  final String orderId;
  final String date;
  final OrderItemModel item;

  const FeedbackDetailsScreen({
    super.key,
    required this.orderId,
    required this.date,
    required this.item,
  });

  @override
  State<FeedbackDetailsScreen> createState() => _FeedbackDetailsScreenState();
}

class _FeedbackDetailsScreenState extends State<FeedbackDetailsScreen> {
  double _currentRating = 0.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Donner mon avis",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildOrderSummaryCard(),
            const SizedBox(height: 20),
            _buildRatingFormCard(),
            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Commande ${widget.orderId}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            "Livré le ${widget.date}",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _itemRowWithImage(widget.item),
          ),
        ],
      ),
    );
  }

  Widget _itemRowWithImage(OrderItemModel item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductThumbnailOrVideoFrame(
            imageUrl: item.mainImage,
            productId: item.productId,
            width: 60,
            height: 60,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Notez votre expérience",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          RatingBar.builder(
            initialRating: _currentRating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 40,
            unratedColor: Colors.grey.shade200,
            itemPadding: const EdgeInsets.only(right: 8.0),
            itemBuilder: (context, _) =>
                const Icon(Icons.star, color: Colors.orange),
            onRatingUpdate: (rating) {
              setState(() => _currentRating = rating);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Laissez un commentaire",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Racontez-nous votre expérience...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xffE74B08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xffE74B08)),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Ajouter des photos/vidéos",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Consumer<FeedbackProvider>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...provider.selectedImages.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildMediaPreview(
                          entry.value,
                          entry.key,
                          provider,
                        ),
                      );
                    }),
                    _buildAddMediaButton(provider),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(XFile file, int index, FeedbackProvider provider) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(File(file.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () {
              provider.removeImage(index);
            },
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Colors.red.shade300,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMediaButton(FeedbackProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: InkWell(
        onTap: () async {
          await provider.pickImage();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70, // Fixed width to match the screenshot
          height: 70, // Fixed height to match the screenshot
          alignment: Alignment.center,
          child: const Icon(Icons.add, color: Colors.grey, size: 28),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<FeedbackProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (_currentRating == 0.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Veuillez donner une note."),
                          ),
                        );
                        return;
                      }

                      final success = await provider.submitFeedback(
                        orderNumber: widget.orderId,
                        orderItemId: widget.item.id,
                        rating: _currentRating,
                        comment: _commentController.text,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        provider.clearImages();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Your review successfully sent"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.errorMessage ?? "Erreur d'envoi",
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: provider.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Envoyer l'avis",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
