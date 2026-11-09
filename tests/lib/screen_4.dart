import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Screen4(),
  ));
}

const Color kGreen = Color(0xFF3EA83C);
const Color kInk = Color(0xFF141414);
const Color kMuted = Color(0xFF6C6C6C);
const Color kBg = Color(0xFFF4F4F1);
const Color kBorder = Color(0xFFE3E3DF);
const Color kBody = Color(0xFF4A4A4A);

class Screen4 extends StatefulWidget {
  const Screen4({super.key});

  @override
  State<Screen4> createState() => _Screen4State();
}

class _Screen4State extends State<Screen4> {
  String _activeNav = 'Projects';
  int _enquiries = 0;

  static const List<List<String>> _facts = [
    ['Service', 'Construction'],
    ['Sector', 'Residential'],
    ['Location', 'Aspindale Park, Harare'],
    ['Status', 'Completed'],
    ['Greengate role', 'Main contractor'],
  ];

  static const List<List<String>> _details = [
    [
      'Scope',
      'Construction delivery for two residential showrooms, including the completed exterior façades, internal rooms and visible finishing works.'
    ],
    [
      'Delivery',
      'The completed gallery records tiled internal floors, decorative ceiling details, fitted doors and windows, tiled wet-area walls, patterned external paving and stone-accent façades.'
    ],
    [
      'Outcome',
      'Two completed showrooms ready for presentation at Aspindale Park.'
    ],
    [
      'Materials & systems',
      'Visible finishes include tiled floors, wall tiling in wet areas, aluminium-framed glazing, timber doors, paved external areas and stone-accent façade treatments.'
    ],
  ];

  static const List<String> _galleryCaptions = [
    'Front elevation of the second completed residential showroom.',
    'Finished side elevation, roofline and glazing.',
    'Completed frontage with paved external finishes.',
    'Completed rear and side elevations following works.',
    'Open-plan interior with tiled floors and fitted doors.',
    'Completed internal walls and decorative ceiling details.',
    'Fitted timber doors, glazing and interior finishes.',
    'Comprehensive finishes and aluminium frames.',
    'Completed wall finishing and tiling works.',
    'Internal glazing as part of the finished building.',
  ];

