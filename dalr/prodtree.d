module dalr.prodtree;

import dalr.productionmanager;
import dalr.symbolmanager;

import hurt.container.mapset;
import hurt.container.deque;
import hurt.container.set;
import hurt.string.stringbuffer;
import hurt.io.stream;

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
		foreach(jdx, jt; prods[it]) {
			if(jdx == 0) {
				ret.pushBack("\t%s -> ", sm.getSymbolName(startSym));
				continue;
			}
			string symName = sm.getSymbolName(jt);
			ret.pushBack("%s%d%d -> ", symName, it, jdx);
		}
		ret.popBack();
		ret.popBack();
		ret.popBack();
		ret.popBack();
		ret.pushBack(";\n");
	}
	ret.pushBack("}\n");
	return ret.getString();
}
