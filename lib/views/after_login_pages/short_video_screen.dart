import 'package:flutter/material.dart';
import '../../utils/text_style.dart';

class ShortVideoPlayerScreen extends StatelessWidget {
  const ShortVideoPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image / Video
        Image.asset("assets/images/2.png", fit: BoxFit.cover),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.25),
                Colors.black.withOpacity(0.85),
              ],
            ),
          ),
        ),

        // Top Bar (Back Button)
        Positioned(
          top: 50,
          left: 16,
          child: GestureDetector(
            onTap: () {
              // Use Navigator.pop if needed or handle via provider
            },
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),

        // Right Side Action Buttons
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _actionButton(Icons.thumb_up_alt_outlined, "12K"),
              const SizedBox(height: 20),
              _actionButton(Icons.comment_outlined, "248"),
              const SizedBox(height: 20),
              _actionButton(Icons.bookmark_border, "Save"),
              const SizedBox(height: 20),
              _actionButton(Icons.more_vert, ""),
            ],
          ),
        ),

        // Bottom User Info
        Positioned(
          bottom: 40,
          left: 16,
          right: 80,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage("assets/images/kim_profile.jpg"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kim Vastavik",
                      style: text18(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Kim Vastavik fghhighlojasjlkjhkjhffkff jlsafjlsfjl...",
                      style: text14(
                        color: Colors.white70,
                      ).copyWith(height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom Right Small Image (Music / Track)
        Positioned(
          bottom: 48,
          right: 16,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: AssetImage("assets/images/music_thumbnail.jpg"),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: text14(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
