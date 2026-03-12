import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/super_user_theme.dart';

class SuperUserEarlyWarningScreen extends StatefulWidget {
  const SuperUserEarlyWarningScreen({super.key});

  @override
  State<SuperUserEarlyWarningScreen> createState() =>
      _SuperUserEarlyWarningScreenState();
}

class _SuperUserEarlyWarningScreenState
    extends State<SuperUserEarlyWarningScreen> {
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;

  String get _supabaseUrl => SupabaseService.supabaseUrl;
  String get _supabaseKey => SupabaseService.supabaseAnonKey;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/enhanced-weather-alert'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseKey',
        },
        body: jsonEncode({
          'latitude': 14.262585,
          'longitude': 121.398436,
          'city': 'LSPU Sta. Cruz Campus, Laguna, Philippines',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherData = data['weather_data'] ?? data;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load weather data: $e';
        _isLoading = false;
      });
    }
  }

  String _getTemperature() {
    if (_weatherData == null) return '--°C';
    final main = _weatherData!['main'];
    final temp = main?['temp'] ?? 0;
    return '${temp.round()}°C';
  }

  /// Match AccuWeather: current/next hour (first period), same as admin.
  int? _rainChancePercent() {
    if (_weatherData == null) return null;
    num? raw;
    final summary = _weatherData!['forecast_summary'];
    if (summary is Map) {
      final list = summary['next_24h_forecast'];
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is Map && first['rain_chance'] != null) raw = first['rain_chance'] as num;
      }
      if (raw == null && summary['next_24h_max_rain_chance'] != null) {
        raw = summary['next_24h_max_rain_chance'] as num;
      }
    }
    raw ??= _weatherData!['pop'];
    if (raw == null || raw is! num) return null;
    final p = raw <= 1 ? (raw * 100).round() : raw.round().clamp(0, 100);
    return p;
  }

  String _getRainChance() {
    final p = _rainChancePercent();
    return p == null ? '--%' : '$p%';
  }

  String _getWeatherCondition() {
    if (_weatherData == null) return 'Clear sky';
    final weather = _weatherData!['weather'];
    if (weather is List && weather.isNotEmpty) {
      return weather[0]['description'] ?? 'Clear sky';
    }
    return 'Clear sky';
  }

  IconData _getWeatherIcon() {
    if (_weatherData == null) return Icons.wb_sunny;
    final weather = _weatherData!['weather'];
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour >= 18;
    final clearIcon = isNight ? Icons.nightlight_round : Icons.wb_sunny;
    final cloudIcon = isNight ? Icons.nightlight_round : Icons.cloud;
    if (weather is List && weather.isNotEmpty) {
      final main = (weather[0]['main'] ?? '').toString().toLowerCase();
      if (main.contains('rain')) return Icons.grain;
      if (main.contains('cloud')) return cloudIcon;
      if (main.contains('clear')) return clearIcon;
      if (main.contains('thunderstorm')) return Icons.flash_on;
    }
    return clearIcon;
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return const Color(0xFFef4444);
      case 'medium':
        return const Color(0xFFf97316);
      case 'low':
        return const Color(0xFF10b981);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SuTheme.bg,
      appBar: AppBar(
        title: const Text(
          'Early Warning',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: SuTheme.appBarGradient,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadWeatherData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: SuTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading weather...',
                    style: TextStyle(
                      color: SuTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfef2f2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadWeatherData,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SuTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeatherData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weather Overview Card — Super User header gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: SuTheme.headerCardGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: SuTheme.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Weather',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    _getWeatherIcon(),
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTemperature(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _getWeatherCondition(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildWeatherMetric(
                                      'Rain Chance',
                                      _getRainChance(),
                                      Icons.water_drop,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildWeatherMetric(
                                      'Location',
                                      'LSPU Campus',
                                      Icons.location_on,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Risk Assessment Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: SuTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFf59e0b).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFf59e0b),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Risk Assessment',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1e293b),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildRiskItem('Flood Risk', 'Low'),
                              const SizedBox(height: 12),
                              _buildRiskItem('Storm Risk', 'Low'),
                              const SizedBox(height: 12),
                              _buildRiskItem('Heat Risk', 'Low'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Alert History
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: SuTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: SuTheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Recent Alerts',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1e293b),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No recent alerts',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWeatherMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String label, String risk) {
    final color = _getRiskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              risk.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

