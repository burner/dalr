module dalr.main;

import dalr.dotfilewriter;
import dalr.grammerparser;
import dalr.productionmanager;
import dalr.symbolmanager;
import dalr.finalitem;
import dalr.tostring;
import dalr.filereader;
import dalr.filewriter;

import hurt.container.deque;
import hurt.container.map;
import hurt.container.mapset;
import hurt.container.set;
import hurt.container.isr;
import hurt.io.stdio;
import hurt.io.stream;
import hurt.util.slog;
import hurt.util.getopt;

int main(string[] args) {
	Args arg = Args(args);
	arg.setHelpText("This is a glr/lalr1 parser generator.\n" ~
		"It is written in D and generates Parser in D.\n");

	// input file
	string inputFile = "";
	arg.setOption("-i", "--input", "specify the grammer file." ~
		" the defaultfile is examplegrammer.dlr", inputFile);

	// output file
	string outputFile = "";
	arg.setOption("-r", "--ruleoutput", 
		"specify the outputfile for parse-table." , outputFile);

	string outputModulename = "";
	arg.setOption("-rm", "--rulemodule", 
		"specify the modulename of the outputfile for the parse-table."
		, outputModulename);

	// driver file
	string driverFile = "";
	arg.setOption("-d", "--driveroutput", 
		"specify the outputfile for driver. this is the actual parser algorithm"
		, driverFile);

	string driverModulename = "";
	arg.setOption("-dm", "--drivermodule", "specify the modulename of driver." 
		, driverModulename);

	string driverClassname = "";
	arg.setOption("-dc", "--drivername", "specify the class name of driver." 
		, driverClassname);


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
		printPrecedence);

	int printAround = -1;
	arg.setOption("-a", "--printaround", 
		"If a grammer has ambiguites it might make sense to print the lr set"
		~ " around that itemset. If you pass an int after this option " ~
		" a graph will be created", 
		printAround, true);

	

	if(driverFile !is null && driverFile.length > 0) {
		LalrWriter lw = new LalrWriter(driverFile, driverModulename,
			null, null, driverClassname !is null && driverClassname.length > 0 ?
			driverClassname : "Lalr");
		lw.write();
		lw.close();
	}


	if(inputFile is null || inputFile.length == 0) {
		printfln("No inputfile defined. An inputfile is required.");
		return -1;
	}

	// create all facilities
	FileReader fr = new FileReader(inputFile);
	fr.parse();

	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm, fr.isGlr());

	// map the actions to the productions
	Map!(size_t, Production) actions = new Map!(size_t, Production)(
		ISRType.HashTable);
	
	MapSet!(int,string) left = fr.getLeftAssociation();
	MapSet!(int,string) right = fr.getRightAssociation();
	Set!(string) non = fr.getNonAssociation();

	if(printPrecedence) { // needed for debugging the grammer
		foreach(int idx, string it; left) {
			log("%d -> %s", idx, it);
		}

		foreach(int idx, string it; right) {
			log("%d -> %s", idx, it);
		}
	}

	// for all productions in the filereader. 
	// add them to the productionsmanager
	for(Iterator!(Production) it = fr.getProductionIterator(); it.isValid(); 
			it++) {
		actions.insert(pm.insertProduction(
			gp.processProduction((*it).getProduction())), *it);
		if(printProductions) { // needed for debugging the grammer
			log("%s", (*it).getProduction());
		}
	}
	//println(sm.toString());

	// operator precedence prolog
	//insertMetaSymbolsIntoSymbolManager(sm, fr.getProductionIterator());
	debug {
		sm.checkIfPrecedenceIsCorrect(left, right, non);
	}

	//println(sm.precedenceToString());

	// pass the ruleIndex Production mapping to the ProductionManager
	// for conflict resolution
	pm.setProdMapping(actions);

	pm.makeAll(graphfile, printAround);

	//println(extendedGrammerToString(pm, sm));
	//println(itemsetsToString(pm, sm));
	File tranTable = new File("tranTable", FileMode.OutNew);
	tranTable.writeString(finalTransitionTableToString(pm, sm));
	tranTable.close();

	if(outputFile !is null && outputFile.length > 0) {
		RuleWriter fw = new RuleWriter(outputFile, outputModulename,
			sm, pm, false);
		fw.write();
		fw.close();
	}

	return 0;
}
