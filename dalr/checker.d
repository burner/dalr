module dalr.checker;

import hurt.container.deque;
import hurt.container.set;
import hurt.container.stack;
import hurt.container.mapset;
import hurt.util.slog;

import dalr.symbolmanager;

struct Checker {
	Deque!(Deque!(int)) prods;
	SymbolManager sm;

	MapSet!(int, int) ssymRul;
	Set!(int) sym;

	Set!(int) unreached;

	this(Deque!(Deque!(int)) prods, SymbolManager sm) {
		this.ssymRul = new MapSet!(int, int)();
		this.sym = new Set!(int)();
		this.prods = prods;
		this.sm = sm;

		this.buildSSymRul();
		log("Check for unreached non-terminals");
		this.checkReach();
		this.printUnreached();
	}

	void buildSSymRul() {
		foreach(size_t idx, Deque!(int) it; this.prods) {
			this.sym.insert(it[0]);
			foreach(size_t jdx, int jt; it) {
				if(this.sm.getKind(jt)) {
					this.ssymRul.insert(it[0], jt);
				}
			}
		}
	}

	void checkReach() {
		auto startSymbol = ssymRul.iterator(sm.getSymbolId("S"));
		assert(startSymbol !is null, "no dedicated start symbol S defined");

		Set!(int) processed = new Set!(int)();
		Stack!(int) toProcess = new Stack!(int)(128);
		toProcess.push(*startSymbol);
		
		while(!toProcess.isEmpty()) {
			int next = toProcess.pop();
			if(!processed.insert(next)) {
				continue;
			}

			auto it = this.ssymRul.iterator(next);
			for(; it.isValid(); it++) {
				if(!processed.contains(*it)) {
					toProcess.push(*it);
				}
			}
		}

		this.unreached = processed.difference(sym);
	}

	void printUnreached() {
		for(auto it = this.unreached.begin(); it.isValid(); it++) {
			warn("%s is unreached", this.sm.getSymbolName(*it));
		}
	}
}
