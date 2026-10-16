import 'package:flutter/material.dart';
import 'package:camprent_pos/core/theme/app_theme.dart';
import 'package:camprent_pos/data/models/rental_model.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool isSmall;

  const StatusPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.isSmall = false,
  });

  factory StatusPill.fromRental(RentalModel rental) {
    if (rental.status == RentalStatus.selesai) {
      return const StatusPill(
        label: 'Selesai',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
    }

    if (rental.isOverdue) {
      return StatusPill(
        label: 'Telat ${rental.overdueDays} Hari',
        backgroundColor: AppColors.dangerLight,
        textColor: AppColors.danger,
        icon: Icons.warning_amber_rounded,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      rental.scheduledReturnDate.year,
      rental.scheduledReturnDate.month,
      rental.scheduledReturnDate.day,
    );

    if (today.isAtSameMomentAs(due)) {
      return const StatusPill(
        label: 'Jatuh Tempo Hari Ini',
        backgroundColor: AppColors.warningLight,
        textColor: AppColors.warning,
        icon: Icons.access_time_rounded,
      );
    }

    if (rental.status == RentalStatus.menungguPersetujuan) {
      return const StatusPill(
        label: 'Persetujuan Admin',
        backgroundColor: AppColors.purpleLight,
        textColor: AppColors.purple,
        icon: Icons.hourglass_top_rounded,
      );
    }

    if (rental.status == RentalStatus.dikembalikanSebagian) {
      return const StatusPill(
        label: 'Kembali Sebagian',
        backgroundColor: AppColors.infoLight,
        textColor: AppColors.info,
        icon: Icons.pie_chart_outline,
      );
    }

    return const StatusPill(
      label: 'Aktif Disewa',
      backgroundColor: Color(0xFFE0F2FE),
      textColor: Color(0xFF0369A1),
      icon: Icons.hiking_rounded,
    );
  }

  factory StatusPill.collateral(CollateralModel? collateral, DepositModel? deposit) {
    if (collateral != null) {
      return StatusPill(
        label: 'Jaminan: ${collateral.typeLabel}',
        backgroundColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF475569),
        icon: Icons.badge_outlined,
        isSmall: true,
      );
    } else if (deposit != null) {
      return StatusPill(
        label: 'Deposit Rp ${deposit.amount ~/ 1000}rb',
        backgroundColor: AppColors.infoLight,
        textColor: AppColors.info,
        icon: Icons.monetization_on_outlined,
        isSmall: true,
      );
    }
    return const StatusPill(
      label: 'Tanpa Jaminan',
      backgroundColor: AppColors.dangerLight,
      textColor: AppColors.danger,
      icon: Icons.error_outline,
      isSmall: true,
    );
  }

  factory StatusPill.blacklist() {
    return const StatusPill(
      label: 'BLACKLIST',
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      icon: Icons.block,
      isSmall: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 12 : 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
