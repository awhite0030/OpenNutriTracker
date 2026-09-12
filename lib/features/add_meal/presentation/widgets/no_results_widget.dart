import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/generated/l10n.dart';

class NoResultsWidget extends StatelessWidget {
  final VoidCallback? onBarcodePressed;
  final VoidCallback? onCustomFoodPressed;

  const NoResultsWidget({super.key, this.onBarcodePressed, this.onCustomFoodPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmptyHint(
          icon: Icons.search_off_rounded,
          title: S.of(context).noResultsFound,
          subtitle: (onBarcodePressed != null || onCustomFoodPressed != null)
              ? S.of(context).emptySearchSubtitle
              : null,
        ),
        if (onBarcodePressed != null || onCustomFoodPressed != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spacing32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onBarcodePressed != null)
                  Expanded(
                    child: Semantics(
                      identifier: 'empty-search-scan-barcode',
                      child: OutlinedButton.icon(
                        onPressed: onBarcodePressed,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(S.of(context).emptySearchScanAction, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                if (onBarcodePressed != null && onCustomFoodPressed != null) const SizedBox(width: Dimens.spacing16),
                if (onCustomFoodPressed != null)
                  Expanded(
                    child: Semantics(
                      identifier: 'empty-search-create-custom',
                      child: FilledButton.icon(
                        onPressed: onCustomFoodPressed,
                        icon: const Icon(Icons.add),
                        label: Text(S.of(context).emptySearchCustomAction, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
