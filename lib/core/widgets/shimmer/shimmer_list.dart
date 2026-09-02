import 'package:flutter/material.dart';
import 'cool_shimmer.dart';

enum ShimmerListType {
  notifications,
  orders,
  cart,
  invoices,
  generic,
}

/// Shimmer Skeleton for multi-item list views (Orders, Notifications, Cart Items, Invoices).
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final ShimmerListType type;
  final EdgeInsetsGeometry padding;
  final bool hasDivider;
  final ScrollPhysics physics;
  final bool shrinkWrap;

  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.type = ShimmerListType.generic,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.hasDivider = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  });

  /// Const constructor for Notifications list skeleton
  const ShimmerList.notifications({
    super.key,
    this.itemCount = 7,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  })  : type = ShimmerListType.notifications,
        hasDivider = true;

  /// Const constructor for My Orders list skeleton
  const ShimmerList.orders({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  })  : type = ShimmerListType.orders,
        hasDivider = false;

  /// Const constructor for Cart items list skeleton
  const ShimmerList.cart({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  })  : type = ShimmerListType.cart,
        hasDivider = false;

  /// Const constructor for Invoices list skeleton
  const ShimmerList.invoices({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.all(16),
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  })  : type = ShimmerListType.invoices,
        hasDivider = false;

  /// Const constructor for Generic list skeleton
  const ShimmerList.generic({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  })  : type = ShimmerListType.generic,
        hasDivider = true;

  @override
  Widget build(BuildContext context) {
    return CoolShimmer(
      child: ListView.separated(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (context, index) {
          if (!hasDivider) return const SizedBox(height: 12);
          return const Divider(height: 16, indent: 70, endIndent: 16);
        },
        itemBuilder: (context, index) {
          switch (type) {
            case ShimmerListType.notifications:
              return _buildNotificationItem();
            case ShimmerListType.orders:
              return _buildOrderItem();
            case ShimmerListType.cart:
              return _buildCartItem();
            case ShimmerListType.invoices:
              return _buildInvoiceItem();
            case ShimmerListType.generic:
              return _buildGenericItem();
          }
        },
      ),
    );
  }

  Widget _buildNotificationItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Circle
          CoolShimmerBone.circle(size: 42),
          SizedBox(width: 15),
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CoolShimmerBone(width: 140, height: 14, borderRadius: 4),
                    CoolShimmerBone.circle(size: 8),
                  ],
                ),
                SizedBox(height: 8),
                CoolShimmerBone(
                    width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 5),
                CoolShimmerBone(width: 180, height: 12, borderRadius: 4),
                SizedBox(height: 8),
                CoolShimmerBone(width: 70, height: 10, borderRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CoolShimmerBone(width: 90, height: 16, borderRadius: 4),
                  SizedBox(width: 8),
                  CoolShimmerBone(width: 40, height: 12, borderRadius: 4),
                  SizedBox(width: 10),
                  CoolShimmerBone.pill(width: 65, height: 20),
                ],
              ),
              CoolShimmerBone(width: 14, height: 14, borderRadius: 3),
            ],
          ),
          SizedBox(height: 10),
          CoolShimmerBone(width: 100, height: 11, borderRadius: 3),
          SizedBox(height: 8),
          CoolShimmerBone(width: double.infinity, height: 13, borderRadius: 4),
          SizedBox(height: 12),
          CoolShimmerBone(width: 110, height: 16, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildCartItem() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: const Row(
        children: [
          // Product Thumbnail
          CoolShimmerBone(width: 80, height: 80, borderRadius: 10),
          SizedBox(width: 15),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoolShimmerBone(width: 150, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                CoolShimmerBone(width: 80, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                CoolShimmerBone(width: 60, height: 11, borderRadius: 3),
                SizedBox(height: 8),
                // Counter UI skeleton
                CoolShimmerBone.pill(width: 88, height: 26),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoolShimmerBone(width: 110, height: 18, borderRadius: 4),
              CoolShimmerBone.pill(width: 65, height: 22),
            ],
          ),
          SizedBox(height: 8),
          CoolShimmerBone(width: 130, height: 12, borderRadius: 4),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoolShimmerBone(width: 90, height: 14, borderRadius: 4),
              CoolShimmerBone(width: 95, height: 16, borderRadius: 4),
            ],
          ),
          SizedBox(height: 14),
          CoolShimmerBone(
              width: double.infinity, height: 44, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildGenericItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CoolShimmerBone.circle(size: 48),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoolShimmerBone(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                CoolShimmerBone(
                    width: double.infinity, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
