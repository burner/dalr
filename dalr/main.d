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
import hurt.io.stream;
import hurt.util.slog;
import hurt.util.getopt;

void main() {
	// create all facilities
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	FileReader fr = new FileReader("d2grm.dlr");
	//FileReader fr = new FileReader("websitegrammer.dlr");
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
	}
	log("number of productions %u", fr.getProductions().getSize());

	pm.makeAll();

	File finalTable = new File("finalTable", FileMode.OutNew);
	finalTable.writeString(finalTransitionTableToString(pm, sm));
	finalTable.close();
}
