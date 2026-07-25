import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/data/models/notification_model.dart';
import 'package:binetatour/providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().fetchNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        Future<void> refreshAction() => context
            .read<NotificationProvider>()
            .fetchNotifications(forceRefresh: true);

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
                onPressed: provider.notifications.isEmpty
                    ? null
                    : () => provider.markAllAsRead(),
                child: const Text(
                  "Tout lire",
                  style: TextStyle(color: Color(0xFFFF6900)),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFFFF6900),
            onRefresh: refreshAction,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                if (provider.isLoading && provider.notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 220),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6900),
                      ),
                    ),
                  )
                else if (provider.errorMessage != null &&
                    provider.notifications.isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: _buildErrorState(provider.errorMessage!),
                  )
                else if (provider.notifications.isEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: _buildEmptyState(),
                  )
                else
                  ...List.generate(provider.notifications.length, (index) {
                    final item = provider.notifications[index];
                    final widgets = <Widget>[_buildNotificationItem(item)];
                    if (index < provider.notifications.length - 1) {
                      widgets.add(const Divider(height: 1, indent: 70));
                    }
                    return Column(children: widgets);
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(NotificationModel item) {
    return Container(
      color: item.isRead
          ? Colors.transparent
          : const Color(0xFFFFF3E6).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dynamic Icon based on type
          _buildIcon(item.notificationType),
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
                  item.body,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatNotificationTime(item),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(String notificationType) {
    IconData iconData;
    Color iconColor;

    switch (notificationType.toLowerCase()) {
      case 'order':
        iconData = Icons.shopping_bag_outlined;
        iconColor = const Color(0xFFFF6900);
        break;
      case 'promo':
        iconData = Icons.local_offer_outlined;
        iconColor = Colors.blue;
        break;
      case 'system':
        iconData = Icons.settings_outlined;
        iconColor = Colors.grey;
        break;
      default:
        iconData = Icons.notifications_none_outlined;
        iconColor = const Color(0xFFFF6900);
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

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNotificationTime(NotificationModel item) {
    final date = item.readAt ?? item.createdAt;
    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} j';
    }
    if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} h';
    }
    if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} min';
    }

    return 'A l\'instant';
  }
}
