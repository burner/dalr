module dalr.checker;

import hurt.conv.conv;
import hurt.container.deque;
import hurt.container.set;
import hurt.container.map;
import hurt.container.stack;
import hurt.container.mapset;
import hurt.util.slog;
import hurt.util.array;
import hurt.string.stringutil;
import hurt.string.formatter;

import dalr.symbolmanager;
import dalr.filereader;

struct Checker {
	Deque!(Deque!(int)) prods;
	SymbolManager sm;

	MapSet!(int, int) ssymRul;
	Set!(int) sym;

	Set!(int) unreached;

	Deque!(Production) actions;

	this(Deque!(Deque!(int)) prods, SymbolManager sm, 
			Deque!(Production) actions) {
		this.ssymRul = new MapSet!(int, int)();
		this.sym = new Set!(int)();
		this.prods = prods;
		this.sm = sm;
		this.actions = actions;

		this.buildSSymRul();
		log("Check for unreached non-terminals");
		this.checkReach();
		this.printUnreached();
		this.checkBuildWithTermName();
		this.checkBuildWithTreeIndices();
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

	private string getTermName(string str) {
		return str;
	}

	void checkBuildWithTermName() {
		foreach(value; this.actions) {
			//log("%s %s", value.getProduction(), value.getAction());
			immutable string str = "buildTreeWithLoc(term";
			size_t len = str.length;
			size_t pos = findArr!(char)(value.getAction(), str);
			assert(pos != value.getAction().length, format("pos = %d: %s %s %s",
				pos, value.getProduction(), value.getAction(), 
				value.getAction()[pos .. $]));
			size_t posC = find!(char)(value.getAction(),',', pos+len);
			assert(posC != value.getAction().length, value.getAction());

			warn(value.getAction()[pos+len .. posC] != 
				trim(value.getStartSymbol()), "%s != %s", 
					value.getAction()[pos+len .. posC], 
					trim(value.getStartSymbol()));
			/*log("%s == %s", value.getAction()[pos+len .. posC], 
				trim(value.getStartSymbol()));*/
		}
	}

	private static size_t getProductionLength(Production p) {
		string[] sp = split(trim(p.getProdString()));
		return sp.length;
	}

	private static Deque!(int) getChildIds(Production p) {
		string action = p.getAction();
		size_t low = find(action, '[');
		if(low == action.length) {
			return new Deque!(int)();
		}
		size_t high = find(action, ']', low+1);
		auto sp = split(action[low+1 .. high], ',');
		auto ret = new Deque!(int)(sp.length);
		foreach(it; sp) {
			ret.pushBack(-conv!(string,int)(trim(it)));
		}
		return ret;
	}

	private static int getPosIdx(Production p) {
		string action = p.getAction();
		size_t high = find(action, ']');
		if(high == action.length) {
			return 9999;
		}
		size_t nLow = find(action, '[', high);
		size_t nHigh = find(action, ']', nLow);
		auto sp = trim(action[nLow+1 .. nHigh]);
		return -conv!(string,int)(sp);
	}

	void checkBuildWithTreeIndices() {
		log("checking tree build indices");
		foreach(it; actions) {
			size_t proLength = getProductionLength(it);
			auto chIdx = getChildIds(it);
			foreach(jt; chIdx) {
				warn(jt > proLength, 
					"tree build index %d to high for production %s",
					jt, it.getProduction());
			}

			int pos = getPosIdx(it);
			warn(pos > proLength, "posIdx % to high for production %s",
				pos, it.getProduction());
		}
	}

	void checkReach() {
		auto startSymbol = this.ssymRul.iterator(sm.getSymbolId("S"));
		assert(startSymbol !is null, "no dedicated start symbol S defined");

		Set!(int) processed = new Set!(int)();
		Stack!(int) toProcess = new Stack!(int)(128);
		toProcess.push(*startSymbol);
		
		while(!toProcess.isEmpty()) {
			int next = toProcess.pop();
			if(!processed.insert(next)) {
				continue;
			}

			//log("%d", next);
			auto it = this.ssymRul.iterator(next);
			if(it is null) {
				continue;
			}
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
