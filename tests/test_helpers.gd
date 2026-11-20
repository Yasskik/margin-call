class_name TestHelpers
extends RefCounted
## Shared fixtures for headless tests. Uses DataLoader directly (never the autoload).


static func loader() -> DataLoader:
	var l: DataLoader = DataLoader.new()
	l.load_all("res://data/")
	return l


static func make_stock(ticker: String, price: float, spread: float, borrow: float) -> StockDef:
	var s: StockDef = StockDef.new()
	s.ticker = ticker
	s.name = ticker + " Test Corp"
	s.sector = "TEST"
	s.start_price = price
	s.base_volatility = 0.3
	s.spread_pct = spread
	s.borrow_rate_annual = borrow
	s.wall_offsets_pct = [0.04, 0.09, 0.16, 0.25, 0.38]
	return s


static func only(stocks: Array[StockDef], ticker: String) -> Array[StockDef]:
	var out: Array[StockDef] = []
	for s: StockDef in stocks:
		if s.ticker == ticker:
			out.append(s)
	return out
