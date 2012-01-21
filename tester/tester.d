import dalr.filereader;
import hurt.container.deque;
import hurt.container.multimap;
import hurt.container.set;
import hurt.string.stringutil;
import hurt.io.stdio;
import hurt.util.getopt;
import hurt.util.slog;
import hurt.util.random;
import hurt.string.stringbuffer;

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

	Twister tw = Twister(123134);
	log("%u %s %s %u", lexCount, inputFile, outputFile, tw.next());
	
	FileReader fr = new FileReader(inputFile);
	fr.parse();
	MultiMap!(string,Deque!(string)) rules = 
		new MultiMap!(string,Deque!(string));

	// this is needed to create identifer that don't resample keywords
	Set!(string) keywords = new Set!(string)();

	// fill the map with the productions
	Deque!(Production) prods = fr.getProductions();
	foreach(Production it; prods) {
		Deque!(string) kw = new Deque!(string)(split(trim(it.getProduction())));
		rules.insert(trim(it.getStartSymbol()), kw);
		foreach(string jt; kw) { // to get the names of the keywords
			if(isLowerCase(jt)) {
				keywords.insert(jt);
			}
		}
	}

	log("%u == %u ???", rules.getSize(), prods.getSize());
	log("%u", keywords.getSize());
	foreach(string it; keywords) {
		log("%s %s", it, processString(it, keywords, tw));
	}
}

string processString(string str, Set!(string) keywords, Twister tw) {
	switch(str) {
		case "identifier": {
			StringBuffer!(char) ret = new StringBuffer!(char)();
			do {
				tw.seed();
				ret.clear();
				size_t len = tw.next() % 14;
				for(size_t i = 0; i < len; i++) {
					ret.pushBack(tw.next() % 2 == 0 ?
						tw.next() % 26 + 65 : // big chars
						tw.next() % 26 + 97); // small chars
				}
			} while(keywords.contains(ret.getString()));
			return ret.getString();
		}
		case "and":
			return "&";
		case "andassign":
			return "&=";
		case "assign":
			return "=";
		case "bang":
			return "!";
		case "banggreater":
			return "!>";
		case "banggreaterequal":
			return "!>=";
		case "bangsmaller":
			return "!<";
		case "bangsmallerequal":
			return "!<=";
		case "bangsquare":
			return "!<>";
		case "bangsquareassign":
			return "!<>=";
		case "colon":
			return ":";
		case "comma":
			return ",";
		case "div":
			return "/";
		case "divassign":
			return "/=";
		case "dollar":
			return "$";
		case "dot":
			return ".";
		case "dotdot":
			return "..";
		case "dotdotdot":
			return "...";
		case "equal":
			return "==";
		case "epsilon":
			return "";
		case "greater":
			return ">";
		case "greaterequal":
			return ">=";
		case "lparen":
			return "(";
		case "rparen":
			return ")";
		case "lbrack":
			return "[";
		case "lcurly":
			return "{";
		case "rbrack":
			return "]";
		case "rcurly":
			return "}";
		case "leftshift":
			return "<<";
		case "leftshiftassgin":
			return "<<=";
		case "less":
			return "<";
		case "lessequal":
			return "<=";
		case "logicand":
			return "$$";
		case "logicor":
			return "||";
		case "minus":
			return "-";
		case "minusassign":
			return "-=";
		case "modassign":
			return "%=";
		case "modulo":
			return "%";
		case "multassign":
			return "*=";
		case "notequal":
			return "!=";
		case "or":
			return "|";
		case "orassign":
			return "|=";
		case "plus":
			return "+";
		case "plusassign":
			return "+=";
		case "questionmark":
			return "?";
		case "rightshift":
			return ">>";
		case "rightshiftassgin":
			return ">>=";
		case "semicolon":
			return ";";
		case "star":
			return "*";
		case "tilde":
			return "~";
		case "tildeassign":
			return "~=";
		case "usignedrightshift":
			return ">>>";
		case "usignedrightshiftassign":
			return ">>>=";
		case "xor":
			return "^";	
		case "xorassign":
			return "^=";	
		case "xorxor":
			return "^^";	
		case "xorxorassign":
			return "^^=";	
		default:
			return str;
	}
}

