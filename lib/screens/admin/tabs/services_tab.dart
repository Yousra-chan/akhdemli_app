import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/ServicesModel.dart';
import '../../../ViewModel/admin_view_model.dart';
import '../../../providers/language_provider.dart';
import '../admin_service_details.dart';
import '../admin_components.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
class _T {
  static const primary     = Color(0xFF4F46E5);
  static const primaryL    = Color(0xFFEEF2FF);
  static const success     = Color(0xFF10B981);
  static const successL    = Color(0xFFD1FAE5);
  static const danger      = Color(0xFFEF4444);
  static const dangerL     = Color(0xFFFEE2E2);

  // Dark-mode counterparts
  static const primaryLD   = Color(0xFF312E81);
  static const successLD   = Color(0xFF064E3B);
  static const dangerLD    = Color(0xFF7F1D1D);

  static List<BoxShadow> card(bool dark) => [
    BoxShadow(
      color: Colors.black.withOpacity(dark ? 0.3 : 0.04),
      blurRadius: 6, offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> elevated(bool dark) => [
    BoxShadow(
      color: Colors.black.withOpacity(dark ? 0.5 : 0.08),
      blurRadius: 16, offset: const Offset(0, 4),
    ),
  ];

  static const rSm = BorderRadius.all(Radius.circular(8));
  static const rMd = BorderRadius.all(Radius.circular(12));
  static const rLg = BorderRadius.all(Radius.circular(16));
  static const rXl = BorderRadius.all(Radius.circular(20));
}

// Helper to grab theme colors concisely
extension _Ctx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg      => isDark ? const Color(0xFF0F0F13) : const Color(0xFFF5F6FA);
  Color get surface => isDark ? const Color(0xFF1C1C25) : Colors.white;
  Color get border  => isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE5E7EB);
  Color get txtP    => isDark ? const Color(0xFFF1F1F5) : const Color(0xFF111827);
  Color get txtS    => isDark ? const Color(0xFFB0B4C1) : const Color(0xFF4B5563); // Improved contrast for secondary text
  Color get txtM    => isDark ? const Color(0xFF8E92A2) : const Color(0xFF6B7280); // Improved contrast for muted text
}

