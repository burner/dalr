module dalr.main;

import dalr.dotfilewriter;
import dalr.grammerparser;
import dalr.productionmanager;
import dalr.symbolmanager;
import dalr.finalitem;

import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.slog;

void main() {
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	//pm.insertProduction(gp.processProduction("S := N"));
	//pm.insertProduction(gp.processProduction("N := V = E"));
	//pm.insertProduction(gp.processProduction("N := E"));
	//pm.insertProduction(gp.processProduction("E := V"));
	//pm.insertProduction(gp.processProduction("V := x"));
	//pm.insertProduction(gp.processProduction("V := * E"));
	pm.insertProduction(gp.processProduction("S := A"));
	pm.insertProduction(gp.processProduction("A := if B then A"));
	pm.insertProduction(gp.processProduction("A := if B then A else A"));
	pm.insertProduction(gp.processProduction("A := a"));
	pm.insertProduction(gp.processProduction("B := bool"));

	pm.makeLRZeroItemSets();
	writeLR0Graph(pm.getItemSets(), sm, pm.getProductions(), "lr0");
	pm.makeExtendedGrammer();
	print(pm.extendedGrammerToString());
	pm.makeNormalFirstSet();
	print(pm.normalFirstSetToString());
	pm.makeExtendedFirstSet();
	print(pm.extendedFirstSetToString());
	pm.makeNormalFollowSet();
	println(pm.normalFollowSetToString());
	println(pm.extendedGrammerItemsToString());
	pm.makeExtendedFollowSet();
	println(pm.extendedFollowSetToString());

	pm.makeExtendedGrammer();
	print(pm.extendedGrammerToString());
	pm.makeNormalFirstSet();
	print(pm.normalFirstSetToString());
	pm.makeExtendedFirstSet();
	print(pm.extendedFirstSetToString());
	pm.makeNormalFollowSet();
	println(pm.normalFollowSetToString());
	println(pm.extendedGrammerItemsToString());
	pm.makeExtendedFollowSet();
	println(pm.extendedFollowSetToString());
	pm.getTranslationTable();
	pm.getFinalTable();
	println(pm.transitionTableToString());
	println(pm.mergedExtendedToString());
	println(pm.extendedFollowSetToString());
	pm.reduceExtGrammerFollow();
	println(pm.extFollowRulesToString());
	println(pm.normalProductionToString());
	println(pm.finalTransitionTableToString());
}
