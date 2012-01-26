module dalr.symbolmanager;

import hurt.container.deque;
import hurt.container.map;
import hurt.container.set;
import hurt.container.isr;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;
import hurt.util.pair;

public class Symbol {
	private string symbolName; // the name of the symbol
	// symbols are handled as int, so there here is the mapping
	private int id; 
	// terminal(false) or non-terminal(true)
	private bool kind; 

	this(string symbolName, int id, bool kind) {
		assert(symbolName !is null);
		this.symbolName = symbolName.idup;
		this.id = id;
		this.kind = kind;
	}

	public bool whatKind() const {
		return this.kind;
	}

	public void setKind(const bool kind) {
		this.kind = kind;
	}

	public int getId() const {
		return this.id;
	}

	public string getSymbolName() {
		return this.symbolName;
	}

	public override string toString() const {
		//return format("(%s %d %b)", this.symbolName, this.id, this.kind);
		return format("(%d :: %s || %s)", this.id, this.symbolName, 
			this.kind ? "true" : "false");
	}
}

public class SymbolManager {
	private Map!(int,Symbol) intSymbols;
	private Map!(string,Symbol) stringSymbols;

	private int nextSymbolNumber;

	this() {
		this.intSymbols = new Map!(int,Symbol)(ISRType.HashTable);
		this.stringSymbols = new Map!(string,Symbol)(ISRType.HashTable);
		this.makeDollarAndEpsilon();
	}

	private void makeDollarAndEpsilon() {
		Symbol d = new Symbol("$", -1, false);
		this.intSymbols.insert(d.getId(), d);
		this.stringSymbols.insert(d.getSymbolName(), d);
		Symbol e = new Symbol("epsilon", -2, false);
		this.intSymbols.insert(e.getId(), e);
		this.stringSymbols.insert(e.getSymbolName(), e);

	}

	public int insertSymbol(string sym, bool kind) {
		MapItem!(string, Symbol) item = this.stringSymbols.find(sym);	
		if(item !is null) {
			throw new Exception(format("Symbol %s allready presend", sym));
		} else {
			int newId = this.getNextId();
			Symbol s = new Symbol(sym, newId, kind);
			this.intSymbols.insert(s.getId(), s);
			this.stringSymbols.insert(s.getSymbolName(), s);

			debug {
				// testing if both maps hold the same symbols
				MapItem!(int,Symbol) intS = this.intSymbols.find(s.getId());
				MapItem!(string,Symbol) strS = this.stringSymbols.find(
					s.getSymbolName());
				assert(intS !is null && strS !is null);
				assert(intS.getData() is strS.getData());
			}
			return newId;
		}
	}

	public Map!(int,Symbol) getIntSymbols() {
		return this.intSymbols;
	}

	public size_t longestItem() {
		ISRIterator!(MapItem!(string, Symbol)) it = this.stringSymbols.begin();
		size_t ret = 0;
		for(; it.isValid(); it++) {
			ret = (*it).getKey().length > ret ? (*it).getKey().length : ret;
		}
		return ret;
	}

	public Pair!(Set!(int), Set!(int)) getTermAndNonTerm() {
		Set!(int) term = new Set!(int)();
		Set!(int) nonTerm = new Set!(int)();
		
		ISRIterator!(MapItem!(int,Symbol)) it = this.intSymbols.begin();
		for(; it.isValid(); it++) {
			if((*it).getData().whatKind()) {
				nonTerm.insert((*it).getKey());
			} else {
				if((*it).getKey() != -1 && (*it).getKey() != -2) {
					term.insert((*it).getKey());
				}
			}
		}
		assert(term.getSize() + nonTerm.getSize() == 
			this.intSymbols.getSize()-2);
		return Pair!(Set!(int),Set!(int))(term, nonTerm);
	}

	public bool containsSymbol(string sym) {
		return null !is this.stringSymbols.find(sym);
	}
	
	public bool containsSymbol(int sym) {
		return null !is this.intSymbols.find(sym);
	}

	private int getNextId() {
		return this.nextSymbolNumber++;
	}

	public void setKind(int symbol, bool kind) {
		MapItem!(int,Symbol) f = this.intSymbols.find(symbol);
		if(f is null) {
			throw new Exception(format("Symbol %d doesn't exist", symbol));
		} else {
			return f.getData().setKind(kind);
		}
	}

	public void setKind(string symbol, bool kind) {
		MapItem!(string,Symbol) f = this.stringSymbols.find(symbol);
		if(f is null) {
			throw new Exception(format("Symbol %s doesn't exist", symbol));
		} else {
			return f.getData().setKind(kind);
		}
	}

	public bool getKind(const int symbol) {
		MapItem!(int,Symbol) f = this.intSymbols.find(symbol);
		if(f is null) {
			throw new Exception(format("Symbol %d doesn't exist", symbol));
		} else {
			return f.getData().whatKind();
		}
	}

	public int getSymbolId(const string symbolName) {
		MapItem!(string,Symbol) f = this.stringSymbols.find(symbolName);
		if(f is null) {
			return -1;
		} else {
			return f.getData().getId();
		}
	}

	public string getSymbolName(const int symbolId) {
		MapItem!(int,Symbol) f = this.intSymbols.find(symbolId);
		if(f is null) {
			return null;
		} else {
			return f.getData().getSymbolName();
		}
	}

	public Symbol getSymbol(const int symbolId) {
		MapItem!(int,Symbol) f = this.intSymbols.find(symbolId);
		if(f is null) {
			return null;
		} else {
			return f.getData();
		}
	}

	public Symbol getSymbol(const string symbolId) {
		MapItem!(string,Symbol) f = this.stringSymbols.find(symbolId);
		if(f is null) {
			return null;
		} else {
			return f.getData();
		}
	}

	public size_t getSize() const {
		assert(this.intSymbols.getSize() == this.stringSymbols.getSize());
		return this.intSymbols.getSize();
	}

	public override string toString() {
		StringBuffer!(char) sb = 
			new StringBuffer!(char)(this.intSymbols.getSize() * 4);
		sb.pushBack("Symbols = { ");

		ISRIterator!(MapItem!(int,Symbol)) it = this.intSymbols.begin();
		for(; it.isValid(); it++) {
			string tmp = (*it).getData().toString();
			sb.pushBack(tmp);
			sb.pushBack(" , ");	
			sb.pushBack("\n");	
		}
		sb.popBack();
		sb.popBack();
		sb.pushBack("}");
		return sb.getString();
	}
}

unittest {
	SymbolManager sm = new SymbolManager();
	sm.insertSymbol("expr", true);
	Symbol sbs = sm.getSymbol("expr");
	Symbol sbi = sm.getSymbol(sbs.getId());
	assert(sbs is sbi);
}
