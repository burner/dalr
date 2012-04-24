module dalr.prodtree;

import dalr.productionmanager;
import dalr.symbolmanager;

import hurt.container.mapset;
import hurt.container.deque;
import hurt.string.stringbuffer;

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
}

string prodGroupToDot(int startSym, Set!(size_t) set, 
		Deque!(Deque!(int)) prods) {
	StringBuffer!(char) ret = new StrinBuffer!(char)(1024);
	ret.pushBack("subgraph %s {", sm.getSymbolName(startSym));
	ret.pushBack("item%s [style=filled, color=lightgray, label=\"%s\"];", 
		sm.getSymbolName(startSym), sm.getSymbolName(startSym));
}
