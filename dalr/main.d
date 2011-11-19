module dalr.main;

import dalr.dotfilewriter;
import dalr.grammerparser;
import dalr.productionmanager;
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
	pm.makeLRZeroItemSets();
	pm.makeExtendedGrammer();
	print(pm.extendedGrammerToString());
	println();
	print(pm.extendedGrammerItemsToString());
	pm.makeNormalFirstSet();
	print(pm.normalFirstSetToString());
	writeLR0Graph(pm.getItemSets(), sm, pm.getProductions(), "lr0");
}