  void _snack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kInk,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            _buildHeader(),
            _buildHero(),
            _buildProjectBody(),
            _buildGallery(),
            _buildRelated(),
            _buildCta(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 760;
      final contact = Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _topContact(Icons.call_outlined, '+263 773 273 621'),
          _topContact(Icons.call_outlined, '+263 716 127 991'),
          _topContact(Icons.mail_outline, '[email protected]'),
        ],
      );
      return Container(
        color: kInk,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: wide
                ? Row(
                    children: [
                      const Text(
                        'Zimbabwean expertise. Practical delivery.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      contact,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zimbabwean expertise. Practical delivery.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      contact,
                    ],
                  ),
          ),
        ),
      );
    });
  }

  Widget _topContact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _snack('Greengate home'),
                    child: _logo(),
                  ),
                  const SizedBox(width: 20),
                  if (wide)
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 6,
                        children: [
                          _navLink('Home'),
                          _navLink('About'),
                          _navLink('Services'),
                          _navLink('Projects'),
                          _navLink('Social'),
                          _navLink('Contact'),
                          const SizedBox(width: 10),
                          _pill(
                            'REQUEST A QUOTE',
                            onTap: () => _snack('Quote request opened'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const Spacer(),
                    IconButton(
                      onPressed: () => _snack('Menu opened'),
                      icon: const Icon(Icons.menu, color: kInk),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _logo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kGreen,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.home_work_outlined,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'GREENGATE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1.8,
                color: kGreen,
              ),
            ),
            Text(
              'C O N S T R U C T I O N',
              style: TextStyle(
                fontSize: 6.5,
                letterSpacing: 1.2,
                color: kMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _navLink(String label) {
    final active = _activeNav == label;
    return InkWell(
      onTap: () {
        setState(() => _activeNav = label);
        _snack('$label tapped');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? kInk : kMuted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: active ? 16 : 0,
              color: kGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    String label, {
    required VoidCallback onTap,
    Color bg = kGreen,
    Color fg = Colors.white,
    bool outlined = false,
  }) {
    return Material(
      color: outlined ? Colors.transparent : bg,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: outlined ? Border.all(color: Colors.white30) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------
  Widget _buildHero() {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 700;
      return Container(
        height: narrow ? 470 : 400,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA7B6BF), Color(0xFF66757F), Color(0xFF36424A)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(40),
                      Colors.black.withAlpha(190),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.apartment,
                    color: Colors.white.withAlpha(35), size: 40),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _breadcrumb(),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _tag('RESIDENTIAL'),
                            _tag('ASPINDALE PARK, HARARE'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Aspindale Park Showrooms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: narrow ? 30 : 44,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Text(
                            'Two completed residential showrooms at Aspindale Park, built by Greengate and presented through one combined exterior and interior gallery.',
                            style: TextStyle(
                              color: Colors.white.withAlpha(215),
                              fontSize: narrow ? 13 : 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _breadcrumb() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _crumb('HOME', false),
        _crumbSep(),
        _crumb('PROJECTS', false),
        _crumbSep(),
        _crumb('ASPINDALE PARK SHOWROOMS', true),
      ],
    );
  }

  Widget _crumb(String text, bool current) {
    return InkWell(
      onTap: () => _snack('$text tapped'),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          letterSpacing: 1.2,
          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
          color: current ? Colors.white : Colors.white60,
        ),
      ),
    );
  }

  Widget _crumbSep() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '/',
        style: TextStyle(fontSize: 9.5, color: Colors.white38),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROJECT FACTS + DETAILS
  // ---------------------------------------------------------------------------
  Widget _buildProjectBody() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 46),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 820;
            final facts = _factsCard();
            final details = _detailsColumn();
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: facts),
                  const SizedBox(width: 56),
                  Expanded(child: details),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                facts,
                const SizedBox(height: 34),
                details,
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _factsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project facts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 2, width: 64, color: kInk),
          const SizedBox(height: 22),
          for (int i = 0; i < _facts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _facts[i][0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.3,
                      color: kMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _facts[i][1],
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kInk,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _details.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _details.length - 1 ? 0 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 18, height: 2, color: kInk),
                    const SizedBox(width: 8),
                    Text(
                      _details[i][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _details[i][1],
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    color: kBody,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GALLERY
  // ---------------------------------------------------------------------------
  Widget _buildGallery() {
    return Container(
      color: kBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 46),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 24, height: 2, color: kGreen),
                  const SizedBox(width: 10),
                  const Text(
                    'PROJECT GALLERY',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'The work in detail.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 26),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 760 ? 2 : 1;
                const gap = 18.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (int i = 0; i < _galleryCaptions.length; i++)
                      SizedBox(
                        width: w - 0.5,
                        child: _galleryTile(i, _galleryCaptions[i]),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryTile(int index, String caption) {
    final palettes = [
      [const Color(0xFFC9D2D6), const Color(0xFF8798A1)],
      [const Color(0xFFCFD6D2), const Color(0xFF8B9A93)],
      [const Color(0xFFD6D2C9), const Color(0xFF9A9287)],
      [const Color(0xFFCDD3D9), const Color(0xFF8593A0)],
    ];
    final colors = palettes[index % palettes.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _snack('Gallery image ${index + 1} opened'),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 32,
                    color: Colors.white.withAlpha(110),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          caption,
          style: const TextStyle(
            fontSize: 11.5,
            color: kMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // RELATED CAPABILITY
  // ---------------------------------------------------------------------------
  Widget _buildRelated() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 720;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'RELATED CAPABILITY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: kMuted,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Construction',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ],
            );
            final right = Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 28,
              runSpacing: 12,
              children: [
                const SizedBox(
                  width: 240,
                  child: Text(
                    'Tailored residential, commercial and industrial construction solutions.',
                    style: TextStyle(fontSize: 12, color: kBody, height: 1.5),
                  ),
                ),
                InkWell(
                  onTap: () => _snack('Explore the service'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'EXPLORE THE SERVICE',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 13, color: kInk),
                    ],
                  ),
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      left,
                      const Spacer(),
                      right,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      left,
                      const SizedBox(height: 18),
                      right,
                    ],
                  );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA
  // ---------------------------------------------------------------------------
  Widget _buildCta() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 760;
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 22, height: 2, color: Colors.white70),
                    const SizedBox(width: 10),
                    const Text(
                      'PLAN SOMETHING RELEVANT',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  "Bring the brief. We'll help shape the path.",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            );
            final button = _pill(
              'Start an enquiry',
              bg: kInk,
              onTap: () {
                setState(() => _enquiries++);
                _snack('Enquiry started ($_enquiries)');
              },
            );
            return wide
                ? Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 24),
                      button,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text,
                      const SizedBox(height: 22),
                      button,
                    ],
                  );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER
  // ---------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      color: kInk,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 46, 20, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Wrap(
                  spacing: 40,
                  runSpacing: 32,
                  children: [
                    SizedBox(width: 260, child: _footerBrand()),
                    SizedBox(
                      width: 130,
                      child: _footerColumn(
                          'COMPANY', ['About', 'Projects', 'Social', 'Reviews', 'Privacy']),
                    ),
                    SizedBox(
                      width: 175,
                      child: _footerColumn('CAPABILITIES', [
                        'Construction',
                        'Civil Engineering',
                        'Steel Fabrication',
                        'Aluminium Works',
                        'Architectural Design',
                        'Quantity Surveying',
                      ]),
                    ),
                    SizedBox(
                      width: 140,
                      child: _footerColumn('SECTORS', [
                        'Residential',
                        'Commercial',
                        'Industrial',
                        'Civil Engineering',
                        'Project Development',
                      ]),
                    ),
                    SizedBox(width: 230, child: _footerContact()),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 1, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    const Text(
                      '© 2025 Greengate Projects (a company) Ltd.',
                      style: TextStyle(fontSize: 10.5, color: Colors.white38),
                    ),
                    Wrap(
                      spacing: 18,
                      children: [
                        _bottomLink('Designed and built by Greengate'),
                        _bottomLink('Privacy'),
                        _bottomLink('Terms'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.home_work_outlined,
                  color: kGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'GREENGATE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'C O N S T R U C T I O N',
                  style: TextStyle(
                    fontSize: 6,
                    letterSpacing: 1.2,
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Bringing creative ideas to real, measurable outcomes.',
          style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.link, size: 12, color: Colors.white54),
            const SizedBox(width: 6),
            _bottomLink('LinkedIn'),
            const SizedBox(width: 14),
            _bottomLink('Facebook'),
          ],
        ),
      ],
    );
  }

  Widget _footerColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () => _snack('$item tapped'),
              child: Text(
                item,
                style: const TextStyle(fontSize: 11.5, color: Colors.white60),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footerContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTACT',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        _footerContactRow(Icons.call_outlined, '+263 773 273 621'),
        _footerContactRow(Icons.call_outlined, '+263 716 127 991'),
        _footerContactRow(Icons.mail_outline, '[email protected]'),
        _footerContactRow(Icons.place_outlined, '5 Rowland Rd, Avondale, Harare'),
        _footerContactRow(Icons.schedule, 'Mon–Fri 08:00 – 17:00'),
      ],
    );
  }

  Widget _footerContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomLink(String text) {
    return InkWell(
      onTap: () => _snack('$text tapped'),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, color: Colors.white38),
      ),
    );
  }
}