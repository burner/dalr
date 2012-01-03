module dalr.main;

import dalr.dotfilewriter;
import dalr.grammerparser;
import dalr.productionmanager;
import dalr.symbolmanager;
import dalr.finalitem;
import dalr.tostring;
import dalr.filereader;

import hurt.container.deque;
import hurt.container.map;
import hurt.container.isr;
import hurt.io.stdio;
import hurt.util.slog;

void main() {
	// create all facilities
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	FileReader fr = new FileReader("d2grm.dlr");
	//FileReader fr = new FileReader("examplegrammer.dlr");
	fr.parse();

	// map the actions to the productions
	Map!(size_t, Production) actions = new Map!(size_t, Production)(
		ISRType.HashTable);

	// for all productions in the filereader. 
	// add them to the productionsmanager
	for(Iterator!(Production) it = fr.getProductionIterator(); it.isValid(); 
			it++) {
		actions.insert(pm.insertProduction(
			gp.processProduction((*it).getProduction())), *it);
		log("%s", (*it).getProduction());
	}
	
	pm.makeLRZeroItemSets();
	//writeLR0Graph(pm.getItemSets(), sm, pm.getProductions(), "lr0");
	
	pm.makeExtendedGrammer();
	//print(extendedGrammerToString(pm, sm));
	pm.makeNormalFirstSet();
	//print(normalFirstSetToString(pm, sm));
	pm.makeExtendedFirstSet();
	//print(extendedFirstSetToString(pm, sm));
	pm.makeNormalFollowSet();
	//println(normalFollowSetToString(pm, sm));
	//println(extendedGrammerItemsToString(pm, sm));
	log();
	pm.makeExtendedFollowSet();
	//println(extendedFollowSetToString(pm, sm));

	pm.makeExtendedGrammer();
	//print(extendedGrammerToString(pm, sm));
	pm.makeNormalFirstSet();
	//print(normalFirstSetToString(pm, sm));
	pm.makeExtendedFirstSet();
	log();
	//print(extendedFirstSetToString(pm, sm));
	pm.makeNormalFollowSet();
	log();
	//println(normalFollowSetToString(pm, sm));
	//println(extendedGrammerItemsToString(pm, sm));
	log();
	pm.makeExtendedFollowSet();
	log();
	pm.getTranslationTable();
	log();
	pm.getFinalTable();
	log();
	//println(transitionTableToString(pm, sm));
	//println(mergedExtendedToString(pm, sm));
	pm.reduceExtGrammerFollow();
	//println(extFollowRulesToString(pm, sm));
	//println(normalProductionToString(pm, sm));
	//println(finalTransitionTableToString(pm, sm));
}
