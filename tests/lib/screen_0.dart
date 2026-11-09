import 'package:flutter/material.dart';

class Screen0 extends StatefulWidget {
  const Screen0({super.key});

  @override
  State<Screen0> createState() => _Screen0State();
}

class _Screen0State extends State<Screen0> {
  int _openFaq = 0;

  final Color dark = const Color(0xFF0F110F);
  final Color dark2 = const Color(0xFF181B18);
  final Color dark3 = const Color(0xFF20241F);
  final Color green = const Color(0xFF3E8B4C);
  final Color brightGreen = const Color(0xFF47A85B);
  final Color lightBg = const Color(0xFFF2F2EC);
  final Color cardBg = const Color(0xFFFBFBF8);
  final Color muted = const Color(0xFF71766F);
  final Color lineColor = const Color(0xFFE3E3DB);

  final List<List<String>> services = <List<String>>[
    <String>['01', 'Construction', 'Tailored residential, commercial and industrial construction solutions.'],
    <String>['02', 'Civil Engineering', 'Civil engineering for large- and small-scale development projects.'],
    <String>['03', 'Steel Fabrication', 'Structural steel detailing, design, fabrication and erection.'],
    <String>['04', 'Aluminium Works', 'Custom aluminium products for residential, commercial and industrial projects.'],
    <String>['05', 'Architectural Design', 'Civil and structural design coordination around the client objectives.'],
    <String>['06', 'Building Materials & Hardware', 'Building materials, hardware and tools for construction and industrial projects.'],
  ];

  final List<IconData> serviceIcons = <IconData>[
    Icons.construction,
    Icons.terrain,
    Icons.grid_on,
    Icons.window,
    Icons.architecture,
    Icons.handyman,
  ];

