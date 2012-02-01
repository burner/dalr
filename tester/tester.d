import dalr.filereader;
import hurt.conv.conv;
import hurt.container.deque;
import hurt.container.map;
import hurt.container.set;
import hurt.container.isr;
import hurt.container.dlst;
import hurt.string.stringutil;
import hurt.io.stdio;
import hurt.io.stream;
import hurt.util.getopt;
import hurt.util.slog;
import hurt.util.random.random;
import hurt.string.stringbuffer;

immutable size_t maxdepth = 5;

void main(string[] args) {
	Args arguments = Args(args);
	arguments.setHelpText("Helper programm that producess a random word " ~
		"for a given grammer.\nWhen creating the text every small written word"
		~ " will be printed unless a replacedment function is found.\n" ~
		"This replacement function need to be defined in 'tester/tester.d'.");
	size_t lexCount = 1;
	string inputFile = "";
	string outputFile = "exampleword.d";
	string startSymbol = "DeclDefsOpt";
	arguments.setOption("-c", "--count", "of how many lex symbol should " ~
		"consists ?", lexCount);
	arguments.setOption("-i", "--input", "inputfile with the grammer", 
		inputFile);
	arguments.setOption("-s", "--start", "choose a start for the word to write"
		, startSymbol);
	arguments.setOption("-o", "--output", "outputfile with the created word", 
		outputFile, true); // the last option

	if(arguments.wasHelpPrinted() && inputFile == "") {
		return;
	}

	Map!(string,string) replace = new Map!(string,string)(ISRType.HashTable);
	replace.insert("and", "&");
	replace.insert("andassign", "&=");
	replace.insert("assign", "=");
	replace.insert("bang", "!");
	replace.insert("banggreater", "!>");
	replace.insert("banggreaterequal", "!>=");
	replace.insert("bangsmaller", "!<");
	replace.insert("bangsmallerequal", "!<=");
	replace.insert("bangsquare", "!<>");
	replace.insert("bangsquareassign", "!<>=");
	replace.insert("colon", ":");
	replace.insert("comma", ",");
	replace.insert("div", "/");
	replace.insert("divassign", "/=");
	replace.insert("dollar", "$");
	replace.insert("dot", ".");
	replace.insert("dotdot", "..");
	replace.insert("dotdotdot", "...");
	replace.insert("equal", "==");
	replace.insert("epsilon", "");
	replace.insert("greater", ">");
	replace.insert("greaterequal", ">=");
	replace.insert("lparen", "(");
	replace.insert("rparen", ")");
	replace.insert("lbrack", "[");
	replace.insert("lcurly", "{");
	replace.insert("rbrack", "]");
	replace.insert("rcurly", "}");
	replace.insert("leftshift", "<<");
	replace.insert("leftshiftassgin", "<<=");
	replace.insert("less", "<");
	replace.insert("lessequal", "<=");
	replace.insert("logicand", "$$");
	replace.insert("logicor", "||");
	replace.insert("minus", "-");
	replace.insert("minusassign", "-=");
	replace.insert("modassign", "%=");
	replace.insert("modulo", "%");
	replace.insert("multassign", "*=");
	replace.insert("notequal", "!=");
	replace.insert("or", "|");
	replace.insert("orassign", "|=");
	replace.insert("plus", "+");
	replace.insert("plusassign", "+=");
	replace.insert("questionmark", "?");
	replace.insert("rightshift", ">>");
	replace.insert("rightshiftassgin", ">>=");
	replace.insert("semicolon", ";");
	replace.insert("star", "*");
	replace.insert("tilde", "~");
	replace.insert("tildeassign", "~=");
	replace.insert("usignedrightshift", ">>>");
	replace.insert("usignedrightshiftassign", ">>>=");
	replace.insert("xor", "^");
	replace.insert("xorassign", "^=");
	replace.insert("xorxor", "^^");
	replace.insert("xorxorassign", "^^=");
	replace.insert("decrement","--");
	replace.insert("increment","++");

	Random tw = new Random();
	//log("%u %s %s %u", lexCount, inputFile, outputFile, tw.next());
	
	FileReader fr = new FileReader(inputFile);
	fr.parse();
	Map!(string,Deque!(Deque!(string))) rules = 
		new Map!(string,Deque!(Deque!(string)));

	// this is needed to create identifer that don't resample keywords
	Set!(string) keywords = new Set!(string)();

	// fill the map with the productions
	Deque!(Production) prods = fr.getProductions();
	foreach(Production it; prods) {
		//printf("%s := ", it.getStartSymbol);
		Deque!(string) kw = new Deque!(string)(split(trim(it.getProdString())));
		MapItem!(string,Deque!(Deque!(string))) item = 
			rules.find(trim(it.getStartSymbol));
		if(item !is null) {
			item.getData().pushBack(kw);
		} else {
			Deque!(Deque!(string)) tmp = new Deque!(Deque!(string))();
			tmp.pushBack(kw);
			rules.insert(trim(it.getStartSymbol()), tmp);
		}
		foreach(string jt; kw) { // to get the names of the keywords
			//printf("%s ", jt);
			if(isLowerCase(jt)) {
				keywords.insert(jt);
			}
		}
		//println();
	}

	//log("%u == %u ???", rules.getSize(), prods.getSize());
	//log("%u", keywords.getSize());
	foreach(string it; keywords) {
		//log("%s %s", it, processString(it, keywords, tw));
	}

	File output = new File(outputFile, FileMode.OutNew);
	StringBuffer!(char) curline = new StringBuffer!(char)(128);
	size_t cnt = 0;
	size_t runs = 0;
	while(cnt < lexCount) {
		//log("%u", runs);
		cnt += process(startSymbol, rules, output, curline, tw, keywords, 0, 
			replace);
	}
	log();
	output.writeLine(curline.getString());
	output.close();
}

