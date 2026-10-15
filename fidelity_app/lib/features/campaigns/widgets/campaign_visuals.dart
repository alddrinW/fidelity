import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../data/campaigns_repository.dart';

/// Texto de vigencia de una campaña: "Hasta 20/10/2026" o "Sin fecha de fin".
String campaignValidity(Campaign campaign) {
  String day(DateTime d) => EcuadorDateUtils.formatEcuadorDate(d.toUtc().toIso8601String());
  switch (campaign.phase) {
    case CampaignPhase.scheduled:
      final start = campaign.startsAt;
      return start == null ? 'Programada' : 'Empieza el ${day(start)}';
    case CampaignPhase.ended:
      return 'Terminó';
    case CampaignPhase.cancelled:
      return 'Cancelada';
    case CampaignPhase.active:
      final end = campaign.endsAt;
      return end == null ? 'Sin fecha de fin' : 'Hasta el ${day(end)}';
  }
}

/// Resumen corto del beneficio o del avance de una campaña.
String campaignHeadline(Campaign campaign) {
  switch (campaign.type) {
    case CampaignType.giftCard:
      return campaign.benefitLabel ?? 'Tarjeta de regalo';
    case CampaignType.route:
      return 'Gana: ${campaign.benefitLabel ?? 'un premio'}';
    case CampaignType.event:
      final text = campaign.description?.trim() ?? '';
      return text.isEmpty ? 'Novedades de ${campaign.businesses.firstOrNull?.name ?? 'tu local'}' : text;
  }
}

/// Colores de una tarjeta de campaña según su tipo: evento en rosa, tarjeta de
/// regalo en negro y ruta con contorno.
({Color background, Color foreground}) campaignColors(CampaignType type) => switch (type) {
      CampaignType.event => (background: AppColors.pink, foreground: AppColors.black),
      CampaignType.giftCard => (background: AppColors.black, foreground: AppColors.white),
      CampaignType.route => (background: AppColors.white, foreground: AppColors.black),
    };