  final List<List<String>> faqs = <List<String>>[
    <String>[
      'Can Greengate support a project from design through construction?',
      'Yes. Greengate coordinates design, engineering, fabrication and site delivery under one accountable team, so you deal with a single point of responsibility from concept to handover.'
    ],
    <String>[
      'What information should I share when requesting a quote?',
      'Site location, drawings or sketches, intended scope, preferred timelines and any approvals already in place help us price quickly and accurately.'
    ],
    <String>[
      'What types of projects does Greengate work on?',
      'Residential, commercial, industrial and civil infrastructure projects across Zimbabwe, from small works to full design-and-build packages.'
    ],
    <String>[
      'Does Greengate work with landowners and investors?',
      'Yes. We work with private landowners, developers, contractors and investor-led project teams, and we are comfortable joining a project at any stage.'
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 900;
    final double hPad = isWide ? 48.0 : 20.0;

    return Scaffold(
      backgroundColor: dark,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _topBar(isWide, hPad),
            _header(isWide, hPad),
            _hero(isWide, hPad),
            _speakBar(isWide, hPad),
            _servicesSection(isWide, hPad),
            _featuredSection(isWide, hPad),
            _whySection(isWide, hPad),
            _fieldSection(isWide, hPad),
            _faqSection(isWide, hPad),
            _ctaSection(isWide, hPad),
            _footerSection(isWide, hPad),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

  Widget _label(String text, Color color, {Color? lineColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 20, height: 2, color: lineColor ?? color),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactItem(IconData icon, String text, {Color? color, double size = 11}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: size + 1, color: color ?? Colors.white38),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color ?? Colors.white70, fontSize: size)),
      ],
    );
  }

  Widget _pillButton(
    String text, {
    bool outlined = false,
    Color? background,
    Color? textColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : (background ?? green),
        borderRadius: BorderRadius.circular(30),
        border: outlined ? Border.all(color: borderColor ?? Colors.white38) : null,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _logo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.change_history, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'GREENGATE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ENGINEERING & CONSTRUCTION',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 6.5,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- top bar

  Widget _topBar(bool isWide, double hPad) {
    final Widget tagline = Text(
      'Zimbabwean expertise. Practical delivery.',
      style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.2),
    );

    final List<Widget> contacts = <Widget>[
      _contactItem(Icons.phone_in_talk_outlined, '+263 773 273 621'),
      _contactItem(Icons.phone_in_talk_outlined, '+263 716 127 991'),
      _contactItem(Icons.mail_outline, '[email protected]'),
    ];

    return Container(
      color: dark,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 9),
      child: isWide
          ? Row(
              children: <Widget>[
                Expanded(child: tagline),
                ...contacts.map(
                  (Widget c) => Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: c,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                tagline,
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 6, children: contacts),
              ],
            ),
    );
  }

  // ----------------------------------------------------------------- header

  Widget _header(bool isWide, double hPad) {
    final List<String> navItems = <String>[
      'Home',
      'About',
      'Services',
      'Projects',
      'Social',
      'Contact'
    ];

    return Container(
      color: dark,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
      child: Row(
        children: <Widget>[
          _logo(),
          if (isWide) ...<Widget>[
            const SizedBox(width: 24),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  ...navItems.map(
                    (String item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _pillButton('Request a quote'),
                ],
              ),
            ),
          ] else ...<Widget>[
            const Spacer(),
            Icon(Icons.menu, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- hero

  Widget _hero(bool isWide, double hPad) {
    final double titleSize = isWide ? 52 : 33;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF44513D),
            const Color(0xFF232C1F),
            const Color(0xFF0C100B),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -60,
            top: 20,
            child: Opacity(
              opacity: 0.09,
              child: Icon(Icons.location_city, size: 340, color: Colors.white),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.16),
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: isWide ? 76 : 44,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _label('Engineering · Construction · Fabrication', brightGreen),
                const SizedBox(height: 22),
                Text(
                  'Built with purpose.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    height: 1.06,
                    letterSpacing: -1.4,
                  ),
                ),
                Text(
                  'Delivered with precision.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    height: 1.06,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Text(
                    'Design, civil works, fabrication and construction delivery under one accountable Greengate team.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _pillButton('Request a project consultation'),
                    _pillButton('View completed projects', outlined: true),
                  ],
                ),
                const SizedBox(height: 38),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <String>[
                    'Zimbabwean expertise',
                    'Practical delivery',
                    'One accountable team',
                  ].map((String t) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: brightGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- speak bar

  Widget _speakBar(bool isWide, double hPad) {
    final List<Widget> right = <Widget>[
      _contactItem(Icons.phone_in_talk_outlined, '+263 773 273 621',
          color: Colors.white60, size: 11),
      _contactItem(Icons.phone_in_talk_outlined, '+263 716 127 991',
          color: Colors.white60, size: 11),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.chat_bubble_outline, size: 12, color: brightGreen),
            const SizedBox(width: 6),
            Text(
              'WhatsApp',
              style: TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
      ),
    ];

    return Container(
      color: dark2,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 14),
      child: isWide
          ? Row(
              children: <Widget>[
                Text(
                  'SPEAK WITH GREENGATE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                ...right.map(
                  (Widget w) => Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: w,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SPEAK WITH GREENGATE',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 18, runSpacing: 10, children: right),
              ],
            ),
    );
  }

  // --------------------------------------------------------------- services

  Widget _servicesSection(bool isWide, double hPad) {
    final double available = MediaQuery.of(context).size.width - hPad * 2;
    final int cols = isWide ? 3 : 1;
    final double cardW = (available - (cols - 1) * 20) / cols;

    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('What we deliver', green),
        const SizedBox(height: 14),
        Text(
          'Capability across the whole project.',
          style: TextStyle(
            color: dark,
            fontSize: isWide ? 34 : 26,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );

    final Widget description = Text(
      'From the first drawing to site delivery, Greengate connects the disciplines needed to move work forward with clarity.',
      style: TextStyle(color: muted, fontSize: 12.5, height: 1.7),
    );

    return Container(
      color: lightBg,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 64 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(flex: 3, child: heading),
                const SizedBox(width: 48),
                Expanded(flex: 1, child: description),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading,
                const SizedBox(height: 16),
                description,
              ],
            ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: List<Widget>.generate(services.length, (int i) {
              return _serviceCard(cardW, services[i], serviceIcons[i]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(double w, List<String> item, IconData icon) {
    return Container(
      width: w,
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 148,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF5A6653),
                  const Color(0xFF2A322A),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Center(
                  child: Icon(icon, size: 44, color: Colors.white24),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Text(
                    'ILLUSTRATIVE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 7,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      item[0],
                      style: TextStyle(
                        color: muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.north_east, size: 14, color: muted),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  item[1],
                  style: TextStyle(
                    color: dark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item[2],
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Illustrative service image',
                  style: TextStyle(color: Colors.black26, fontSize: 8.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- featured

  Widget _featuredSection(bool isWide, double hPad) {
    final Widget image = Container(
      height: isWide ? 400 : 230,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF8FA6B8),
            const Color(0xFF5B6E58),
            const Color(0xFF2C332B),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(Icons.home_work_outlined, size: 90, color: Colors.white24),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Text(
              'ASPINDALE PARK SHOWROOMS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 8,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget panel = Container(
      color: dark,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _label('Featured project', brightGreen),
          const SizedBox(height: 16),
          Text(
            'Aspindale Park Showrooms',
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 26 : 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Two completed residential showrooms at Aspindale Park, built by Greengate and finished through our in-house carpentry and interior joinery.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 22),
          _specRow('Sector', 'Construction'),
          _specRow('Discipline', 'Design & Build'),
          _specRow('Type', 'Stand-Alone'),
          _specRow('Status', 'Completed'),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Text(
                'VIEW THE FULL CASE STUDY',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.north_east, size: 12, color: brightGreen),
            ],
          ),
        ],
      ),
    );

    return Container(
      color: lightBg,
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, isWide ? 64 : 32),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: image),
                Expanded(child: panel),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[image, panel],
            ),
    );
  }

  Widget _specRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- why

  Widget _whySection(bool isWide, double hPad) {
    final List<List<String>> values = <List<String>>[
      <String>[
        'Professionalism',
        'We uphold high standards in our operations and in every client interaction.'
      ],
      <String>[
        'Excellence',
        'We strive for superior quality in every project and every stage of delivery.'
      ],
      <String>[
        'Teamwork',
        'We collaborate effectively with clients, professionals and project stakeholders.'
      ],
    ];

    final List<List<String>> steps = <List<String>>[
      <String>['01', 'Define', 'Clarify the brief, constraints and the outcomes that matter.'],
      <String>['02', 'Coordinate', 'Align design, engineering, material and trades before build.'],
      <String>['03', 'Deliver', 'Manage the work with practical milestones and clear reporting.'],
      <String>['04', 'Handover', 'Complete the build, explain the systems and stand behind the work.'],
    ];

    final Widget leftBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('Why Greengate', brightGreen),
        const SizedBox(height: 16),
        Text(
          'Practical thinking before work begins.',
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 34 : 26,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );

    final Widget rightBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values.map((List<String> v) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: RichText(
            text: TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: v[0] + '  ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: v[1],
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    final List<Widget> stepWidgets = steps.map((List<String> s) {
      return _stepBlock(s[0], s[1], s[2]);
    }).toList();

    return Container(
      color: dark,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 64 : 44,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: leftBlock),
                const SizedBox(width: 56),
                Expanded(child: rightBlock),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                leftBlock,
                const SizedBox(height: 24),
                rightBlock,
              ],
            ),
          const SizedBox(height: 44),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 28),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.generate(stepWidgets.length, (int i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == stepWidgets.length - 1 ? 0 : 26,
                    ),
                    child: stepWidgets[i],
                  ),
                );
              }),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: stepWidgets
                  .map((Widget w) => Padding(
                        padding: const EdgeInsets.only(bottom: 26),
                        child: w,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _stepBlock(String number, String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          number,
          style: TextStyle(
            color: brightGreen,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.6),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ field

  Widget _fieldSection(bool isWide, double hPad) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('From the field', green),
        const SizedBox(height: 14),
        Text(
          'Current work, directly from Greengate.',
          style: TextStyle(
            color: dark,
            fontSize: isWide ? 34 : 26,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );

    final Widget description = Text(
      'Explore company-owned site imagery alongside the automatically updated timeline from Greengate’s official Facebook page.',
      style: TextStyle(color: muted, fontSize: 12.5, height: 1.7),
    );

    final Widget card1 = _fieldCard(
      label: 'Greengate Site Insight',
      title: 'Construction progress, seen from the field.',
      link: 'Follow the work on Facebook',
      icon: Icons.apartment,
    );

    final Widget card2 = _fieldCard(
      label: 'Recent Post',
      title: 'A practical delivery by an accountable team.',
      link: 'Follow the work on Facebook',
      icon: Icons.foundation,
    );

    return Container(
      color: lightBg,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 64 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(flex: 3, child: heading),
                const SizedBox(width: 48),
                Expanded(flex: 1, child: description),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading,
                const SizedBox(height: 16),
                description,
              ],
            ),
          const SizedBox(height: 32),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: card1),
                      const SizedBox(width: 16),
                      Expanded(child: card2),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _facebookPanel()),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                card1,
                const SizedBox(height: 16),
                card2,
                const SizedBox(height: 16),
                _facebookPanel(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fieldCard({
    required String label,
    required String title,
    required String link,
    required IconData icon,
  }) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF6E7C68),
            const Color(0xFF3A443A),
            const Color(0xFF12160F),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Center(
            child: Icon(icon, size: 70, color: Colors.white12),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _label(label, Colors.white70, lineColor: brightGreen),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Text(
                      link,
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.north_east, size: 10, color: Colors.white38),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _facebookPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _label('Live from Facebook', muted, lineColor: brightGreen),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.change_history,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'GREENGATE ENGINEERING...',
                      style: TextStyle(
                        color: dark,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Facebook page',
                      style: TextStyle(color: muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.open_in_new, size: 11, color: dark),
                    const SizedBox(width: 6),
                    Text(
                      'View page',
                      style: TextStyle(color: dark, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEA),
              border: Border.all(color: lineColor),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.image_outlined, size: 26, color: Colors.black26),
                  const SizedBox(height: 8),
                  Text(
                    'Latest post preview',
                    style: TextStyle(color: Colors.black26, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Posts are pulled automatically from the official Greengate Facebook page.',
            style: TextStyle(color: muted, fontSize: 9.5, height: 1.6),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- faq

  Widget _faqSection(bool isWide, double hPad) {
    final Widget left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('Questions, answered', green),
        const SizedBox(height: 14),
        Text(
          'Plan the next conversation.',
          style: TextStyle(
            color: dark,
            fontSize: isWide ? 32 : 25,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Useful with the information you already have. Use this page to help prepare the practical next step.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.7),
          ),
        ),
      ],
    );

    final List<Widget> items = List<Widget>.generate(faqs.length, (int i) {
      return _faqItem(i, faqs[i][0], faqs[i][1]);
    });

    return Container(
      color: lightBg,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 64 : 40,
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2, child: left),
                const SizedBox(width: 56),
                Expanded(flex: 3, child: Column(children: items)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                left,
                const SizedBox(height: 26),
                ...items,
              ],
            ),
    );
  }

  Widget _faqItem(int index, String question, String answer) {
    final bool open = _openFaq == index;

    return Column(
      children: <Widget>[
        InkWell(
          onTap: () {
            setState(() {
              _openFaq = open ? -1 : index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 28,
                  child: Text(
                    index < 9 ? '0${index + 1}' : '${index + 1}',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ),
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      color: dark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  open ? Icons.remove : Icons.add,
                  size: 16,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 28, right: 28, bottom: 16),
            child: Text(
              answer,
              style: TextStyle(color: muted, fontSize: 11.5, height: 1.7),
            ),
          ),
        Container(height: 1, color: lineColor),
      ],
    );
  }

  // -------------------------------------------------------------------- cta

  Widget _ctaSection(bool isWide, double hPad) {
    final Widget left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(width: 20, height: 2, color: Colors.black45),
            const SizedBox(width: 10),
            Text(
              'START A CONVERSATION',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Have a site, a drawing or an early idea?',
          style: TextStyle(
            color: const Color(0xFF0B1A0D),
            fontSize: isWide ? 30 : 23,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 10,
          children: <Widget>[
            _contactItem(Icons.phone_in_talk_outlined, '+263 773 273 621',
                color: const Color(0xFF0B1A0D), size: 11.5),
            _contactItem(Icons.phone_in_talk_outlined, '+263 716 127 991',
                color: const Color(0xFF0B1A0D), size: 11.5),
          ],
        ),
      ],
    );

    final Widget button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        'REQUEST A QUOTE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );

    return Container(
      color: brightGreen,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 44 : 32,
      ),
      child: isWide
          ? Row(
              children: <Widget>[
                Expanded(child: left),
                const SizedBox(width: 24),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                left,
                const SizedBox(height: 22),
                button,
              ],
            ),
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _footerSection(bool isWide, double hPad) {
    final Widget brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _logo(),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Text(
            'Bright, creative ideas to reality.',
            style: TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.7),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.flag_outlined, size: 12, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Zimbabwean owned',
                style: TextStyle(color: Colors.white54, fontSize: 9.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Icon(Icons.facebook, size: 16, color: Colors.white38),
            const SizedBox(width: 14),
            Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white38),
            const SizedBox(width: 14),
            Icon(Icons.mail_outline, size: 16, color: Colors.white38),
          ],
        ),
      ],
    );

    final Widget company = _footerCol('Company', <String>[
      'Home',
      'About',
      'Projects',
      'Social',
      'Insights',
      'Privacy',
    ]);

    final Widget capabilities = _footerCol('Capabilities', <String>[
      'Construction',
      'Civil Engineering',
      'Steel Fabrication',
      'Aluminium Works',
      'Architectural Design',
      'Building Materials & Hardware',
    ]);

    final Widget sectors = _footerCol('Sectors', <String>[
      'Residential',
      'Commercial',
      'Industrial',
      'Civil Infrastructure',
      'Property Development',
    ]);

    final Widget contact = _footerCol('Contact', <String>[
      '+263 773 273 621',
      '+263 716 127 991',
      'info@greengate.co.zw',
      '146 Kingston Rd, Marlborough, Harare',
      'Monday–Saturday, 08:00–17:00',
    ]);

    final Widget copyright = Text(
      '© 2025 Greengate Engineering & Construction (Pvt) Ltd',
      style: TextStyle(color: Colors.white38, fontSize: 10),
    );

    return Container(
      color: dark,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isWide ? 52 : 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2, child: brand),
                const SizedBox(width: 24),
                Expanded(child: company),
                Expanded(child: capabilities),
                Expanded(child: sectors),
                Expanded(child: contact),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                brand,
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: company),
                    Expanded(child: capabilities),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: sectors),
                    Expanded(child: contact),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 36),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 20),
          isWide
              ? Row(
                  children: <Widget>[
                    Expanded(child: copyright),
                    Text(
                      'Crafted by Third Octet Solutions · Privacy · Sitemap',
                      style: TextStyle(color: Colors.white24, fontSize: 9.5),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    copyright,
                    const SizedBox(height: 10),
                    Text(
                      'Crafted by Third Octet Solutions · Privacy · Sitemap',
                      style: TextStyle(color: Colors.white24, fontSize: 9.5),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _footerCol(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        ...items.map(
          (String item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              item,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}