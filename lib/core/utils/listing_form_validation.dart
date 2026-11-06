import 'package:flutter/material.dart';

import '../widgets/app_toast.dart';

/// Shared copy + helpers for trade / gift / donation create forms.
class ListingFormValidation {
  ListingFormValidation._();

  static const String requiredFieldsMessage =
      'Please complete all required fields highlighted below.';

  static void showRequiredFieldsToast(BuildContext context) {
    AppToast.error(context, requiredFieldsMessage);
  }
}
