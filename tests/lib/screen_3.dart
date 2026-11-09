import 'package:flutter/material.dart';

const Color kGreen = Color(0xFF2F8F3F);
const Color kDark = Color(0xFF1E1E1E);
const Color kBlack = Color(0xFF131313);
const Color kInk = Color(0xFF1B1B1B);
const Color kBody = Color(0xFF2E2E2B);
const Color kMuted = Color(0xFF6B6B66);
const Color kBorder = Color(0xFFE3E3E0);
const Color kPanel = Color(0xFFF5F5F2);
const Color kFooterMuted = Color(0xFF9A9A94);
const Color kFooterLink = Color(0xFFD9D9D4);

class Screen3 extends StatefulWidget {
  const Screen3({super.key});

  @override
  State<Screen3> createState() => _Screen3State();
}

class _Screen3State extends State<Screen3> {
  int _selectedService = 5;

  static const List<String> _services = <String>[
    'Construction',
    'Civil Engineering',
    'Steel Fabrication',
    'Aluminium Works',
    'Architectural Design',
    'Building Materials & Hardware',
  ];

  static const List<String> _deliverables = <String>[
    'Windows and door frames',
    'Plumbing materials and fittings',
    'Tiles, grout and tiling materials',
    'Paints, brushes and finishing tools',
    'Electrical connections and power tools',
    'Timber, ceiling boards, cement and Rhinoset',
  ];