size_t process(string start, Map!(string,Deque!(Deque!(string))) m, 
		File output, StringBuffer!(char) curline, Random tw, 
		Set!(string) keywords, size_t depth, Map!(string,string) replace) {
	assert(start !is null);
	assert(keywords !is null);
	assert(m !is null);
	assert(curline !is null);
	// the position in the rule
	size_t pos = 0;
	// how many terminals have been written
	size_t count = 0;

	// get the linkedlist of pro
	MapItem!(string,Deque!(Deque!(string))) it = m.find(start);
	assert(it !is null, start);
	Deque!(Deque!(string)) list = it.getData();

	// get a random rule and process it
	size_t whichRule = tw.uniform!(size_t)() % list.getSize();
	assert(whichRule >= 0 && whichRule < 1000);
	//log("%u %u", whichRule, list.getSize());
	Deque!(string) rule = list[whichRule];
	if(depth > maxdepth) { // maximal maxdepth
		foreach(Deque!(string) it; list) {
			if(it[0] == "epsilon") {
				rule = it;
				break;
			}
		}
	}
	assert(rule !is null);
	foreach(size_t pos, string symbol; rule) {
		//log("%u %u/%u %s", whichRule, pos, rule.getSize(), symbol);
		//log(symbol);
		if(symbol[0] >= 65 && symbol[0] < 91) {
			//log("%u %b %b %b %b", depth, symbol is null, m is null, curline is null, keywords is null);
			count += process(symbol, m, output, curline, tw, keywords, depth++,
				replace);	
		} else {
			//log();
			count++;
			curline.pushBack(processString(symbol, keywords, tw, replace));
			curline.pushBack(' ');
			if(curline.getSize() >= 80) {
				output.writeLine(curline.getString());
				curline.clear();
			}
			//log();
		}
	}
	//println();
	return count;
}

string processString(string str, Set!(string) keywords, Random tw, 
		Map!(string,string) replace) {
	switch(str) {
		case "identifier": {
			StringBuffer!(char) ret = new StringBuffer!(char)();
			do {
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
		case "astring": {
			StringBuffer!(char) ret = new StringBuffer!(char)();
			ret.pushBack("\"");
			do {
				ret.clear();
				size_t len = tw.next() % 14;
				for(size_t i = 0; i < len; i++) {
					ret.pushBack(tw.next() % 2 == 0 ?
						tw.next() % 26 + 65 : // big chars
						tw.next() % 26 + 97); // small chars
				}
			} while(keywords.contains(ret.getString()));
			ret.pushBack("\"");
			return ret.getString();
		}
		case "characterliteral": {
			StringBuffer!(char) ret = new StringBuffer!(char)();
			ret.pushBack("'");
			switch(tw.next() % 3) {
				case 0:
					ret.pushBack(conv!(int,string)(tw.next() % 10));
					ret.pushBack("'");
					return ret.getString();
				case 1:
					ret.pushBack(cast(char)(tw.next() % 26 + 65));
					ret.pushBack("'");
					return ret.getString();
				case 2:
					ret.pushBack(cast(char)(tw.next() % 26 + 97));
					ret.pushBack("'");
					return ret.getString();
				default:
					assert(false);
			}
			assert(false);
		}
		case "integer": {
			return conv!(uint,string)(tw.next() % 1024);
		}
		case "float":
			return conv!(uint,string)(tw.next() % 1024) ~ "." ~
				conv!(uint,string)(tw.next() % 1024);
		default:
			if(replace.contains(str)) {
				return replace.find(str).getData();
			} else {
				return str;
			}
	}
}
