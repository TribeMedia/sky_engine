// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of stocks;

typedef void ModeUpdater(StockMode mode);

const Duration _kSnackbarSlideDuration = const Duration(milliseconds: 200);

class StockHome extends StatefulComponent {

  StockHome(this.navigator, this.stocks, this.stockMode, this.modeUpdater);

  Navigator navigator;
  List<Stock> stocks;
  StockMode stockMode;
  ModeUpdater modeUpdater;

  void syncFields(StockHome source) {
    navigator = source.navigator;
    stocks = source.stocks;
    stockMode = source.stockMode;
    modeUpdater = source.modeUpdater;
  }

  bool _isSearching = false;
  String _searchQuery;

  AnimationStatus _snackBarStatus = AnimationStatus.dismissed;
  bool _isSnackBarShowing = false;

  void _handleSearchBegin() {
    navigator.pushState(this, (_) {
      setState(() {
        _isSearching = false;
        _searchQuery = null;
      });
    });
    setState(() {
      _isSearching = true;
    });
  }

  void _handleSearchEnd() {
    assert(navigator.currentRoute is RouteState);
    assert((navigator.currentRoute as RouteState).owner == this); // TODO(ianh): remove cast once analyzer is cleverer
    navigator.pop();
    setState(() {
      _isSearching = false;
      _searchQuery = null;
    });
  }

  void _handleSearchQueryChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  bool _drawerShowing = false;
  AnimationStatus _drawerStatus = AnimationStatus.dismissed;

  void _handleOpenDrawer() {
    setState(() {
      _drawerShowing = true;
      _drawerStatus = AnimationStatus.forward;
    });
  }

  void _handleDrawerDismissed() {
    setState(() {
      _drawerStatus = AnimationStatus.dismissed;
    });
  }

  bool _menuShowing = false;
  AnimationStatus _menuStatus = AnimationStatus.dismissed;

  void _handleMenuShow() {
    setState(() {
      _menuShowing = true;
      _menuStatus = AnimationStatus.forward;
    });
  }

  void _handleMenuHide() {
    setState(() {
      _menuShowing = false;
    });
  }

  void _handleMenuDismissed() {
    setState(() {
      _menuStatus = AnimationStatus.dismissed;
    });
  }

  bool _autorefresh = false;
  void _handleAutorefreshChanged(bool value) {
    setState(() {
      _autorefresh = value;
    });
  }

  EventDisposition _handleStockModeChange(StockMode value) {
    setState(() {
      stockMode = value;
    });
    if (modeUpdater != null)
      modeUpdater(value);
    return EventDisposition.processed;
  }

  Drawer buildDrawer() {
    if (_drawerStatus == AnimationStatus.dismissed)
      return null;
    assert(_drawerShowing); // TODO(mpcomplete): this is always true
    return new Drawer(
      level: 3,
      showing: _drawerShowing,
      onDismissed: _handleDrawerDismissed,
      navigator: navigator,
      children: [
        new DrawerHeader(children: [new Text('Stocks')]),
        new DrawerItem(
          icon: 'action/assessment',
          selected: true,
          children: [new Text('Stock List')]),
        new DrawerItem(
          icon: 'action/account_balance',
          children: [new Text('Account Balance')]),
        new DrawerDivider(),
        new DrawerItem(
          icon: 'action/thumb_up',
          onPressed: () => _handleStockModeChange(StockMode.optimistic),
          children: [
            new Flexible(child: new Text('Optimistic')),
            new Radio(value: StockMode.optimistic, groupValue: stockMode, onChanged: _handleStockModeChange)
          ]),
        new DrawerItem(
          icon: 'action/thumb_down',
          onPressed: () => _handleStockModeChange(StockMode.pessimistic),
          children: [
            new Flexible(child: new Text('Pessimistic')),
            new Radio(value: StockMode.pessimistic, groupValue: stockMode, onChanged: _handleStockModeChange)
          ]),
        new DrawerDivider(),
        new DrawerItem(
          icon: 'action/settings',
          onPressed: _handleShowSettings,
          children: [new Text('Settings')]),
        new DrawerItem(
          icon: 'action/help',
          children: [new Text('Help & Feedback')])
     ]
    );
  }

  EventDisposition _handleShowSettings() {
    navigator.pop();
    navigator.pushNamed('/settings');
    return EventDisposition.processed;
  }

