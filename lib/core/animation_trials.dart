class AnimationTrials {
  AnimationTrials._();

  static const bool paymentSuccessWebpEnabled = bool.fromEnvironment(
    'TRIAL_PAYMENT_SUCCESS_WEBP',
    defaultValue: true,
  );
}
