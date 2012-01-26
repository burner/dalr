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

void main(string[] args) {
	Args arg = Args(args);
	arg.setHelpText("This is a glr/lalr1 parser generator.\n" ~
		"It is written in D and generates Parser in D.\n");

	// input file
	string inputFile = "examplegrammer.dlr";
	arg.setOption("-i", "--input", "specify the grammer file." ~
		" the defaultfile is examplegrammer.dlr", inputFile);

	// output file
	string outputFile = "examplegrammer.d";
	arg.setOption("-o", "--output", "specify the outputfile for the parser." ~
		" the default is examplegramer.d", outputFile);

	// graph filename
	string graphfile = "";
	arg.setOption("-g", "--graph", "specify the filename for the lr0 graph." ~
		" if non is set no graph will be printed", graphfile);

	// create all facilities
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	FileReader fr = new FileReader(inputFile);
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
		//log("%s", (*it).getProduction());
	}

	pm.makeAll(graphfile);

	File finalTable = new File(outputFile, FileMode.OutNew);
	finalTable.writeString(finalTransitionTableToString(pm, sm));
	finalTable.writeString(sm.toString());
	finalTable.close();
}
