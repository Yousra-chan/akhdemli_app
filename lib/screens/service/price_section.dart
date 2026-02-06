import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildPriceInputSection(),
      ],
    );
  }

  Widget _buildPriceInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
        const SizedBox(height: 12),
        if (priceController.text.isNotEmpty) ...[
          _buildPriceInfoCards(),
          const SizedBox(height: 4), // Reduced spacing
        ],
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPriceInputCard(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPriceUnitCard(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildPriceInputCard(),
        const SizedBox(height: 12),
        _buildPriceUnitCard(),
      ],
    );
  }

  Widget _buildPriceInputCard() {
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
                  'Price (DZD)',
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
                    child: Icon(
                      Icons.clear,
                      color: _textSecondary,
                      size: 18,
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
                    'DZD',
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
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.5),
                        fontSize: 16, // Reduced size
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(bottom: 4),
                    ),
                    style: TextStyle(
                      fontSize: 16, // Reduced size
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

  Widget _buildPriceUnitCard() {
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
              'Billing Method',
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
              items: _buildPriceUnitItems(),
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

  List<DropdownMenuItem<String>> _buildPriceUnitItems() {
    return priceUnits.map((unit) {
      return DropdownMenuItem(
        value: unit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4), // Reduced padding
          child: Row(
            children: [
              Icon(
                _getPriceUnitIcon(unit),
                size: 18, // Reduced size
                color: _primaryColor,
              ),
              const SizedBox(width: 8), // Reduced spacing
              Flexible(
                // Use Flexible instead of Expanded
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Prevent overflow
                  children: [
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 13, // Reduced size
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getPriceUnitTooltip(unit),
                      style: TextStyle(
                        fontSize: 10, // Reduced size
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

  Widget _buildPriceInfoCards() {
    final price = double.tryParse(priceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min, // Prevent overflow
      children: [
        _buildPriceSummaryCard(price),
        if (showMarketComparison) ...[
          const SizedBox(height: 6), // Reduced spacing
          _buildMarketComparisonCard(price),
        ],
      ],
    );
  }

  Widget _buildPriceSummaryCard(double price) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10), // Reduced padding
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_exchange_rounded,
            size: 16, // Reduced size
            color: _accentColor,
          ),
          const SizedBox(width: 8), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              children: [
                Text(
                  _getPriceSummaryText(price),
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12, // Reduced size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on $selectedPriceUnit',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10, // Reduced size
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

  Widget _buildMarketComparisonCard(double price) {
    final comparison = price.compareTo(marketAveragePrice);
    final comparisonData = _getComparisonData(comparison, price);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10), // Reduced padding
      decoration: BoxDecoration(
        color: comparisonData.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: comparisonData.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            comparisonData.icon,
            size: 16, // Reduced size
            color: comparisonData.color,
          ),
          const SizedBox(width: 8), // Reduced spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Prevent overflow
              children: [
                Text(
                  comparisonData.text,
                  style: TextStyle(
                    color: comparisonData.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12, // Reduced size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Market avg: ${marketAveragePrice.toStringAsFixed(0)} DZD',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10, // Reduced size
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
  String _getPriceUnitTooltip(String unit) {
    final lowerUnit = unit.toLowerCase();

    final tooltips = {
      'per hour': 'Per hour worked',
      'per day': 'Per day worked',
      'per service': 'Fixed price',
      'per square meter': 'Based on area',
      'per item': 'Price per unit',
      'per session': 'Per appointment',
    };

    return tooltips[lowerUnit] ?? '';
  }

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

  String _getPriceSummaryText(double price) {
    final formattedPrice =
        price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
    return '$formattedPrice DZD $selectedPriceUnit';
  }

  _ComparisonData _getComparisonData(int comparison, double price) {
    final percentage =
        ((price - marketAveragePrice).abs() / marketAveragePrice * 100)
            .toStringAsFixed(0);

    if (comparison < 0) {
      return _ComparisonData(
        text: '$percentage% below avg',
        color: const Color(0xFF10B981),
        icon: Icons.trending_down,
      );
    } else if (comparison > 0) {
      return _ComparisonData(
        text: '$percentage% above avg',
        color: const Color(0xFFF59E0B),
        icon: Icons.trending_up,
      );
    } else {
      return _ComparisonData(
        text: 'At market average',
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
