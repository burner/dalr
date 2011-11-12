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
}