  static const List<String> _navItems = <String>[
    'Home',
    'About',
    'Services',
    'Projects',
    'Social',
    'Contact',
  ];

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildTopBar(),
                _buildHeader(),
                _buildHero(),
                _buildMain(),
                _buildFooter(),
              ],
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: _buildWhatsApp(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- TOP BAR

  Widget _buildTopBar() {
    return Container(
      color: kBlack,
      child: _Wrap(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool wide = c.maxWidth > 720;
              final Widget left = Text(
                'Zimbabwean expertise. Practical delivery.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.80),
                  letterSpacing: 0.2,
                ),
              );
              final Widget right = Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _topItem(Icons.phone_in_talk_outlined, '+263 773 273 621',
                      () => _snack('Call +263 773 273 621')),
                  _topItem(Icons.phone_in_talk_outlined, '+263 716 127 991',
                      () => _snack('Call +263 716 127 991')),
                  _topItem(Icons.mail_outline, 'info@greengate.co.zw',
                      () => _snack('Email info@greengate.co.zw')),
                ],
              );
              if (wide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[left, right],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[left, const SizedBox(height: 8), right],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.65)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.90),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- HEADER

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _Wrap(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool wide = c.maxWidth > 900;
                  return Row(
                    children: <Widget>[
                      _logo(),
                      const Spacer(),
                      if (wide) ..._buildNavLinks(),
                      if (wide) const SizedBox(width: 24),
                      _pillButton(
                        'REQUEST A QUOTE',
                        onTap: () => _snack('Request a quote form opened'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(height: 1, color: kBorder),
        ],
      ),
    );
  }

  List<Widget> _buildNavLinks() {
    return _navItems.map((String item) {
      final bool active = item == 'Services';
      return InkWell(
        onTap: () => _snack('Navigate to $item'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            item.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: active ? kGreen : kInk,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _logo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.cabin_rounded, size: 32, color: kGreen),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              'GREENGATE',
              style: TextStyle(
                fontSize: 19,
                height: 1.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: kGreen,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'ENGINEERING & CONSTRUCTION',
              style: TextStyle(
                fontSize: 6.4,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Color(0xFF4A4A45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pillButton(String label, {VoidCallback? onTap, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14)}) {
    return Material(
      color: kGreen,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- HERO

  Widget _buildHero() {
    double screenW = 0;
    try {
      screenW = MediaQuery.of(context).size.width;
    } catch (_) {}
    final double leftPad = screenW > 1280 ? (screenW - 1280) / 2 + 24.0 : 32.0;

    return Container(
      color: kDark,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool wide = c.maxWidth >= 900;
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                  child: _heroCopy(narrow: true),
                ),
                SizedBox(height: 300, child: _heroImage()),
              ],
            );
          }
          return SizedBox(
            height: 620,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 46,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(leftPad, 56, 40, 56),
                    child: _heroCopy(narrow: false),
                  ),
                ),
                Expanded(
                  flex: 54,
                  child: _heroImage(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heroCopy({required bool narrow}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'HOME   /   SERVICES   /   BUILDING MATERIALS & HARDWARE',
          style: TextStyle(
            fontSize: narrow ? 9.5 : 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(width: 24, height: 2, color: kGreen),
            const SizedBox(width: 10),
            Text(
              'THE RIGHT MATERIAL, ON TIME',
              style: TextStyle(
                fontSize: narrow ? 10 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: kGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          narrow ? 'Building Materials & Hardware' : 'Building Materials\n& Hardware',
          style: TextStyle(
            fontSize: narrow ? 34 : 52,
            height: 1.06,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            'Building materials, hardware and tools for construction and improvement projects.',
            style: TextStyle(
              fontSize: narrow ? 15 : 17,
              height: 1.55,
              color: Colors.white.withOpacity(0.82),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroImage() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF9A9A92), Color(0xFF55554F), Color(0xFF2F2F2B)],
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.warehouse_outlined,
            size: 140,
            color: Colors.white.withOpacity(0.16),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black.withOpacity(0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Text(
              'Illustrative service image',
              style: TextStyle(fontSize: 10, color: Colors.white, letterSpacing: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- MAIN

  Widget _buildMain() {
    return ColoredBox(
      color: Colors.white,
      child: _Wrap(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool wide = c.maxWidth >= 860;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _sidebar(),
                    const SizedBox(height: 36),
                    _content(false),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 280, child: _sidebar()),
                  const SizedBox(width: 48),
                  Expanded(child: _content(true)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(top: BorderSide(color: kGreen, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Our services',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
          ),
          ...List<Widget>.generate(_services.length, (int i) {
            final bool selected = i == _selectedService;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedService = i);
                  _snack('Selected service: ${_services[i]}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Text(
                    _services[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? kGreen : kInk,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _content(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('THE NEED'),
        const SizedBox(height: 16),
        Text(
          'Greengate supplies hardware, tools and building materials for professional contractors, property owners and home-improvement projects, with guidance to help clients select suitable products.',
          style: TextStyle(
            fontSize: wide ? 24 : 18,
            height: 1.45,
            color: kBody,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 44),
        _label('TYPICAL DELIVERABLES'),
        const SizedBox(height: 20),
        _deliverablesTable(wide),
        const SizedBox(height: 44),
        _outcomeBox(),
        const SizedBox(height: 52),
        Container(height: 1, color: kBorder),
        const SizedBox(height: 44),
        _nextStep(wide),
      ],
    );
  }

  Widget _label(String text, {bool onDark = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 26, height: 2, color: kGreen),
        const SizedBox(width: 10),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: onDark ? Colors.white : kInk,
          ),
        ),
      ],
    );
  }

  Widget _deliverablesTable(bool wide) {
    if (!wide) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: kBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List<Widget>.generate(_deliverables.length, (int i) {
            return _cell(_deliverables[i], bottom: i != _deliverables.length - 1);
          }),
        ),
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < _deliverables.length; i += 2) {
      final bool hasSecond = i + 1 < _deliverables.length;
      final bool lastRow = i + 2 >= _deliverables.length;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _cell(_deliverables[i], right: true, bottom: !lastRow),
              ),
              Expanded(
                child: hasSecond
                    ? _cell(_deliverables[i + 1], right: false, bottom: !lastRow)
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _cell(String text, {bool right = false, bool bottom = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          right: right ? const BorderSide(color: kBorder) : BorderSide.none,
          bottom: bottom ? const BorderSide(color: kBorder) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '\u2713',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kGreen,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcomeBox() {
    return Container(
      color: kDark,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _label('THE OUTCOME', onDark: true),
          const SizedBox(height: 16),
          Text(
            'A practical one-stop source for quality building materials, tools and expert product guidance at competitive prices.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStep(bool wide) {
    final Widget heading = Text(
      'Make the scope clear before work begins.',
      style: TextStyle(
        fontSize: wide ? 34 : 26,
        height: 1.18,
        fontWeight: FontWeight.w800,
        color: kInk,
        letterSpacing: -0.3,
      ),
    );

    final Widget button = _pillButton(
      'DISCUSS THIS SERVICE',
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
      onTap: () => _snack('Let\'s discuss your building materials scope.'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('NEXT STEP'),
        const SizedBox(height: 18),
        if (wide)
          Row(
            children: <Widget>[
              Expanded(child: heading),
              const SizedBox(width: 32),
              button,
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: 22),
              button,
            ],
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- FOOTER

  Widget _buildFooter() {
    return Container(
      color: kBlack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Wrap(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool wide = c.maxWidth > 900;
                  final List<Widget> columns = <Widget>[
                    _footerBrand(),
                    _footerCol('COMPANY', <String>[
                      'About',
                      'Projects',
                      'Social',
                      'Materials',
                      'Contact',
                      'Privacy',
                    ]),
                    _footerCol('CAPABILITIES', <String>[
                      'Construction',
                      'Civil Engineering',
                      'Steel Fabrication',
                      'Aluminium Works',
                      'Architectural Design',
                      'Building Materials & Hardware',
                    ]),
                    _footerCol('SECTORS', <String>[
                      'Residential',
                      'Commercial',
                      'Industrial',
                      'Civil Infrastructure',
                      'Property development',
                    ]),
                    _footerContact(),
                  ];

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: columns[0]),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: columns[1]),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: columns[2]),
                        const SizedBox(width: 28),
                        Expanded(flex: 2, child: columns[3]),
                        const SizedBox(width: 28),
                        Expanded(flex: 3, child: columns[4]),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      columns[0],
                      const SizedBox(height: 36),
                      Wrap(
                        spacing: 48,
                        runSpacing: 32,
                        children: <Widget>[
                          columns[1],
                          columns[2],
                          columns[3],
                          columns[4],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Container(height: 1, color: Colors.white.withOpacity(0.10)),
          _Wrap(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Wrap(
                spacing: 24,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    '© 2026 Greengate Engineering & Construction (Pvt) Ltd',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  Wrap(
                    spacing: 22,
                    children: <Widget>[
                      _footerMiniLink('Designed by Rapid ICT Solutions'),
                      _footerMiniLink('Privacy'),
                      _footerMiniLink('Site manager'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerMicroLink(String text, {bool underline = false}) {
    return InkWell(
      onTap: () => _snack(text),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: Colors.white.withOpacity(0.55),
          decoration: underline ? TextDecoration.underline : TextDecoration.none,
          decorationColor: Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _footerBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _logo(),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bringing creative ideas to reality.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Greengate Engineering & Construction (Pvt) Ltd',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _snack('Opening Facebook page'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.facebook, size: 16, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 8),
              Text(
                'Follow on Facebook',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footerCol(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: kFooterMuted,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map(
          (String e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _snack('Open $e'),
              child: Text(
                e,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: kFooterLink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _footerContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'CONTACT',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: kFooterMuted,
          ),
        ),
        const SizedBox(height: 16),
        _contactRow(Icons.phone_in_talk_outlined, '+263 773 273 621'),
        _contactRow(Icons.phone_in_talk_outlined, '+263 716 127 991'),
        _contactRow(Icons.mail_outline, 'info@greengate.co.zw'),
        _contactRow(Icons.location_on_outlined,
            '5 Portland Road, Workington, Harare,\nZimbabwe'),
        _contactRow(Icons.access_time, 'Monday–Saturday, 09:00–17:00'),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.70)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: kFooterLink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- WHATSAPP

  Widget _buildWhatsApp() {
    return Material(
      color: kGreen,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _snack('Chat with us on WhatsApp'),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.chat, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ HELPERS

class _Wrap extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const _Wrap({
    required this.child,
    this.maxWidth = 1280,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}