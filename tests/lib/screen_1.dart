import 'package:flutter/material.dart';

class Screen1 extends StatefulWidget {
  const Screen1({super.key});

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _greenBright = Color(0xFF4CAF50);
  static const Color _ink = Color(0xFF0F120F);
  static const Color _soft = Color(0xFFF3F5F1);
  static const Color _line = Color(0xFFE1E5DF);
  static const Color _muted = Color(0xFF5B6159);

  static const List<String> _navItems = <String>[
    'HOME',
    'ABOUT',
    'SERVICES',
    'PROJECTS',
    'SOCIAL',
    'CONTACT',
  ];

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

  String _selectedNav = 'SERVICES';
  String _selectedService = 'Building Materials & Hardware';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _whatsappButton(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _topBar(),
            _header(),
            _hero(),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _mainBody(),
            ),
            const SizedBox(height: 56),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- TOP BAR

  Widget _topBar() {
    return Container(
      color: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Widget tagline = Text(
            'Zimbabwean expertise. Practical delivery.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          );
          final Widget contacts = Wrap(
            spacing: 18,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _topContact(Icons.call_outlined, '+263 773 273 621'),
              _topContact(Icons.call_outlined, '+263 716 127 991'),
              _topContact(Icons.mail_outline, 'info@greengate.co.zw'),
            ],
          );
          if (c.maxWidth > 780) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[tagline, contacts],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              tagline,
              const SizedBox(height: 8),
              contacts,
            ],
          );
        },
      ),
    );
  }

  Widget _topContact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- HEADER

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool wide = c.maxWidth > 940;
          final Widget nav = Wrap(
            spacing: 22,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: wide ? WrapAlignment.end : WrapAlignment.start,
            children: <Widget>[
              ..._navItems.map(_navLink),
              _pillButton('REQUEST A QUOTE'),
            ],
          );
          if (wide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _logo(),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: nav,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _logo(),
              const SizedBox(height: 16),
              nav,
            ],
          );
        },
      ),
    );
  }

  Widget _logo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.home_work_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'GREENGATE',
              style: TextStyle(
                color: _green,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'ENGINEERING & CONSTRUCTION',
              style: TextStyle(
                color: _muted,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _navLink(String label) {
    final bool selected = label == _selectedNav;
    return InkWell(
      onTap: () => setState(() => _selectedNav = label),
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _green : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _green : _ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _pillButton(String label, {bool filled = true}) {
    return Material(
      color: filled ? _green : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: filled ? BorderSide.none : BorderSide(color: _green),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: filled ? Colors.white : _green,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- HERO

  Widget _hero() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth > 900;
        final Widget info = Container(
          color: _ink,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _breadcrumb(),
              const SizedBox(height: 28),
              _labelLight('THE RIGHT MATERIAL, ON TIME'),
              const SizedBox(height: 16),
              Text(
                'Building Materials\n& Hardware',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 44 : 34,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Building materials, hardware and tools for construction and improvement projects.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );

        final Widget image = _heroImage();

        if (wide) {
          return SizedBox(
            height: 430,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: info),
                Expanded(child: image),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            info,
            SizedBox(height: 240, child: image),
          ],
        );
      },
    );
  }

  Widget _breadcrumb() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          'HOME',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text('/', style: TextStyle(color: Colors.white24, fontSize: 11)),
        Text(
          'SERVICES',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        Text('/', style: TextStyle(color: Colors.white24, fontSize: 11)),
        Text(
          'BUILDING MATERIALS & HARDWARE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _heroImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF44513F),
            const Color(0xFF1D251E),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black.withOpacity(0.55),
              child: Text(
                'Illustrative service image',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelLight(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 28, height: 2, color: _greenBright),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 28, height: 2, color: _ink),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- MAIN BODY

  Widget _mainBody() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 300, child: _sidebar()),
              const SizedBox(width: 44),
              Expanded(child: _content()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _sidebar(),
            const SizedBox(height: 32),
            _content(),
          ],
        );
      },
    );
  }

  Widget _sidebar() {
    return Container(
      decoration: BoxDecoration(
        color: _soft,
        border: Border(
          top: BorderSide(color: _green, width: 3),
          left: BorderSide(color: _green, width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Our services',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ..._services.map(_serviceTile),
        ],
      ),
    );
  }

  Widget _serviceTile(String name) {
    final bool selected = name == _selectedService;
    return InkWell(
      onTap: () => setState(() => _selectedService = name),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? _green : _ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionLabel('THE NEED'),
        const SizedBox(height: 16),
        Text(
          'Greengate supplies hardware, tools and building materials for professional contractors, property owners and home-improvement projects, with guidance to help clients select suitable products.',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 32),
        _sectionLabel('TYPICAL DELIVERABLES'),
        const SizedBox(height: 16),
        _deliverablesGrid(),
        const SizedBox(height: 32),
        _outcomeBox(),
        const SizedBox(height: 32),
        Divider(color: _line, height: 1),
        const SizedBox(height: 32),
        _nextStep(),
      ],
    );
  }

  Widget _deliverablesGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool twoCol = c.maxWidth > 560;
        final List<Widget> rows = <Widget>[];

        if (twoCol) {
          for (int i = 0; i < _deliverables.length; i += 2) {
            final bool hasSecond = i + 1 < _deliverables.length;
            final bool bottomLine = i + 2 < _deliverables.length;
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: _deliverableCell(
                        _deliverables[i],
                        rightLine: hasSecond,
                        bottomLine: bottomLine,
                      ),
                    ),
                    if (hasSecond)
                      Expanded(
                        child: _deliverableCell(
                          _deliverables[i + 1],
                          rightLine: false,
                          bottomLine: bottomLine,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        } else {
          for (int i = 0; i < _deliverables.length; i++) {
            rows.add(
              _deliverableCell(
                _deliverables[i],
                rightLine: false,
                bottomLine: i < _deliverables.length - 1,
              ),
            );
          }
        }

        return Container(
          decoration: BoxDecoration(border: Border.all(color: _line)),
          child: Column(children: rows),
        );
      },
    );
  }

  Widget _deliverableCell(
    String text, {
    required bool rightLine,
    required bool bottomLine,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          right: rightLine ? BorderSide(color: _line) : BorderSide.none,
          bottom: bottomLine ? BorderSide(color: _line) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check, size: 16, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _ink, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcomeBox() {
    return Container(
      color: _ink,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(width: 28, height: 2, color: _greenBright),
              const SizedBox(width: 10),
              Text(
                'THE OUTCOME',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'A practical one-stop source for quality building materials, tools and expert product guidance at competitive prices.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStep() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth > 620;
        final Widget title = Text(
          'Make the scope clear before work begins.',
          style: TextStyle(
            color: _ink,
            fontSize: wide ? 34 : 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        );
        final Widget button = _pillButton('Discuss this service');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _sectionLabel('NEXT STEP'),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: title),
                  const SizedBox(width: 24),
                  button,
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  title,
                  const SizedBox(height: 20),
                  button,
                ],
              ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------------- FOOTER

  Widget _footer() {
    return Container(
      color: _ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(height: 4, color: _green),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: 36,
                  runSpacing: 36,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 250, child: _footerBrand()),
                    SizedBox(
                      width: 140,
                      child: _footerColumn('COMPANY', <String>[
                        'About',
                        'Projects',
                        'Social',
                        'Materials',
                        'Contact',
                        'Privacy',
                      ]),
                    ),
                    SizedBox(
                      width: 190,
                      child: _footerColumn('CAPABILITIES', <String>[
                        'Construction',
                        'Civil Engineering',
                        'Steel Fabrication',
                        'Aluminium Works',
                        'Architectural Design',
                        'Building Materials & Hardware',
                      ]),
                    ),
                    SizedBox(
                      width: 170,
                      child: _footerColumn('SECTORS', <String>[
                        'Residential',
                        'Commercial',
                        'Industrial',
                        'Civil Infrastructure',
                        'Property development',
                      ]),
                    ),
                    SizedBox(width: 230, child: _footerContact()),
                  ],
                ),
                const SizedBox(height: 36),
                Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  spacing: 16,
                  children: <Widget>[
                    Text(
                      '© 2026 Greengate Engineering & Construction (Pty) Ltd',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: <Widget>[
                        Text(
                          'Designed by Rapid ICT Solutions',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Privacy',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          'Site manager',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: _logo(),
        ),
        const SizedBox(height: 18),
        Text(
          'Bringing creative ideas to reality.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Greengate Engineering & Construction (Pvt) Ltd',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.facebook, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              'Follow on Facebook',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footerColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        ...items.map(
          (String item) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(
              item,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
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
        Text(
          'CONTACT',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _footerContactRow(Icons.call_outlined, '+263 773 273 621'),
        _footerContactRow(Icons.call_outlined, '+263 716 127 991'),
        _footerContactRow(Icons.mail_outline, 'info@greengate.co.zw'),
        _footerContactRow(
          Icons.location_on_outlined,
          '5 Portland Road, Workington, Harare, Zimbabwe',
        ),
        _footerContactRow(
          Icons.schedule,
          'Monday - Saturday, 09:00 - 17:00',
        ),
      ],
    );
  }

  Widget _footerContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- FLOATING

  Widget _whatsappButton() {
    return FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: _green,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: Icon(Icons.chat_bubble_outline, size: 18),
      label: Text(
        'WhatsApp',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}