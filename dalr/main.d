module dalr.main;

import dalr.productionmanager;
import dalr.grammerparser;
import dalr.symbolmanager;

import hurt.container.deque;
import hurt.io.stdio;

void main() {
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	pm.insertProduction(gp.processProduction("S := N"));
	pm.insertProduction(gp.processProduction("N := V = E"));
	pm.insertProduction(gp.processProduction("N := E"));
	pm.insertProduction(gp.processProduction("E := V"));
	pm.insertProduction(gp.processProduction("V := x"));
	pm.insertProduction(gp.processProduction("V := * E"));
	print(pm.toString());
	println(sm.toString());
	pm.makeLRZeroItemSets();
	println(pm.itemsetsToString());
}
