class CompanyBillingDetails {
  const CompanyBillingDetails({
    required this.status,
    this.isInTrial = false,
    required this.trialEnd,
    required this.requiresPayment,
    required this.latestInvoiceId,
    required this.currentPeriodEnd,
    required this.hasPaymentMethod,
    required this.stripeCustomerId,
    required this.cancelAt,
    required this.cancelAtPeriodEnd,
    required this.latestInvoiceStatus,
    required this.canUsePaidFeatures,
    required this.stripeSubscriptionId,
    required this.lastPaymentFailedAt,
    required this.isTrialSetupComplete,
    required this.latestInvoiceHostedUrl,
  });

  final String? status;
  final bool isInTrial;
  final String? trialEnd;
  final bool requiresPayment;
  final String? latestInvoiceId;
  final String? currentPeriodEnd;
  final bool hasPaymentMethod;
  final String? stripeCustomerId;
  final String? cancelAt;
  final bool cancelAtPeriodEnd;
  final String? latestInvoiceStatus;
  final bool? canUsePaidFeatures;
  final String? stripeSubscriptionId;
  final String? lastPaymentFailedAt;
  final bool isTrialSetupComplete;
  final String? latestInvoiceHostedUrl;

  factory CompanyBillingDetails.fromApiJson(Map<String, dynamic> json) {
    return CompanyBillingDetails(
      status: _readString(json['status']),
      isInTrial:
          _readBool(json['is_in_trial']) ??
          _readBool(json['isInTrial']) ??
          false,
      trialEnd: _readString(json['trial_end']),
      requiresPayment: _readBool(json['requires_payment']) ?? false,
      latestInvoiceId: _readString(json['latest_invoice_id']),
      currentPeriodEnd: _readString(json['current_period_end']),
      hasPaymentMethod: _readBool(json['has_payment_method']) ?? false,
      stripeCustomerId: _readString(json['stripe_customer_id']),
      cancelAt: _readString(json['cancel_at']),
      cancelAtPeriodEnd: _readBool(json['cancel_at_period_end']) ?? false,
      latestInvoiceStatus: _readString(json['latest_invoice_status']),
      canUsePaidFeatures: _readBool(json['can_use_paid_features']),
      stripeSubscriptionId: _readString(json['stripe_subscription_id']),
      lastPaymentFailedAt: _readString(json['last_payment_failed_at']),
      isTrialSetupComplete: _readBool(json['is_trial_setup_complete']) ?? false,
      latestInvoiceHostedUrl: _readString(json['latest_invoice_hosted_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'is_in_trial': isInTrial,
      'trial_end': trialEnd,
      'requires_payment': requiresPayment,
      'latest_invoice_id': latestInvoiceId,
      'current_period_end': currentPeriodEnd,
      'has_payment_method': hasPaymentMethod,
      'stripe_customer_id': stripeCustomerId,
      'cancel_at': cancelAt,
      'cancel_at_period_end': cancelAtPeriodEnd,
      'latest_invoice_status': latestInvoiceStatus,
      if (canUsePaidFeatures != null)
        'can_use_paid_features': canUsePaidFeatures,
      'stripe_subscription_id': stripeSubscriptionId,
      'last_payment_failed_at': lastPaymentFailedAt,
      'is_trial_setup_complete': isTrialSetupComplete,
      'latest_invoice_hosted_url': latestInvoiceHostedUrl,
    };
  }

  static String? _readString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty || resolved == 'null') {
      return null;
    }

    return resolved;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return null;
  }
}
