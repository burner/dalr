module dalr.grammerparser;

import dalr.symbolmanager;

import hurt.io.stdio;
import hurt.string.stringutil;
import hurt.container.deque;

class GrammerParser {
	SymbolManager symbolManager;

	this(SymbolManager sm) {
		this.symbolManager = sm;
	}

	public Deque!(int) processProduction(string production) {
		string[] splits = split!(char)(production);
		Deque!(int) ret = new Deque!(int)(splits.length);

		foreach(size_t idx, string it; splits) {
			if(idx == 0 && this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.getSymbolId(it);
				this.symbolManager.setKind(symId, true);
				ret.pushBack(symId);
			} else if(idx == 0 && !this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.insertSymbol(it, true);
				ret.pushBack(symId);
			} else if(idx == 1) {
				continue;
			} else if(this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.getSymbolId(it);
				ret.pushBack(symId);
			} else if(!this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.insertSymbol(it, false);
				ret.pushBack(symId);
			}
		}
		return ret;
	}

	public Deque!(int) processProduction(string start, string production) {
		string[] splits = split!(char)(production);
		Deque!(int) ret = new Deque!(int)(splits.length+1);

		// the start symbol
		if(this.symbolManager.containsSymbol(start)) {
			int symId = this.symbolManager.getSymbolId(start);
			this.symbolManager.setKind(symId, true);
			ret.pushBack(symId);
		} else if(!this.symbolManager.containsSymbol(start)) {
			int symId = this.symbolManager.insertSymbol(start, true);
			ret.pushBack(symId);
		}

		foreach(size_t idx, string it; splits) {
			if(it == ":=" || it == "|") {
				continue;
			} else if(this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.getSymbolId(it);
				ret.pushBack(symId);
			} else if(!this.symbolManager.containsSymbol(it)) {
				int symId = this.symbolManager.insertSymbol(it, false);
				ret.pushBack(symId);
			}
		}
		return ret;

	}
}

unittest {
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	Deque!(int) d1 = gp.processProduction("S := A B C");
	Deque!(int) d2 = gp.processProduction("S", ":= A B C");
	Deque!(int) d3 = gp.processProduction("S", "| A B C");
	assert(d1 == d2);
	assert(d1 == d3);
	assert(d2 == d3);
}
