import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<AppNotification> notifications = [
    AppNotification(
      title: "Commande Confirmée",
      message: "Votre commande pour le Ballon de Football a été validée.",
      time: "Il y a 2 min",
      type: NotificationType.order,
    ),
    AppNotification(
      title: "Offre Flash ! ⚡",
      message:
          "Profitez de -20% sur toute la catégorie Tech aujourd'hui seulement.",
      time: "Il y a 1 heure",
      type: NotificationType.promo,
    ),
    AppNotification(
      title: "Mise à jour du système",
      message: "Une nouvelle version de Binetatour est disponible.",
      time: "Hier",
      type: NotificationType.system,
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "NOTIFICATIONS",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in notifications) {
                  n.isRead = true;
                }
              });
            },
            child: const Text(
              "Tout lire",
              style: TextStyle(color: Color(0xFFFF6900)),
            ),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: notifications.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationItem(item);
              },
            ),
    );
  }

  Widget _buildNotificationItem(AppNotification item) {
    return Container(
      color: item.isRead
          ? Colors.transparent
          : const Color(0xFFFFF3E6).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Icon based on type
          _buildIcon(item.type),
          const SizedBox(width: 15),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (!item.isRead)
                      const CircleAvatar(
                        radius: 4,
                        backgroundColor: Color(0xFFFF6900),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.message,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.time,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case NotificationType.order:
        iconData = Icons.shopping_bag_outlined;
        iconColor = const Color(0xFFFF6900);
        break;
      case NotificationType.promo:
        iconData = Icons.local_offer_outlined;
        iconColor = Colors.blue;
        break;
      case NotificationType.system:
        iconData = Icons.settings_outlined;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 15),
          const Text(
            "Aucune notification",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

enum NotificationType { order, promo, system }

class AppNotification {
  final String title;
  final String message;
  final String time;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}
