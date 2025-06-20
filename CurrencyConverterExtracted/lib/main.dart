import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const CurrencyConverterApp());
}

class CurrencyConverterApp extends StatelessWidget {
  const CurrencyConverterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CurrencyConverterScreen(),
    );
  }
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({Key? key}) : super(key: key);

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final TextEditingController _amountController = TextEditingController();
  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'INR',
    'JPY',
    'AUD',
    'CAD'
  ];
  final List<String> _conversionHistory = [];

  String _fromCurrency = 'USD';
  String _toCurrency = 'INR';
  double? _convertedAmount;
  bool _isLoading = false;
  String? _error;
  int _conversionCount = 0;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  Timer? _bannerTimer;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadBannerAd();
    });
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId:
          'ca-app-pub-3940256099942544/9214589741', // Replace with your ad unit
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          setState(() {
            _isBannerAdReady = false;
          });
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId:
          'ca-app-pub-3940256099942544/1033173712', // Replace with your ad unit
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (err) {
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _showInterstitialAdIfNeeded() {
    _conversionCount++;
    if (_conversionCount >= 3 && _isInterstitialAdReady) {
      _interstitialAd?.show();
      _conversionCount = 0;
      _loadInterstitialAd();
    }
  }

  Future<void> _convertCurrency() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() {
        _error = "Please enter a valid number";
        _convertedAmount = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = 'https://api.exchangerate-api.com/v4/latest/$_fromCurrency';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['rates'][_toCurrency];
        if (rate != null) {
          setState(() {
            _convertedAmount = amount * rate;
            _conversionHistory.insert(
              0,
              "$amount $_fromCurrency = ${_convertedAmount!.toStringAsFixed(2)} $_toCurrency",
            );
          });
          _showInterstitialAdIfNeeded();
        } else {
          setState(() => _error = "Invalid target currency.");
        }
      } else {
        setState(() => _error = "API Error");
      }
    } catch (e) {
      setState(() => _error = "An error occurred: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdown(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: _currencies.map((currency) {
            return DropdownMenuItem<String>(
              value: currency,
              child: Text(currency),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Converter')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Enter amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          'From',
                          _fromCurrency,
                          (String? newValue) {
                            if (newValue != null) {
                              setState(() => _fromCurrency = newValue);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          'To',
                          _toCurrency,
                          (String? newValue) {
                            if (newValue != null) {
                              setState(() => _toCurrency = newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _convertCurrency,
                    child: const Text('Convert'),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red))
                  else if (_convertedAmount != null)
                    Text(
                      'Converted: ${_convertedAmount!.toStringAsFixed(2)} $_toCurrency',
                      style: const TextStyle(fontSize: 20),
                    ),
                  const Divider(height: 32),
                  const Text(
                    'Conversion History',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _conversionHistory.length,
                      itemBuilder: (context, index) {
                        return ListTile(title: Text(_conversionHistory[index]));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isBannerAdReady)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
