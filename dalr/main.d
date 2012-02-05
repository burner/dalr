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
import hurt.container.mapset;
import hurt.container.set;
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

	bool printProductions = false;
	arg.setOption("-p", "--productions", 
		"if set the parsed productions are printed." , printProductions);

	bool printPrecedence = false;
	arg.setOption("-c", "--printprecedence", 
		"if passed the precedence of the terminals is printed ", 
		printPrecedence, true);

	// create all facilities
	FileReader fr = new FileReader(inputFile);
	fr.parse();

	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);

	// map the actions to the productions
	Map!(size_t, Production) actions = new Map!(size_t, Production)(
		ISRType.HashTable);
	
	MapSet!(int,string) left = fr.getLeftAssociation();
	MapSet!(int,string) right = fr.getRightAssociation();
	Set!(string) non = fr.getNonAssociation();

	sm.checkIfPrecedenceIsCorrect(left, right, non);

	if(printPrecedence) {
		foreach(int idx, string it; left) {
			log("%d -> %s", idx, it);
		}

		foreach(int idx, string it; right) {
			log("%d -> %s", idx, it);
		}
	}
	log("%s", fr.productionToString());

	// for all productions in the filereader. 
	// add them to the productionsmanager
	for(Iterator!(Production) it = fr.getProductionIterator(); it.isValid(); 
			it++) {
		actions.insert(pm.insertProduction(
			gp.processProduction((*it).getProduction())), *it);
		if(printProductions) {
			log("%s", (*it).getProduction());
		}
	}

	// pass the ruleIndex Production mapping to the ProductionManager
	// for conflict resolution
	pm.setProdMapping(actions);

	pm.makeAll(graphfile);

	File finalTable = new File(outputFile, FileMode.OutNew);
	finalTable.writeString(finalTransitionTableToStringShort(pm, sm));
	//println(finalTransitionTableToStringShort(pm, sm));
	finalTable.writeString(finalTransitionTableToString(pm, sm));
	//println(finalTransitionTableToString(pm, sm));
	finalTable.writeString(sm.toString());
	finalTable.close();
}
