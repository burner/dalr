import dalr.filereader;
import hurt.container.deque;
import hurt.container.multimap;
import hurt.container.set;
import hurt.string.stringutil;
import hurt.io.stdio;
import hurt.util.getopt;
import hurt.util.slog;

void main(string[] args) {
	Args arguments = Args(args);
	arguments.setHelpText("Helper programm that producess a random word " ~
		"for a given grammer.\nWhen creating the text every small written word" 		~ " will be printed unless a replacedment function is found.\n" ~
		"This replacement function need to be defined in 'tester/tester.d'.");
	size_t lexCount = 10;
	string inputFile = "examplegrammer.dlr";
	string outputFile = "exampleword.d";
	arguments.setOption("-c", "--count", "of how many lex symbol should " ~
		"consists ?", lexCount);
	arguments.setOption("-i", "--input", "inputfile with the grammer", 
		inputFile);
	arguments.setOption("-o", "--output", "outputfile with the created word", 
		outputFile, true); // the last option

	log("%u %s %s", lexCount, inputFile, outputFile);
	
	FileReader fr = new FileReader(inputFile);
	fr.parse();
	MultiMap!(string,Deque!(string)) rules = 
		new MultiMap!(string,Deque!(string));

	Set!(string) keywords = new Set!(string)();

	// fill the map with the productions
	Deque!(Production) prods = fr.getProductions();
	foreach(Production it; prods) {
		Deque!(string) kw = new Deque!(string)(split(trim(it.getProduction())));
		rules.insert(trim(it.getStartSymbol()), kw);
		foreach(string jt; kw) { // to get the names of the keywords
			keywords.insert(jt);
		}
	}

	printfln("%u == %u ???", rules.getSize(), prods.getSize());
}
