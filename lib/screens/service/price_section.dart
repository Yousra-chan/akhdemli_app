import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_app/providers/language_provider.dart';

class PriceSection extends StatelessWidget {
  final TextEditingController priceController;
  final String selectedPriceUnit;
  final List<String> priceUnits;
  final Function(String?) onPriceUnitChanged;
  final VoidCallback? onPriceChanged;
  final bool showMarketComparison;
  final double marketAveragePrice;

  const PriceSection({
    super.key,
    required this.priceController,
    required this.selectedPriceUnit,
    required this.priceUnits,
    required this.onPriceUnitChanged,
    this.onPriceChanged,
    this.showMarketComparison = true,
    this.marketAveragePrice = 2500.0,
  });

  // Colors
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _accentColor = Color(0xFF059669);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildPriceInputSection(lang),
          ],
        );
      },
    );
  }

  Widget _buildPriceInputSection(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildDesktopLayout(lang);
            } else {
              return _buildMobileLayout(lang);
            }
          },
        ),
        const SizedBox(height: 12),
        if (priceController.text.isNotEmpty) ...[
          _buildPriceInfoCards(lang),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(LanguageProvider lang) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPriceInputCard(lang),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPriceUnitCard(lang),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(LanguageProvider lang) {
    return Column(
      children: [
        _buildPriceInputCard(lang),
        const SizedBox(height: 12),
        _buildPriceUnitCard(lang),
      ],
    );
  }

  Widget _buildPriceInputCard(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.tr('price_section_title', category: 'service'),
                  style: TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (priceController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      priceController.clear();
                      onPriceChanged?.call();
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear,
                          color: _textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lang.tr('price_clear', category: 'service'),
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lang.tr('price_currency', category: 'service'),
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    onChanged: (_) => onPriceChanged?.call(),
                    decoration: InputDecoration(
                      hintText: lang.tr('price_hint', category: 'service'),
                      hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 4),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceUnitCard(LanguageProvider lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.tr('price_billing_method', category: 'service'),
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: selectedPriceUnit,
              isExpanded: true,
              items: _buildPriceUnitItems(lang),
              onChanged: onPriceUnitChanged,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: _primaryColor,
                size: 24,
              ),
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              dropdownColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildPriceUnitItems(LanguageProvider lang) {
    return priceUnits.map((unit) {
      final unitKey = _getPriceUnitKey(unit);

      return DropdownMenuItem(
        value: unit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                _getPriceUnitIcon(unit),
                size: 18,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.tr(unitKey, category: 'service'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.tr('${unitKey}_desc', category: 'service'),
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _getPriceUnitKey(String unit) {
    switch (unit) {
      case 'per hour':
        return 'price_unit_hour';
      case 'per day':
        return 'price_unit_day';
      case 'per service':
        return 'price_unit_service';
      case 'per square meter':
        return 'price_unit_square_meter';
      case 'per item':
        return 'price_unit_item';
      case 'per session':
        return 'price_unit_session';
      default:
        return 'price_unit_service';
    }
  }

  Widget _buildPriceInfoCards(LanguageProvider lang) {
    final price = double.tryParse(priceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPriceSummaryCard(price, lang),
        if (showMarketComparison) ...[
          const SizedBox(height: 6),
          _buildMarketComparisonCard(price, lang),
        ],
      ],
    );
  }

  Widget _buildPriceSummaryCard(double price, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 16,
            color: _accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.trParams('price_summary', category: 'service', params: {
                    'price': price.toStringAsFixed(
                        price.truncateToDouble() == price ? 0 : 2),
                    'unit': lang.tr(_getPriceUnitKey(selectedPriceUnit),
                        category: 'service'),
                  }),
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lang.trParams('price_summary_label',
                      category: 'service',
                      params: {
                        'unit': lang.tr(_getPriceUnitKey(selectedPriceUnit),
                            category: 'service'),
                      }),
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketComparisonCard(double price, LanguageProvider lang) {
    final comparison = price.compareTo(marketAveragePrice);
    final comparisonData = _getComparisonData(comparison, price, lang);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: comparisonData.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: comparisonData.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            comparisonData.icon,
            size: 16,
            color: comparisonData.color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  comparisonData.text,
                  style: TextStyle(
                    color: comparisonData.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lang.trParams('price_market_avg',
                      category: 'service',
                      params: {
                        'price': marketAveragePrice.toStringAsFixed(0),
                      }),
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getPriceUnitIcon(String unit) {
    final lowerUnit = unit.toLowerCase();

    final icons = {
      'per hour': Icons.access_time,
      'per day': Icons.calendar_today,
      'per service': Icons.check_circle,
      'per square meter': Icons.aspect_ratio,
      'per item': Icons.shopping_basket,
      'per session': Icons.event,
    };

    return icons[lowerUnit] ?? Icons.attach_money;
  }

  _ComparisonData _getComparisonData(
      int comparison, double price, LanguageProvider lang) {
    final percentage =
        ((price - marketAveragePrice).abs() / marketAveragePrice * 100)
            .toStringAsFixed(0);

    if (comparison < 0) {
      return _ComparisonData(
        text: lang.trParams('price_below_avg', category: 'service', params: {
          'percentage': percentage,
        }),
        color: const Color(0xFF10B981),
        icon: Icons.trending_down,
      );
    } else if (comparison > 0) {
      return _ComparisonData(
        text: lang.trParams('price_above_avg', category: 'service', params: {
          'percentage': percentage,
        }),
        color: const Color(0xFFF59E0B),
        icon: Icons.trending_up,
      );
    } else {
      return _ComparisonData(
        text: lang.tr('price_at_avg', category: 'service'),
        color: const Color(0xFF6366F1),
        icon: Icons.trending_flat,
      );
    }
  }
}

// Helper class for comparison data
class _ComparisonData {
  final String text;
  final Color color;
  final IconData icon;

  const _ComparisonData({
    required this.text,
    required this.color,
    required this.icon,
  });
}
