import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Checkbox list for selecting allergens.
/// Tapping "لا يحتوي على مسببات حساسية معروفة" clears all other selections;
/// tapping any specific allergen clears the no-known-allergens option.
class AllergyCheckboxPanel extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const AllergyCheckboxPanel({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مسببات الحساسية الغذائية',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'اختر المكونات التي قد تسبب الحساسية في هذا العرض',
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: AppConstants.allergenOptions.map((allergen) {
              final isChecked = selected.contains(allergen);
              final isNoAllergen =
                  allergen == AppConstants.noKnownAllergens;
              return CheckboxListTile(
                value: isChecked,
                title: Text(
                  allergen,
                  style: TextStyle(
                    fontSize: 13,
                    color: isNoAllergen && isChecked
                        ? AppColors.success
                        : AppColors.textDark,
                    fontWeight: isNoAllergen
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                activeColor:
                    isNoAllergen ? AppColors.success : AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                onChanged: (checked) {
                  final newSet = Set<String>.from(selected);
                  if (checked == true) {
                    if (isNoAllergen) {
                      newSet.clear();
                    } else {
                      newSet.remove(AppConstants.noKnownAllergens);
                    }
                    newSet.add(allergen);
                  } else {
                    newSet.remove(allergen);
                  }
                  onChanged(newSet);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
