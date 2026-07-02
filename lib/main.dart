import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/stock_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stock_list_screen.dart';
import 'screens/delivery_register_screen.dart';
import 'screens/shipping_register_screen.dart';
import 'screens/history_screen.dart';
import 'screens/initial_stock_screen.dart';
import 'screens/period_summary_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
      ],
      child: const WireStockApp(),
    ),
  );
}

class WireStockApp extends StatelessWidget {
  const WireStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '村田鉄筋㈱ 結束線・タイワイヤ在庫管理',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // 日本語ロケール設定（DatePicker / MaterialLocalizations すべてを日本語化）
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

/// 認証状態に応じてログイン画面／メイン画面を切り替えるゲート。
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _stockInitialized = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const _LoadingScreen(message: '起動中...');
        }
        if (!auth.isLoggedIn) {
          _stockInitialized = false;
          return const LoginScreen();
        }
        // ログイン直後に在庫データを取得
        if (!_stockInitialized) {
          _stockInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<StockProvider>().initialize();
          });
        }
        return Consumer<StockProvider>(
          builder: (context, stock, _) {
            if (!stock.isInitialized && stock.isLoading) {
              return const _LoadingScreen(message: 'データ取得中…');
            }
            if (!stock.isInitialized && stock.lastError != null) {
              return _ErrorScreen(
                message: 'サーバーに接続できませんでした',
                detail: stock.lastError!,
                onRetry: () => context.read<StockProvider>().initialize(),
              );
            }
            return const MainScaffold();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;
  const _LoadingScreen({required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;
  const _ErrorScreen({
    required this.message,
    required this.detail,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,      label: 'ダッシュボード'),
    _NavItem(icon: Icons.inventory_2_outlined,    activeIcon: Icons.inventory_2,    label: '在庫一覧'),
    _NavItem(icon: Icons.add_circle_outline,      activeIcon: Icons.add_circle,     label: '納入登録'),
    _NavItem(icon: Icons.output_outlined,         activeIcon: Icons.output,         label: '出荷登録'),
    _NavItem(icon: Icons.history_outlined,        activeIcon: Icons.history,        label: '履歴'),
    _NavItem(icon: Icons.analytics_outlined,      activeIcon: Icons.analytics,      label: '期間集計'),
    _NavItem(icon: Icons.tune_outlined,           activeIcon: Icons.tune,           label: '在庫修正'),
  ];

  static const List<String> _titles = [
    'ダッシュボード',
    '在庫一覧',
    '納入登録',
    '出荷・使用登録',
    '履歴',
    '期間集計',
    '在庫修正',
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    StockListScreen(),
    DeliveryRegisterScreen(),
    ShippingRegisterScreen(),
    HistoryScreen(),
    PeriodSummaryScreen(),
    InitialStockScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<StockProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '村田鉄筋㈱ 在庫管理',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: '最新データに更新',
              onPressed: () => context.read<StockProvider>().refreshAll(),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            tooltip: 'アプリ情報',
            onPressed: () => _showAppInfo(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'ログアウト',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          // 7項目なので fixed タイプで全タブ常時表示
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: _navItems.map((item) {
            return BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.activeIcon),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('ログアウト'),
          ],
        ),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アプリ情報'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('村田鉄筋㈱',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('結束線・タイワイヤ在庫管理アプリ'),
            SizedBox(height: 12),
            Text('バージョン: 2.0.0（共有DB版）',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            SizedBox(height: 8),
            Text('管理品目:',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('・結束線（350mm〜700mm）',
                style: TextStyle(fontSize: 12)),
            Text('・メッキ結束線（350mm〜700mm）',
                style: TextStyle(fontSize: 12)),
            Text('・18番結束線（550mm・700mm）',
                style: TextStyle(fontSize: 12)),
            Text('・タイワイヤ', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('保管場所: 本社工場 / 第二工場',
                style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('データ保存: Cloudflare D1（全端末共有）',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.primaryGreen)),
            SizedBox(height: 8),
            Text('・現在庫＝最新の在庫修正数量＋修正日時以降の納入−修正日時以降の出荷',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}