// ── Main tab ─────────────────────────────────────────────────────────────────
class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab>
    with SingleTickerProviderStateMixin {
  String  _q    = '';
  String? _cat;
  String? _sub;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
  }

  @override
  void dispose() { _fade.dispose(); super.dispose(); }

  void _reset() => setState(() { _q = ''; _cat = null; _sub = null; });

  @override
  Widget build(BuildContext context) {
    final vm   = context.watch<AdminViewModel>();
    final lang = context.watch<LanguageProvider>();
    final dark = context.isDark;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: Container(
        color: context.bg,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: dark ? _T.primaryLD : _T.primaryL,
                    borderRadius: _T.rMd,
                  ),
                  child: const Icon(Icons.miscellaneous_services_rounded,
                      color: _T.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lang.tr('services', category: 'admin'),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.txtP,
                          letterSpacing: -0.6)),
                  const SizedBox(height: 2),
                  Text(lang.tr('manage_services_desc', category: 'admin'),
                      style: TextStyle(fontSize: 13, color: context.txtS)),
                ]),
              ],
            ),

            const SizedBox(height: 28),

            // ── Toolbar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: _T.rLg,
                boxShadow: _T.card(dark),
                border: Border.all(color: context.border),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        _SearchField(
                          value: _q,
                          onChanged: (v) => setState(() => _q = v),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _Dropdown<String?>(
                              value: _cat,
                              hint: lang.tr('all_categories', category: 'admin'),
                              items: [
                                DropdownMenuItem(value: null, child: Text(lang.tr('all_categories', category: 'admin'))),
                                ...vm.categories.map((c) =>
                                    DropdownMenuItem(value: c.name, child: Text(c.getTranslatedName(lang)))),
                              ],
                              onChanged: (v) => setState(() { _cat = v; _sub = null; }),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: Builder(builder: (ctx) {
                              final subs = _cat == null ? [] :
                              vm.categories.firstWhere((c) => c.name == _cat).subcategories;
                              return _Dropdown<String?>(
                                value: _sub,
                                hint: lang.tr('all_subcategories', category: 'admin'),
                                items: [
                                  DropdownMenuItem(value: null, child: Text(lang.tr('all_subcategories', category: 'admin'))),
                                  ...subs.map((s) =>
                                      DropdownMenuItem(value: s.name, child: Text(s.getTranslatedName(lang)))),
                                ],
                                onChanged: subs.isEmpty ? null :
                                    (v) => setState(() => _sub = v),
                              );
                            })),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: TextButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                            label: Text(lang.tr('reset', category: 'admin')),
                            style: TextButton.styleFrom(
                              foregroundColor: context.txtS,
                              backgroundColor: context.bg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: _T.rMd,
                                  side: BorderSide(color: context.border)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(children: [
                    Expanded(flex: 3, child: _SearchField(
                      value: _q,
                      onChanged: (v) => setState(() => _q = v),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _Dropdown<String?>(
                      value: _cat,
                      hint: lang.tr('all_categories', category: 'admin'),
                      items: [
                        DropdownMenuItem(value: null, child: Text(lang.tr('all_categories', category: 'admin'))),
                        ...vm.categories.map((c) =>
                            DropdownMenuItem(value: c.name, child: Text(c.getTranslatedName(lang)))),
                      ],
                      onChanged: (v) => setState(() { _cat = v; _sub = null; }),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: Builder(builder: (ctx) {
                      final subs = _cat == null ? [] :
                      vm.categories.firstWhere((c) => c.name == _cat).subcategories;
                      return _Dropdown<String?>(
                        value: _sub,
                        hint: lang.tr('all_subcategories', category: 'admin'),
                        items: [
                          DropdownMenuItem(value: null, child: Text(lang.tr('all_subcategories', category: 'admin'))),
                          ...subs.map((s) =>
                              DropdownMenuItem(value: s.name, child: Text(s.getTranslatedName(lang)))),
                        ],
                        onChanged: subs.isEmpty ? null :
                            (v) => setState(() => _sub = v),
                      );
                    })),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                        label: Text(lang.tr('reset', category: 'admin')),
                        style: TextButton.styleFrom(
                          foregroundColor: context.txtS,
                          backgroundColor: context.bg,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: _T.rMd,
                              side: BorderSide(color: context.border)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── List ──
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('services').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return _Skeleton();
                if (snap.hasError) {
                  return _StateView(
                  icon: Icons.cloud_off_rounded,
                  color: _T.danger,
                  bg: dark ? _T.dangerLD : _T.dangerL,
                  title: lang.tr('failed_load_services', category: 'admin'),
                  subtitle: lang.tr('check_connection_retry', category: 'admin'),
                );
                }

                final all = snap.data!.docs.map((d) => Service.fromFirestore(d));
                final services = all.where((s) {
                  final q = _q.toLowerCase();
                  return (s.title.toLowerCase().contains(q) ||
                      s.description.toLowerCase().contains(q)) &&
                      (_cat == null || s.category == _cat) &&
                      (_sub == null || s.subcategory == _sub);
                }).toList();

                if (services.isEmpty) {
                  return _StateView(
                  icon: Icons.search_off_rounded,
                  color: _T.primary,
                  bg: dark ? _T.primaryLD : _T.primaryL,
                  title: _q.isNotEmpty || _cat != null ? lang.tr('no_matching_services', category: 'admin') : lang.tr('no_services_yet', category: 'admin'),
                  subtitle: _q.isNotEmpty || _cat != null
                      ? lang.tr('adjust_filters', category: 'admin')
                      : lang.tr('services_will_appear', category: 'admin'),
                );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Result count bar ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 2),
                      child: Text(
                        services.length == 1 
                          ? lang.tr('service_count_single', category: 'admin').replaceAll('{{count}}', '1')
                          : lang.trParams('service_count_plural', category: 'admin', params: {'count': services.length.toString()}),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: context.txtS),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: services.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _ServiceRow(
                          key: ValueKey(services[i].id),
                          service: services[i],
                          onDelete: () => _confirmDelete(ctx, vm, services[i], lang),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AdminViewModel vm, Service s, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteDialog(
        serviceName: s.title,
        onConfirm: () { vm.deleteService(s.id); Navigator.pop(ctx); },
        onCancel:  () => Navigator.pop(ctx),
      ),
    );
  }
}

// ── Search field ─────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.value, required this.onChanged});
  @override State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.value;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: _T.rMd,
        border: Border.all(
          // Slightly more visible border on the search field for prominence
          color: context.isDark
              ? const Color(0xFF3A3A50)
              : const Color(0xFFD1D5DB),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: 13, color: context.txtP),
        decoration: InputDecoration(
          hintText: lang.tr('search_services_hint', category: 'admin'),
          hintStyle: TextStyle(fontSize: 13, color: context.txtM),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: _T.primary.withOpacity(0.7)),
          suffixIcon: _ctrl.text.isNotEmpty
              ? GestureDetector(
            onTap: () { _ctrl.clear(); widget.onChanged(''); },
            child: Icon(Icons.close_rounded, size: 16, color: context.txtM),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Generic dropdown ──────────────────────────────────────────────────────────
class _Dropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const _Dropdown({required this.value, required this.hint,
    required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: disabled
            ? (context.isDark ? const Color(0xFF16161E) : const Color(0xFFF9FAFB))
            : context.bg,
        borderRadius: _T.rMd,
        border: Border.all(color: context.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13,
              color: disabled ? context.txtM : context.txtS)),
          isExpanded: true,
          icon: Icon(Icons.unfold_more_rounded, size: 16,
              color: disabled ? context.txtM : context.txtS),
          style: TextStyle(fontSize: 13, color: context.txtP),
          items: items,
          onChanged: onChanged,
          dropdownColor: context.surface,
          borderRadius: _T.rMd,
        ),
      ),
    );
  }
}

// ── Service row ───────────────────────────────────────────────────────────────
class _ServiceRow extends StatefulWidget {
  final Service service;
  final VoidCallback onDelete;
  const _ServiceRow({super.key, required this.service, required this.onDelete});
  @override State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hovered = false;
  String _providerName = '';

  @override
  void initState() {
    super.initState();
    // Don't call _fetchProviderName here, do it in build or use a FutureBuilder
    // Actually, it's better to keep it but use localized placeholders
  }

  Future<void> _fetchProviderName(LanguageProvider lang) async {
    if (_providerName.isNotEmpty && _providerName != lang.tr('loading', category: 'admin')) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.service.providerId).get();
      if (doc.exists && mounted) {
        setState(() => _providerName = doc.data()?['name'] ?? lang.tr('unknown', category: 'admin'));
      }
    } catch (e) {
      if (mounted) setState(() => _providerName = lang.tr('error', category: 'admin'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s    = widget.service;
    final dark = context.isDark;
    final lang = context.watch<LanguageProvider>();
    
    if (_providerName.isEmpty) {
      _providerName = lang.tr('loading', category: 'admin');
      _fetchProviderName(lang);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: _T.rMd,
          border: Border.all(
              color: _hovered ? _T.primary.withOpacity(0.4) : context.border,
              width: _hovered ? 1.5 : 1.0),
          boxShadow: _hovered ? _T.elevated(dark) : _T.card(dark),
        ),
        child: InkWell(
          onTap: () {
            final vm = context.read<AdminViewModel>();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: AdminServiceDetailsScreen(service: s),
                ),
              ),
            );
          },
          borderRadius: _T.rMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              // Thumbnail
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: dark ? _T.primaryLD : _T.primaryL,
                  borderRadius: _T.rMd,
                  image: s.images.isNotEmpty
                      ? DecorationImage(image: NetworkImage(s.images[0]), fit: BoxFit.cover)
                      : null,
                ),
                child: s.images.isEmpty
                    ? const Icon(Icons.image_outlined, color: _T.primary, size: 22)
                    : null,
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.txtP,
                          letterSpacing: -0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 12, color: context.txtM),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _providerName, 
                          style: TextStyle(fontSize: 12, color: context.txtS, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_rounded, size: 12, color: context.txtM),
                      const SizedBox(width: 4),
                      Text(DateFormat.yMMMd().format(s.createdAt), style: TextStyle(fontSize: 12, color: context.txtM)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Flexible(child: _chip(s.category, false, dark)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right_rounded, size: 13, color: context.txtM),
                    ),
                    Flexible(child: _chip(s.subcategory, true, dark)),
                  ]),
                ],
              )),

              const SizedBox(width: 16),

              // Status
              _statusBadge(s.isActive, dark),
              if (s.isFeatured) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              ],
              const SizedBox(width: 14),

              // Delete
              _DeleteBtn(onPressed: widget.onDelete),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool isPrimary, bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isPrimary
          ? (dark ? _T.primaryLD : _T.primaryL)
          : (dark ? const Color(0xFF2A2A36) : const Color(0xFFF3F4F6)),
      borderRadius: const BorderRadius.all(Radius.circular(6)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isPrimary ? _T.primary : context.txtS,
            letterSpacing: 0.1),
        maxLines: 1,
        overflow: TextOverflow.ellipsis),
  );

  Widget _statusBadge(bool active, bool dark) {
    final lang = context.watch<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? (dark ? _T.successLD : _T.successL)
            : (dark ? _T.dangerLD  : _T.dangerL),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: active
              ? _T.success.withOpacity(0.3)
              : _T.danger.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(
                color: active ? _T.success : _T.danger, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? lang.tr('status_active', category: 'admin') : lang.tr('inactive', category: 'admin'),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? _T.success : _T.danger,
                letterSpacing: 0.2)),
      ]),
    );
  }
}

