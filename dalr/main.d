module dalr.main;

import dalr.dotfilewriter;
import dalr.grammerparser;
import dalr.productionmanager;
import dalr.symbolmanager;
import dalr.finalitem;
import dalr.tostring;

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
	print(extendedGrammerToString(pm, sm));
	pm.makeNormalFirstSet();
	print(normalFirstSetToString(pm, sm));
	pm.makeExtendedFirstSet();
	print(extendedFirstSetToString(pm, sm));
	pm.makeNormalFollowSet();
	println(normalFollowSetToString(pm, sm));
	println(extendedGrammerItemsToString(pm, sm));
	pm.makeExtendedFollowSet();
	println(extendedFollowSetToString(pm, sm));

	pm.makeExtendedGrammer();
	print(extendedGrammerToString(pm, sm));
	pm.makeNormalFirstSet();
	print(normalFirstSetToString(pm, sm));
	pm.makeExtendedFirstSet();
	print(extendedFirstSetToString(pm, sm));
	pm.makeNormalFollowSet();
	println(normalFollowSetToString(pm, sm));
	println(extendedGrammerItemsToString(pm, sm));
	pm.makeExtendedFollowSet();
	pm.getTranslationTable();
	pm.getFinalTable();
	println(transitionTableToString(pm, sm));
	println(mergedExtendedToString(pm, sm));
	pm.reduceExtGrammerFollow();
	println(extFollowRulesToString(pm, sm));
	println(normalProductionToString(pm, sm));
	println(finalTransitionTableToString(pm, sm));
}
