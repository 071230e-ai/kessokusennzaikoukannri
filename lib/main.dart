import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/stock_item.dart';
import 'models/delivery_record.dart';
import 'models/shipping_record.dart';
import 'providers/stock_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stock_list_screen.dart';
import 'screens/delivery_register_screen.dart';
import 'screens/shipping_register_screen.dart';
import 'screens/history_screen.dart';
import 'screens/initial_stock_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(StockItemAdapter());
  Hive.registerAdapter(DeliveryRecordAdapter());
  Hive.registerAdapter(ShippingRecordAdapter());

  await Hive.openBox<StockItem>(StockProvider.stockBoxName);
  await Hive.openBox<DeliveryRecord>(StockProvider.deliveryBoxName);
  await Hive.openBox<ShippingRecord>(StockProvider.shippingBoxName);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StockProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
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
      home: const _AuthGate(),
    );
  }
}

/// 認証状態に応じてログイン画面／メイン画面を切り替えるゲート。
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // SharedPreferences 読み込み中はスプラッシュ表示
        if (!auth.isInitialized) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F5),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return const MainScaffold();
      },
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

  // ナビゲーション定義（6タブ）
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,      label: 'ダッシュボード'),
    _NavItem(icon: Icons.inventory_2_outlined,    activeIcon: Icons.inventory_2,    label: '在庫一覧'),
    _NavItem(icon: Icons.add_circle_outline,      activeIcon: Icons.add_circle,     label: '納入登録'),
    _NavItem(icon: Icons.output_outlined,         activeIcon: Icons.output,         label: '出荷登録'),
    _NavItem(icon: Icons.history_outlined,        activeIcon: Icons.history,        label: '履歴'),
    _NavItem(icon: Icons.tune_outlined,           activeIcon: Icons.tune,           label: '初期在庫'),
  ];

  static const List<String> _titles = [
    'ダッシュボード',
    '在庫一覧',
    '納入登録',
    '出荷・使用登録',
    '履歴',
    '初期在庫設定',
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    StockListScreen(),
    DeliveryRegisterScreen(),
    ShippingRegisterScreen(),
    HistoryScreen(),
    InitialStockScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
            Text('バージョン: 1.1.0',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            SizedBox(height: 8),
            Text('管理品目:',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('・結束線（350mm〜700mm）',
                style: TextStyle(fontSize: 12)),
            Text('・18番結束線（550mm・700mm）',
                style: TextStyle(fontSize: 12)),
            Text('・タイワイヤ', style: TextStyle(fontSize: 12)),
            SizedBox(height: 8),
            Text('機能:',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text('・初期在庫設定（新機能）',
                style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
            Text('・現在庫＝初期在庫＋納入−出荷・使用',
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