// ── Delete icon button ────────────────────────────────────────────────────────
class _DeleteBtn extends StatefulWidget {
  final VoidCallback onPressed;
  const _DeleteBtn({required this.onPressed});
  @override State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final lang = context.watch<LanguageProvider>();
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hov ? (dark ? _T.dangerLD : _T.dangerL) : Colors.transparent,
          borderRadius: _T.rSm,
        ),
        child: IconButton(
          icon: Icon(Icons.delete_outline_rounded, size: 18,
              color: _hov ? _T.danger : context.txtM),
          onPressed: widget.onPressed,
          splashRadius: 20,
          tooltip: lang.tr('delete_service_confirm', category: 'admin'),
        ),
      ),
    );
  }
}

// ── Skeleton loader ───────────────────────────────────────────────────────────
class _Skeleton extends StatefulWidget {
  @override State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final shimmer = Color.lerp(
          dark ? const Color(0xFF1E1E2A) : const Color(0xFFE5E7EB),
          dark ? const Color(0xFF2A2A38) : const Color(0xFFF3F4F6),
          _ctrl.value,
        )!;
        return ListView.separated(
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => Container(
            height: 76,
            decoration: BoxDecoration(color: context.surface,
                borderRadius: _T.rMd, border: Border.all(color: context.border)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              _Sk(52, 52, 12, shimmer),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Sk(double.infinity, 13, 6, shimmer),
                  const SizedBox(height: 8),
                  _Sk(160, 11, 6, shimmer),
                ],
              )),
              const SizedBox(width: 16),
              _Sk(72, 26, 20, shimmer),
              const SizedBox(width: 14),
              _Sk(32, 32, 8, shimmer),
            ]),
          ),
        );
      },
    );
  }
}

