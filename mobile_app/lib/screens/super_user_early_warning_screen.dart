import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

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

  String _getRainChance() {
    if (_weatherData == null) return '--%';
    final pop = _weatherData!['pop'];
    if (pop != null) {
      return '${((pop as num) * 100).round()}%';
    }
    return '--%';
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
    if (weather is List && weather.isNotEmpty) {
      final main = (weather[0]['main'] ?? '').toString().toLowerCase();
      if (main.contains('rain')) return Icons.grain;
      if (main.contains('cloud')) return Icons.cloud;
      if (main.contains('clear')) return Icons.wb_sunny;
      if (main.contains('thunderstorm')) return Icons.flash_on;
    }
    return Icons.wb_sunny;
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
      appBar: AppBar(
        title: const Text(
          'Early Warning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeatherData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadWeatherData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWeatherData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weather Overview Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1e293b),
                                Color(0xFF0f172a),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3b82f6).withOpacity(0.3),
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
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      color: Color(0xFFf59e0b)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Risk Assessment',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
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
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent Alerts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recent alerts',
                                style: TextStyle(color: Colors.grey.shade600),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getRiskColor(risk).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            risk.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _getRiskColor(risk),
            ),
          ),
        ),
      ],
    );
  }
}