  Widget buildToolBar() {
    return new ToolBar(
        left: new IconButton(
          icon: "navigation/menu",
          onPressed: _handleOpenDrawer),
        center: new Text('Stocks'),
        right: [
          new IconButton(
            icon: "action/search",
            onPressed: _handleSearchBegin),
          new IconButton(
            icon: "navigation/more_vert",
            onPressed: _handleMenuShow)
        ]
      );
  }

  int selectedTabIndex = 0;
  List<String> portfolioSymbols = ["AAPL","FIZZ", "FIVE", "FLAT", "ZINC", "ZNGA"];

  Iterable<Stock> _filterByPortfolio(Iterable<Stock> stocks) {
    return stocks.where((stock) => portfolioSymbols.contains(stock.symbol));
  }

  Iterable<Stock> _filterBySearchQuery(Iterable<Stock> stocks) {
    if (_searchQuery == null)
      return stocks;
    RegExp regexp = new RegExp(_searchQuery, caseSensitive: false);
    return stocks.where((stock) => stock.symbol.contains(regexp));
  }

  Widget buildMarketStockList() {
    return new Stocklist(stocks: _filterBySearchQuery(stocks).toList());
  }

  Widget buildPortfolioStocklist() {
    return new Stocklist(stocks: _filterBySearchQuery(_filterByPortfolio(stocks)).toList());
  }

  Widget buildTabNavigator() {
    List<TabNavigatorView> views = <TabNavigatorView>[
      new TabNavigatorView(
        label: const TabLabel(text: 'MARKET'),
        builder: buildMarketStockList
      ),
      new TabNavigatorView(
        label: const TabLabel(text: 'PORTFOLIO'),
        builder: buildPortfolioStocklist
      )
    ];
    return new TabNavigator(
      views: views,
      selectedIndex: selectedTabIndex,
      onChanged: (tabIndex) {
        setState(() { selectedTabIndex = tabIndex; } );
      }
    );
  }

  static GlobalKey searchFieldKey = new GlobalKey();

  // TODO(abarth): Should we factor this into a SearchBar in the framework?
  Widget buildSearchBar() {
    return new ToolBar(
      left: new IconButton(
        icon: "navigation/arrow_back",
        color: Theme.of(this).accentColor,
        onPressed: _handleSearchEnd
      ),
      center: new Input(
        key: searchFieldKey,
        placeholder: 'Search stocks',
        onChanged: _handleSearchQueryChanged
      ),
      backgroundColor: Theme.of(this).canvasColor
    );
  }

  void _handleUndo() {
    setState(() {
      _isSnackBarShowing = false;
    });
  }

  Anchor _snackBarAnchor = new Anchor();
  Widget buildSnackBar() {
    if (_snackBarStatus == AnimationStatus.dismissed)
      return null;
    return new SnackBar(
      showing: _isSnackBarShowing,
      anchor: _snackBarAnchor,
      content: new Text("Stock purchased!"),
      actions: [new SnackBarAction(label: "UNDO", onPressed: _handleUndo)],
      onDismissed: () { setState(() { _snackBarStatus = AnimationStatus.dismissed; }); }
    );
  }

  void _handleStockPurchased() {
    setState(() {
      _isSnackBarShowing = true;
      _snackBarStatus = AnimationStatus.forward;
    });
  }

  Widget buildFloatingActionButton() {
    return _snackBarAnchor.build(
      new FloatingActionButton(
        child: new Icon(type: 'content/add', size: 24),
        backgroundColor: colors.RedAccent[200],
        onPressed: _handleStockPurchased
      ));
  }

  void addMenuToOverlays(List<Widget> overlays) {
    if (_menuStatus == AnimationStatus.dismissed)
      return;
    overlays.add(new ModalOverlay(
      children: [new StockMenu(
        showing: _menuShowing,
        onDismissed: _handleMenuDismissed,
        navigator: navigator,
        autorefresh: _autorefresh,
        onAutorefreshChanged: _handleAutorefreshChanged
      )],
      onDismiss: _handleMenuHide));
  }

  Widget build() {
    List<Widget> overlays = [
      new Scaffold(
        toolbar: _isSearching ? buildSearchBar() : buildToolBar(),
        body: buildTabNavigator(),
        snackBar: buildSnackBar(),
        floatingActionButton: buildFloatingActionButton(),
        drawer: buildDrawer()
      ),
    ];
    addMenuToOverlays(overlays);
    return new Stack(overlays);
  }
}
