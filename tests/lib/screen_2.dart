import 'package:flutter/material.dart';

class Screen2 extends StatefulWidget {
  const Screen2({Key? key}) : super(key: key);

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  final Color primaryGreen = const Color(0xFF64B146);
  final Color darkText = const Color(0xFF1A1A1A);
  final Color lightText = const Color(0xFF666666);
  final Color bgLight = const Color(0xFFF8F8F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopBar(),
            _buildHeader(),
            _buildHero(),
            _buildFactsAndScope(),
            _buildGallery(),
            _buildRelatedService(),
            _buildGreenCTA(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF1F2421),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;
              return Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment:
                    isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Zimbabwean expertise. Practical delivery.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (isMobile) const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildTopBarLink('+263 773 273 621'),
                      _buildTopBarLink('+263 716 127 991'),
                      _buildTopBarLink('hello@greengate.co.zw'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarLink(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          text.contains('@') ? Icons.email_outlined : Icons.phone_outlined,
          size: 14,
          color: Colors.white70,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          return Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work, color: primaryGreen, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    'GREENGATE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (isMobile) const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildNavLink('HOME'),
                  _buildNavLink('ABOUT'),
                  _buildNavLink('SERVICES'),
                  _buildNavLink('PROJECTS', isActive: true),
                  _buildNavLink('SOCIAL'),
                  _buildNavLink('CONTACT'),
                ],
              ),
              if (isMobile) const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'REQUEST A QUOTE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavLink(String text, {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: darkText,
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 20,
            color: primaryGreen,
          ),
        ],
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      height: 500,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
              'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=1600&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.2),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('HOME', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(' / ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('PROJECTS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(' / ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('ASPINDALE PARK SHOWROOMS',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'RESIDENTIAL',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text('ASPINDALE PARK, HARARE',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Aspindale Park Showrooms',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Two completed residential showrooms at Aspindale Park, built by Greengate and presented through one combined exterior and interior gallery.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactsAndScope() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProjectFacts(),
                const SizedBox(height: 32),
                _buildScopeDetails(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildProjectFacts()),
              const SizedBox(width: 48),
              Expanded(flex: 2, child: _buildScopeDetails()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectFacts() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project facts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 24),
          _buildFactItem('SERVICE', 'Construction'),
          _buildFactItem('SECTOR', 'Residential'),
          _buildFactItem('LOCATION', 'Aspindale Park, Harare'),
          _buildFactItem('STATUS', 'Completed'),
          _buildFactItem('GREENGATE ROLE', 'Main contractor'),
        ],
      ),
    );
  }

  Widget _buildFactItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScopeItem(
          'Scope',
          'Construction delivery for two residential showrooms, including the completed exterior façades, internal rooms and visible finishing works.',
        ),
        const SizedBox(height: 24),
        _buildScopeItem(
          'Delivery',
          'The completed gallery records tiled internal floors, decorative ceiling details, fitted doors and windows, tiled wet-area walls, patterned external paving and stone-accented façades.',
        ),
        const SizedBox(height: 24),
        _buildScopeItem(
          'Outcomes',
          'Two completed showrooms ready for presentation at Aspindale Park.',
        ),
        const SizedBox(height: 24),
        _buildScopeItem(
          'Materials & systems',
          'Visible finishes include tiled floors, wall tiling in wet areas, aluminium-framed glazing, timber doors, paved external areas and stone-accent façade treatments.',
        ),
      ],
    );
  }

  Widget _buildScopeItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 24, height: 2, color: primaryGreen),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: darkText,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: lightText,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGallery() {
    final images = [
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600585154526-990dced4db0d?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600573472592-401b489a3cdc?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    ];
    final captions = [
      'Front elevation of the second completed residential showroom.',
      'Finished side elevation, roofline and glazing.',
      'Completed front elevation with stone-accent details.',
      'Completed side and rear elevation showing paved driveway.',
      'Open-plan interior with tiled floors and fitted doors.',
      'Completed internal room with tiled floor and coffered ceiling details.',
      'First elevation room with fitted floor and aluminium framed window.',
      'Second bedroom room with fitted floor and aluminium window.',
      'Completed rear depth patio with paved driveway.',
      'Front and side facade details.',
    ];

    return Container(
      color: bgLight,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 24, height: 2, color: primaryGreen),
              const SizedBox(width: 8),
              Text(
                'PROJECT GALLERY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The work in detail.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth < 600 ? 1 : 2;
              double spacing = 16;
              double itemWidth = crossAxisCount == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: List.generate(images.length, (index) {
                  return SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[index],
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          captions[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: lightText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedService() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;

          Widget leftSide = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RELATED SERVICE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Construction',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
            ],
          );

          Widget rightSide = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tailored residential, commercial and industrial construction solutions.',
                style: TextStyle(
                  fontSize: 14,
                  color: lightText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: primaryGreen),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'EXPLORE THE SERVICE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 14, color: primaryGreen),
                  ],
                ),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftSide,
                const SizedBox(height: 24),
                rightSide,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(flex: 1, child: leftSide),
              const SizedBox(width: 48),
              Expanded(flex: 1, child: rightSide),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGreenCTA() {
    return Container(
      color: primaryGreen,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;

          Widget textSide = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAN SOMETHING RELEVANT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black.withOpacity(0.6),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Bring the brief. We'll help shape the path.",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          );

          Widget buttonSide = ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: Text(
              'Start an enquiry',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textSide,
                const SizedBox(height: 24),
                buttonSide,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: textSide),
              const SizedBox(width: 24),
              buttonSide,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;
              return Wrap(
                spacing: isMobile ? 0 : 48,
                runSpacing: 32,
                children: [
                  SizedBox(
                    width: isMobile ? constraints.maxWidth : 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home_work, color: primaryGreen, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              'GREENGATE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bringing creative ideas to reality, from first sketch to final handover.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.facebook, color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Follow on Facebook',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildFooterLinksColumn('COMPANY',
                      ['About', 'Projects', 'Services', 'Social', 'Contact', 'Privacy']),
                  _buildFooterLinksColumn('CAPABILITIES', [
                    'Construction',
                    'Civil Engineering',
                    'Steel Fabrication',
                    'Aluminium Windows',
                    'Architectural Design',
                    'Quantity Surveying',
                    'Building Materials & Hardware'
                  ]),
                  _buildFooterLinksColumn('SECTORS', [
                    'Residential',
                    'Commercial',
                    'Industrial',
                    'Civil Engineering',
                    'Property Development'
                  ]),
                  SizedBox(
                    width: isMobile ? constraints.maxWidth : 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTACT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildContactItem(Icons.phone, '+263 773 273 621'),
                        _buildContactItem(Icons.phone, '+263 716 127 991'),
                        _buildContactItem(Icons.email, 'hello@greengate.co.zw'),
                        _buildContactItem(
                            Icons.location_on, '5 Rowland Rd, Willowvale, Harare, Zimbabwe'),
                        _buildContactItem(Icons.access_time, 'Mon–Fri: 08:00–16:30'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 48),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 800;
              return Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '© 2024 Greengate Projects & Construction. All rights reserved.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if (isMobile) const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Website by Digital Fervor',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 16),
                      Text('Privacy',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinksColumn(String title, List<String> links) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          ...links.map((link) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  link,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}