import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: AppBar(
        title: const Text(
          'Safety Tips',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3b82f6), Color(0xFF2563eb)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3b82f6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stay Safe',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Essential emergency procedures and contacts',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Emergency Procedures Section
            _buildSectionHeader(
              icon: Icons.warning_rounded,
              title: 'Emergency Procedures',
              iconColor: const Color(0xFFef4444),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProcedureCard(
                    title: 'Earthquake Safety',
                    icon: Icons.waves,
                    procedures: [
                      _ProcedureItem(action: 'DROP', description: 'Drop to the ground immediately'),
                      _ProcedureItem(action: 'COVER', description: 'Take cover under a sturdy table or desk'),
                      _ProcedureItem(action: 'HOLD ON', description: 'Hold onto the table leg until shaking stops'),
                      _ProcedureItem(action: 'EVACUATE', description: 'Follow evacuation routes to designated areas'),
                    ],
                    borderColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProcedureCard(
                    title: 'Fire Safety',
                    icon: Icons.local_fire_department,
                    procedures: [
                      _ProcedureItem(action: 'ALERT', description: 'Pull fire alarm and call emergency services'),
                      _ProcedureItem(action: 'EVACUATE', description: 'Use nearest exit, never use elevators'),
                      _ProcedureItem(action: 'ASSEMBLE', description: 'Gather at designated assembly points'),
                      _ProcedureItem(action: 'ACCOUNT', description: 'Report to safety officers for headcount'),
                    ],
                    borderColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Emergency Training Videos Section
            _buildSectionHeader(
              icon: Icons.video_camera_back,
              title: 'Emergency Training Videos',
              iconColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 16),
            _buildVideoCard(
              context: context,
              title: 'First Aid',
              icon: Icons.favorite,
              iconColor: Colors.red,
              videoUrl: 'https://www.youtube.com/embed/TsJ49Np3HS0',
            ),
            const SizedBox(height: 12),
            _buildVideoCard(
              context: context,
              title: 'Earthquake Drill',
              icon: Icons.waves,
              iconColor: Colors.grey.shade800,
              videoUrl: 'https://www.youtube.com/embed/BLEPakj1YTY',
            ),
            const SizedBox(height: 12),
            _buildVideoCard(
              context: context,
              title: 'Fire Drill',
              icon: Icons.local_fire_department,
              iconColor: Colors.grey.shade800,
              videoUrl: 'https://www.youtube.com/embed/kPWyiscBrfk',
            ),
            const SizedBox(height: 32),

            // Evacuation Routes Section
            _buildSectionHeader(
              icon: Icons.map,
              title: 'Evacuation Routes & Assembly Points',
              iconColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 16),
            _buildEvacuationRouteCard(
              title: 'Primary Evacuation Area',
              icon: Icons.location_on,
              location: 'Main Quadrangle / Open Field',
              capacity: '2,000+ people',
              features: [
                'Open space away from buildings',
                'First aid station available',
                'Emergency supplies storage',
              ],
            ),
            const SizedBox(height: 12),
            _buildEvacuationRouteCard(
              title: 'Secondary Evacuation Areas',
              icon: Icons.location_city,
              location: 'Multiple Locations',
              capacity: 'Various',
              features: [
                'Gymnasium (Building 15)',
                'Library (Building 8)',
                'Auditorium (Building 12)',
                'Parking Area (North Side)',
              ],
            ),
            const SizedBox(height: 32),

            // Emergency Contacts Section
            _buildSectionHeader(
              icon: Icons.phone,
              title: 'Emergency Contacts',
              iconColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context: context,
              title: 'MDRRMO',
              subtitle: 'Municipal Disaster Risk Reduction and Management Office',
              phone: '0921-962-0602',
              landline: '(049) 557-1047',
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context: context,
              title: 'PDRRMO',
              subtitle: 'Provincial Disaster Risk Reduction and Management Office',
              phone: '0917 417 3698',
              landline: '(049) 501-4672',
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context: context,
              title: 'BFP',
              subtitle: 'Bureau of Fire Protection',
              phone: '0917 417 3698',
              landline: '(049) 501-0004',
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context: context,
              title: 'Police Station',
              subtitle: 'Emergency Services',
              phone: '0928-465-3820',
              landline: '501-5971',
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context: context,
              title: 'Medical Emergency',
              subtitle: 'Laguna Doctors Hospital',
              phone: '(049) 501-3218',
              landline: '',
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              context: context,
              title: 'Medical Emergency',
              subtitle: 'Laguna Medical Center',
              phone: '(049) 543-333',
              landline: '',
            ),
            const SizedBox(height: 32),

            // Safety Tips & Reminders Section
            _buildSectionHeader(
              icon: Icons.lightbulb,
              title: 'Safety Tips & Reminders',
              iconColor: Colors.grey.shade800,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTipsCard(
                    title: 'Before an Emergency',
                    tips: [
                      'Familiarize yourself with evacuation routes',
                      'Know the location of emergency exits',
                      'Keep emergency contact numbers handy',
                      'Participate in emergency drills',
                    ],
                    iconColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTipsCard(
                    title: 'During an Emergency',
                    tips: [
                      'Stay calm and follow instructions',
                      'Use designated evacuation routes',
                      'Help others if it\'s safe to do so',
                      'Report to assembly points for headcount',
                    ],
                    iconColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e293b),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcedureCard({
    required String title,
    required IconData icon,
    required List<_ProcedureItem> procedures,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: borderColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...procedures.asMap().entries.map((entry) {
              final index = entry.key;
              final procedure = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [borderColor, borderColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            procedure.action,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1e293b),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            procedure.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String videoUrl,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e293b),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(
                    builder: (context) {
                      // Extract video ID from embed URL
                      String videoId = '';
                      if (videoUrl.contains('/embed/')) {
                        videoId = videoUrl.split('/embed/').last.split('?').first;
                      } else if (videoUrl.contains('watch?v=')) {
                        videoId = videoUrl.split('watch?v=').last.split('&').first;
                      } else {
                        videoId = videoUrl.split('/').last.split('?').first;
                      }
                      
                      return Image.network(
                        'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Convert embed URL to watch URL
                  String watchUrl = videoUrl;
                  if (videoUrl.contains('/embed/')) {
                    final videoId = videoUrl.split('/embed/').last.split('?').first;
                    watchUrl = 'https://www.youtube.com/watch?v=$videoId';
                  }
                  
                  try {
                    final url = Uri.parse(watchUrl);
                    final launched = await launcher.launchUrl(
                      url,
                      mode: launcher.LaunchMode.externalApplication,
                    );
                    
                    if (!launched && context.mounted) {
                      _showVideoUrlDialog(context, watchUrl);
                    }
                  } catch (e) {
                    // If launch fails, show dialog with URL so user can copy it
                    if (context.mounted) {
                      _showVideoUrlDialog(context, watchUrl);
                    }
                  }
                },
                icon: const Icon(Icons.play_circle_filled, size: 20),
                label: const Text(
                  'Watch Video',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3b82f6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvacuationRouteCard({
    required String title,
    required IconData icon,
    required String location,
    required String capacity,
    required List<String> features,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10b981).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10b981).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10b981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF10b981), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10b981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (location != 'Multiple Locations') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFf0fdf4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: Color(0xFF10b981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people, color: Color(0xFF10b981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          capacity,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10b981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required String subtitle,
    required String phone,
    required String landline,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFf59e0b).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf59e0b).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFf59e0b).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone_in_talk,
                color: Color(0xFFf59e0b),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf59e0b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (phone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Color(0xFF10b981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (landline.isNotEmpty)
                    const SizedBox(height: 4),
                  if (landline.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone_forwarded, size: 14, color: Color(0xFF10b981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            landline,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard({
    required String title,
    required List<String> tips,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showVideoUrlDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Open Video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unable to open video automatically. Please copy the URL below and open it in your browser:'),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _ProcedureItem {
  final String action;
  final String description;

  _ProcedureItem({required this.action, required this.description});
}

