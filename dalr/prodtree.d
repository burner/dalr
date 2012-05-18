module dalr.prodtree;

import dalr.productionmanager;
import dalr.symbolmanager;

import hurt.container.mapset;
import hurt.container.deque;
import hurt.container.set;
import hurt.container.stack;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.io.stream;
import hurt.io.stdio;
import hurt.string.stringutil;
import hurt.util.slog;
import hurt.util.pair;

void tree(string filename, ProductionManager pm, SymbolManager sm) {
	Deque!(Deque!(int)) prods = pm.getProductions();	
	File output = new File(filename, FileMode.OutNew);
	output.writeString("digraph g {\n\tcompound=true;\n");

	auto prodIdices = new MapSet!(int,size_t)();
	foreach(size_t idx, Deque!(int) it; prods) {
		foreach(size_t jdx, int jt; it) {
			prodIdices.insert(it[0], idx);
		}
	}

	auto toProcess = new Stack!(int)(128);
	toProcess.push(prods[0][0]);
	auto processed = new Set!(int)();

	auto processedWritten = new MapSet!(int,int)();

	while(!toProcess.isEmpty()) {
		int startSym = toProcess.pop();
		auto it = prodIdices.iterator(startSym);
		for(; it.isValid(); it++) {
			auto prod = prods[*it];
			foreach(jt; prod) {
				if(sm.getKind(jt)) {
					//log("%d %d", startSym, jt);
					if(!processedWritten.contains(startSym, jt)) {
						output.writeString(format("\t%s -> %s;\n", sm.getSymbolName(startSym), 
							sm.getSymbolName(jt)));
						processedWritten.insert(startSym, jt);
					}
					if(!processed.contains(jt)) {
						toProcess.push(jt);
					}
				}
			}
		}
		processed.insert(startSym);
	}
	output.writeString("}\n");
	output.close();
}

void prodToTree(string filename, ProductionManager pm, SymbolManager sm) {
	Deque!(Deque!(int)) prods = pm.getProductions();	
	MapSet!(int,int) follow = new MapSet!(int,int)();
	MapSet!(int,size_t) prodsWithSameStartSym = new MapSet!(int,size_t)();

	foreach(idx, it; prods) {
		prodsWithSameStartSym.insert(it[0], idx);
		foreach(jtx, jt; it) {
			if(jtx == 0) {
				continue;
			}
			if(sm.getKind(jt)) {
				follow.insert(it[0], jt);
			}
		}
	}

	File output = new File(filename, FileMode.OutNew);
	output.writeString("digraph g {\n\trankdir=LR;\n\tcompound=true;\n");
	int[] keys = prodsWithSameStartSym.keys();
	foreach(it; keys) {
		output.writeString(prodGroupToDot(it, prodsWithSameStartSym.getSet(it),
			prods, sm));
		output.writeString(connections(it, follow.getSet(it), sm));
		output.write('\n');
	}
	output.writeString("}\n");
	output.close();
}

string connections(int startSym, Set!(int) follow, SymbolManager sm) {
	auto ret = new StringBuffer!(char)(1024);
	const string startSymName = sm.getSymbolName(startSym);
	foreach(it; follow) {
		if(it != startSym) {
			ret.pushBack("%s -> %s [ltail=cluster_%s, lhead=cluster_%s];\n", 
				startSymName, sm.getSymbolName(it), startSymName, 
				sm.getSymbolName(it));
		} else {
			ret.pushBack("%s -> %s;\n", 
				startSymName, sm.getSymbolName(it));
		}
	}
	return ret.getString();
}

string prodGroupToDot(int startSym, Set!(size_t) set, 
		Deque!(Deque!(int)) prods, SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(1024);
	ret.pushBack("subgraph cluster_%s {\n", sm.getSymbolName(startSym));
	ret.pushBack("\tcolor=black;\n\tlabel=%s;\n", 
		sm.getSymbolName(startSym));
	//ret.pushBack("\t%s [style=invisible];\n", sm.getSymbolName(startSym));
	ret.pushBack("\t%s;\n", sm.getSymbolName(startSym));
	
	foreach(it; set) {
		foreach(jdx, jt; prods[it]) {
			if(jdx == 0) {
				continue;
			}
			string symName = sm.getSymbolName(jt);
			ret.pushBack("\t%s%d%d [label=%s];\n", symName, it, jdx, symName);
		}
	}
	foreach(it; set) {
		auto tmpSb = new StringBuffer!(char)(128);
		foreach(jdx, jt; prods[it]) {
			string symName = sm.getSymbolName(jt);
			tmpSb.pushBack("%s%d%d -> ", symName, it, jdx);
		}
		tmpSb.popBack();
		tmpSb.popBack();
		tmpSb.popBack();
		tmpSb.popBack();
		tmpSb.pushBack(";\n");
		ret.pushBack(tmpSb.getData());
	}
	ret.pushBack("}\n");
	return ret.getString();
}