class _Sk extends StatelessWidget {
  final double w, h, r;
  final Color c;
  const _Sk(this.w, this.h, this.r, this.c);
  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
  );
}

// ── Generic state view (empty / error) ───────────────────────────────────────
class _StateView extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String title, subtitle;
  const _StateView({required this.icon, required this.color, required this.bg,
    required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 32, color: color),
      ),
      const SizedBox(height: 20),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
          color: context.txtP)),
      const SizedBox(height: 6),
      Text(subtitle, style: TextStyle(fontSize: 13, color: context.txtS),
          textAlign: TextAlign.center),
    ]),
  );
}

// ── Delete dialog ─────────────────────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final String serviceName;
  final VoidCallback onConfirm, onCancel;
  const _DeleteDialog({required this.serviceName,
    required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final lang = context.watch<LanguageProvider>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: _T.rXl),
      elevation: 0,
      backgroundColor: context.surface,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: dark ? _T.dangerLD : _T.dangerL, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: _T.danger, size: 22),
              ),
              const SizedBox(height: 20),
              Text(lang.tr('delete_service_confirm', category: 'admin'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: context.txtP, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              RichText(text: TextSpan(
                style: TextStyle(fontSize: 13, color: context.txtS, height: 1.6),
                children: [
                  TextSpan(text: lang.tr('delete_service_warning', category: 'admin')),
                  TextSpan(text: '"$serviceName"',
                      style: TextStyle(fontWeight: FontWeight.w600, color: context.txtP)),
                  TextSpan(text: lang.tr('delete_service_undone', category: 'admin')),
                ],
              )),
              const SizedBox(height: 24),
              Divider(color: context.border, height: 1),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: context.txtS,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: _T.rMd, side: BorderSide(color: context.border)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  child: Text(lang.tr('cancel', category: 'common')),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: Text(lang.tr('delete', category: 'common')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: _T.rMd),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }
}
