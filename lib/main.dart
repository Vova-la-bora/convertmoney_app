import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(Converter());
}

class Converter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConverterPage(),
    );
  }
}

// ================= Модель =================

class Rates {
  final String base;
  final Map<String, double> rates;
  final DateTime time;

  Rates(this.base, this.rates, this.time);

  factory Rates.fromJson(Map<String, dynamic> j) {
    if (j['result'] != 'success') {
      throw ApiException('Сервер вернул ошибку: ${j['error-type']}');
    }
    Map<String, double> m = {};
    (j['rates'] as Map<String, dynamic>).forEach((k, v) {
      m[k] = (v as num).toDouble();
    });
    DateTime t = DateTime.fromMillisecondsSinceEpoch(
      (j['time_last_update_unix'] as int) * 1000,
    );
    return Rates(j['base_code'], m, t);
  }
}

class ApiException implements Exception {
  final String msg;
  ApiException(this.msg);

  @override
  String toString() => msg;
}

// ================= ApiClient =================

class ApiClient {
  String url = 'https://open.er-api.com/v6/latest/';

  Future<Map<String, dynamic>> get(String base) async {
    http.Response r;
    try {
      r = await http.get(Uri.parse(url + base)).timeout(Duration(seconds: 10));
    } on SocketException {
      throw ApiException('Нет подключения к интернету');
    } on http.ClientException {
      throw ApiException('Нет подключения к интернету');
    } on TimeoutException {
      throw ApiException('Сервер не отвечает');
    }

    if (r.statusCode != 200) {
      throw ApiException('Ошибка сервера: ${r.statusCode}');
    }

    try {
      return jsonDecode(r.body);
    } catch (e) {
      throw ApiException('Некорректный ответ сервера');
    }
  }
}

// ================= Repository =================

class CurrencyRepository {
  ApiClient api = ApiClient();

  Future<Rates> load(String base) async {
    Map<String, dynamic> j = await api.get(base);
    try {
      return Rates.fromJson(j);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Некорректный ответ сервера');
    }
  }
}

// ================= State =================

enum Status { idle, loading, success, error }

class ConverterState extends ChangeNotifier {
  CurrencyRepository repo = CurrencyRepository();

  List<String> cools = [
    'EUR',
    'RUB',
    'USD',
    'CNY',
    'GBP',
    'JPY',
    'KZT',
    'TRY',
    'THB',
    'VND',
  ];
  String from = 'EUR';
  String to = 'RUB';

  Status st = Status.idle;
  String err = '';

  double sumka = 0;
  double resultato = 0;
  double rate = 0;
  String rf = '';
  String rt = '';
  DateTime? time;

  void setFrom(String v) {
    from = v;
    notifyListeners();
  }

  void setTo(String v) {
    to = v;
    notifyListeners();
  }

  void swap(String t) {
    String x = from;
    from = to;
    to = x;
    if (st == Status.success) {
      convert(t);
    } else {
      notifyListeners();
    }
  }

  void e(String m) {
    err = m;
    st = Status.error;
    notifyListeners();
  }

  Future<void> convert(String t) async {
    if (st == Status.loading) return;

    t = t.trim().replaceAll(',', '.');
    if (t == '') {
      e('Введите сумму');
      return;
    }

    double? a = double.tryParse(t);
    if (a == null || !a.isFinite) {
      e('Некорректная сумма');
      return;
    }
    if (a <= 0) {
      e('Сумма должна быть больше нуля');
      return;
    }

    String f = from;
    String o = to;
    st = Status.loading;
    notifyListeners();

    try {
      Rates r = await repo.load(f);
      double? k = r.rates[o];
      if (k == null) throw ApiException('Курс $f → $o не найден');
      sumka = a;
      rate = k;
      resultato = a * k;
      rf = f;
      rt = o;
      time = r.time;
      st = Status.success;
    } on ApiException catch (x) {
      err = x.msg;
      st = Status.error;
    }
    notifyListeners();
  }
}

// ================= UI =================

class ConverterPage extends StatefulWidget {
  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  ConverterState c = ConverterState();
  TextEditingController t = TextEditingController();

  @override
  void dispose() {
    t.dispose();
    c.dispose();
    super.dispose();
  }

  String f(double x) {
    if (x < 0.01) return x.toStringAsPrecision(3);
    return x.toStringAsFixed(2);
  }

  String k(double x) {
    if (x < 0.01) return x.toStringAsPrecision(4);
    return x.toStringAsFixed(4);
  }

  String d(DateTime x) {
    String z(int v) => v.toString().padLeft(2, '0');
    return '${z(x.day)}.${z(x.month)}.${x.year} ${z(x.hour)}:${z(x.minute)}';
  }

  Widget drop(String v, void Function(String) on) {
    return Expanded(
      child: DropdownButton<String>(
        value: v,
        isExpanded: true,
        items: c.cools
            .map(
              (k) => DropdownMenuItem(
                value: k,
                child: Text(k, style: TextStyle(fontSize: 20)),
              ),
            )
            .toList(),
        onChanged: c.st == Status.loading
            ? null
            : (k) {
                if (k != null) on(k);
              },
      ),
    );
  }

  Widget card() {
    if (c.st == Status.loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (c.st == Status.error) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  c.err,
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (c.st == Status.success) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${f(c.sumka)} ${c.rf} =',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                '${f(c.resultato)} ${c.rt}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('Курс: 1 ${c.rf} = ${k(c.rate)} ${c.rt}'),
              Text('Обновлено: ${d(c.time!)}'),
            ],
          ),
        ),
      );
    }
    return SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Конвертер валют')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          bool l = c.st == Status.loading;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: t,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  style: TextStyle(fontSize: 22),
                  decoration: InputDecoration(
                    labelText: 'Сумма',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    drop(c.from, c.setFrom),
                    IconButton(
                      icon: Icon(Icons.swap_horiz, size: 32),
                      onPressed: l ? null : () => c.swap(t.text),
                    ),
                    drop(c.to, c.setTo),
                  ],
                ),
                SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: l
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            c.convert(t.text);
                          },
                    child: Text(
                      'Конвертировать',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                card(),
              ],
            ),
          );
        },
      ),
    );
  }
}
