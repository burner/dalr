module dalr.filereader;

import dalr.grammerparser;

import hurt.container.deque;
import hurt.container.mapset;
import hurt.container.set;
import hurt.container.isr;
import hurt.exception.exception;
import hurt.conv.conv;
import hurt.io.stream;
import hurt.io.file;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.string.stringutil;
import hurt.util.pair;
import hurt.util.array;
import hurt.util.slog;
import hurt.math.mathutil;

class Production {
	private string startSymbol;
	private string prodString;
	private string action;
	private string precedence;

	this(string startSymbol) {
		this.startSymbol = startSymbol;
	}

	this(string startSymbol, string prodString) {
		this(startSymbol);
		this.prodString = prodString;
	}

	this(string startSymbol, string prodString, string action) {
		this(startSymbol, prodString);
		this.action = action;
	}

	void setProdString(string inProdString) {
		this.prodString = inProdString;
	}

	void setAction(string inAction) {
		this.action = inAction;
	}

	public string getAction() {
		return this.action;
	}

	public string getProduction() {
		return trim(this.startSymbol) ~ " := " ~ trim(this.prodString);
	}

	public string getProdString() {
		return this.prodString;
	}

	public string getPrecedence() {
		return this.precedence;
	}

	public void setPrecedence(string precedence) {
		this.precedence = precedence;
	}

	public string getStartSymbol() const {
		return this.startSymbol;
	}

	public override string toString() {
		return this.getProduction();
	}
}

class ConflictIgnore {
	private Deque!(string) rules;
	private Deque!(Deque!(int)) rulesInt;
	private size_t cnt;

	this() {
		this.rules = new Deque!(string)();
		this.rulesInt = new Deque!(Deque!(int))();
		this.cnt = 0;
	}

	public void addRule(string rule) {
		enforce(!this.rules.contains(rule), 
			format("rule \"%s\" allready present in ConflictIgnore", rule));
		this.rules.pushBack(rule);
	}

	public void addRule(Deque!(int) rule) {
		enforce(!this.rulesInt.contains(rule), 
			format("rule allready present in ConflictIgnore"));
		this.rulesInt.pushBack(rule);
	}
	
	public bool holdsRules(Deque!(Deque!(int)) rule) {
		return this.rulesInt == rule;
	}

	public bool holdsRule(Deque!(int) rule) {
		return this.rulesInt.contains(rule);
	}

	public bool holdsRules(Deque!(string) rule) {
		return this.rules == rule;
	}

	public bool holdsRule(string rule) {
		return this.rules.contains(rule);
	}

	public void increCnt() {
		this.cnt++;
	}

	public size_t getCnt() const {
		return this.cnt;
	}

	public Iterator!(string) getRuleIterator() {
		return this.rules.begin();
	}

	public override string toString() {
		auto ret = new StringBuffer!(char)(1024);
		ret.pushBack("%{\n");
		foreach(it; this.rules) {
			ret.pushBack(it);
			ret.pushBack('\n');
		}
		ret.pushBack("}%\n");
		return ret.getString();
	}
}

class FileReader {
	// the name of the input file
	private string filename;
	private Deque!(string) userCode;
	private Deque!(Production) productions;
	private Deque!(string) stash;
	private MapSet!(int,string) leftAssociation;
	private MapSet!(int,string) rightAssociation;
	private Set!(string) nonAssociation;
	private int associationCnt;
	private size_t line;
	private bool glr;
	private Deque!(ConflictIgnore) conflictIgnores;
	private uint disCounter;
	private uint ruleSplitCnt;
	
	// input file
	private InputStream inFile;

	/** This function is called to make sure that the given filename
	 *  if of form *.dex
	 *
	 *  @param filename The filename to check
	 *
	 *  @return true if ends on .dex false otherwise
	 */
	private static bool isWellFormedFilename(in string filename) {
		if(filename.length <= 4)
			return false;

		if(filename[$-4..$] != ".dlr")
			return false;

		return true;
	}

	this(string filename) {
		this.filename = filename;

		// test if file has formated name, very bad test if the file is valid
		if(!FileReader.isWellFormedFilename(filename)) {
			throw new Exception(format("Filename not well formed %s",
				filename));
		}
	
		// test if the file exists
		if(!exists(this.filename))
			throw new Exception("File does not Exist");

		// open the file
		this.inFile = new File(filename);
		this.userCode = new Deque!(string)();
		this.productions = new Deque!(Production)();
		this.stash = new Deque!(string)();

		// assocication
		this.leftAssociation = new MapSet!(int,string)();
		this.rightAssociation = new MapSet!(int,string)();
		this.nonAssociation = new Set!(string)();
		this.associationCnt = 1;
		this.line = 1;
		this.glr = false;

		this.conflictIgnores = new Deque!(ConflictIgnore)();

		this.disCounter++;
		this.ruleSplitCnt = 0;
	}

	public Deque!(ConflictIgnore) getConflictIgnores() {
		return this.conflictIgnores;
	}

	public bool isGlr() const {
		return this.glr;
	}

	public string getNextLine() {
		if(this.inFile.eof() && this.stash.isEmpty()) {
			throw new Exception("No more lines present");
		} else if(!this.stash.isEmpty()) {
			return this.stash.popBack();	
		} else {
			this.line++;
			return this.inFile.readLine().idup;
		}
	}

	private size_t getLineNumber() const {
		return this.line;
	}

	public Deque!(Production) getProductions() {
		return this.productions;
	}

	public bool isEof() {
		return this.inFile.eof() && this.stash.isEmpty();
	}

	public void stashString(string str) {
		assert(this.stash.getSize() < 1);
		this.stash.pushBack(str);
	}

	public void parse() {
		while(!this.isEof()) {
			string cur = this.getNextLine();

			// is the line a comment
			size_t comment = findArr!(char)(cur, "//");
			if(comment < cur.length) {
				continue;
			}

			// check for usercode
			int userCodeIdx = userCodeParanthesis(cur);
			if(userCodeIdx != -1 && userCodeIdx < comment) {
				this.parseUserCode(cur);
				continue;
			}

			// check if we have to emit a glr parse table
			// if not shift reduce conflict will be solved in favor
			// of the shift
			size_t glr = findArr!(char)(cur, "%glrParser");
			if(glr != cur.length) {
				this.glr = true;
			}

			// check for precedence symbols
			size_t left = findArr!(char)(cur, "%left");
			size_t right = findArr!(char)(cur, "%right");
			size_t nonassoc = findArr!(char)(cur, "%nonassoc");

			if(left < cur.length || right < cur.length || 
					nonassoc < cur.length) {
				this.parseAssociation(cur, left < cur.length ? 0 :
					right < cur.length ? 1 : 
					nonassoc < cur.length ? 2 : 3);
				continue;
			}

			bool didSomething = false;

			// grammer rules
			size_t prodStart = findArr!(char)(cur, ":=");
			size_t pipe = find!(char)(cur, '|');
			//log("%u %u", prodStart, pipe);
			if(prodStart < cur.length) {
				cur = this.parseProduction(cur);
				this.checkAndSetPrecedence!("%prec")(productions.back());
				didSomething = true;
			} else if(pipe < cur.length) {
				cur = this.parseProduction(cur, true);
				this.checkAndSetPrecedence!("%prec")(productions.back());
				didSomething = true;
			}

			// production code 
			size_t prodCodeStart = findArr!(char)(cur, "{:");
			if(prodCodeStart < cur.length) {
				cur = this.parseProductionAction(cur);
				didSomething = true;
			}

			// to igore know conflicts
			size_t conIgnore = findArr!(char)(cur, "%{");
			if(conIgnore < cur.length) {
				cur = this.parseConflictIgnore(cur);
				didSomething = true;
			}

			if(cur.length > 0 && !didSomething) {
				foreach(size_t idx, char it; cur) {
					assert(isWhiteSpace(it), 
						format("error in line %d:%d with char %c",
						this.getLineNumber(), idx, it));		
				}
			}

		}
	}

	private void checkAndSetPrecedence(string type)(Production prod) 
			if(type == "%prec" || type == "%glr") {
		size_t prec = findArr!(char)(prod.getProdString, type);

		// check if type is in the prod string
		if(prec == prod.getProdString().length) {
			return;
		}

		string tmp = prod.getProdString()[0 .. prec];
		string precSymbol = prod.getProdString()[prec + type.length .. $];
		static if(type == "%prec") {
			assert(leftAssociation.containsElement(trim(precSymbol)) || 
				   rightAssociation.containsElement(trim(precSymbol)), 
				   format("precedence symbol %s must was not defined", 
				   trim(precSymbol)));
		}

		//log("%s %s", tmp, precSymbol);
		static if(type == "%prec") {
			prod.setProdString(tmp);
			prod.setPrecedence(trim(precSymbol));
			assert(prod.getProdString == tmp);
			assert(prod.getPrecedence() == trim(precSymbol));
		} else {
			prod.setProdString(tmp);
			prod.setPrecedence("glr");
		}
	}

	private void parseAssociation(string cur, int type) {
		string[] split = split(cur);
		assert(split.length > 1);

		// save the symbols stupid in case of nonassoc
		// but I'm to tried to figure something better
		Set!(string) set = new Set!(string)();
		foreach(string str; split[1 .. $]) {
			set.insert(trim(str));
		}

		switch(type) {
			case 0: // left
				assert(trim(split[0]) == "%left");
				this.leftAssociation.insert(this.associationCnt++, set);
				return;
			case 1: // right
				assert(trim(split[0]) == "%right");
				this.rightAssociation.insert(this.associationCnt++, set);
				return;
			case 2: // nonassoc
				assert(trim(split[0]) == "%nonassoc");
				foreach(string it; split[1 .. $]) {
					this.nonAssociation.insert(trim(it));
				}
				return;
			default:
				assert(false, format("precedence definiation failed." ~
					" type value was %d in line %s", type, cur));
		}
	}

	private string parseProduction(string cur, bool startOld = false) {
		string start;
		auto sb = new StringBuffer!(char)(128);
		size_t semi, colom, semicolon, actionStart, actionEnd;

		if(startOld) {
			colom = find!(char)(cur, '|');
			assert(colom < cur.length,
				format("should have found a colom %d %d %s", colom, cur.length,
				cur));
			start = this.productions.back().startSymbol;
		} else {
			colom = findArr!(char)(cur, ":=");
			start = cur[0 .. colom];
			assert(colom < cur.length, 
				format("should have found a colom %d %d %s", colom, cur.length,
				cur));
		}

		colom = colom + (startOld ? 1 : 2);
		log("%s %d", cur, colom);
		cur = cur[colom .. $];
		log("%s", cur);
		//log("%s %s %d:%d=%d",start, cur, colom, (startOld ? 1 : 2),colom + (startOld ? 1 : 2) );

		string leftNew = format("rule%d", this.ruleSplitCnt++);
		string rightNew = format("rule%d", this.ruleSplitCnt++);
		bool splitParse = false;
		assert(leftNew != rightNew);

		do {
			semi = find!(char)(cur, ';');
			actionStart = findArr!(char)(cur, "{:");
			// simple semicolon end and maybe a action following
			if( (semi < cur.length && actionStart < cur.length && 
					semi < actionStart) || 
					( semi < cur.length && actionStart == cur.length) ) {

				sb.pushBack(cur[0 .. min(semi, actionStart)]);
				log("%s", sb.getString());
				if(!splitParse) {
					this.productions.pushBack(new Production(start,sb.getString()));
				} else {
					this.productions.pushBack(new Production(rightNew,sb.getString()));
				}

				log("%s", this.productions.back().toString());
				return cur;
			// we found a semicolon and a actionstart and the semicolon is found 
			// earlier than the actionstart. or we found just a  actionstart
			} else if( (semi < cur.length && actionStart < cur.length && 
					semi > actionStart) || 
					(semi == cur.length && actionStart < cur.length) ){
				splitParse = true;
				
				sb.pushBack(cur[0 .. actionStart]);
				this.productions.pushBack(
					new Production(leftNew, sb.getString()));

				log("%s", this.productions.back().toString());
				sb.clear();
				cur = this.parseProductionAction(cur[actionStart .. $]);
				actionEnd = findArr!(char)(cur, ":}");
				cur = cur[actionEnd + 2 .. $];
				semi = find!(char)(cur, ';');
				if(semi < cur.length) {
					this.productions.pushBack(new Production(rightNew,
						cur[0 .. semi]));
					this.productions.pushBack(
						new Production(start, leftNew ~ " " ~ rightNew));
					log("%s", this.productions.back().toString());
					return cur[semi .. $];
				} else {
					sb.pushBack(cur[semi+1 .. $]);
				}
			} else {
				sb.pushBack(cur);
			}
			if(this.isEof()) {
				assert(false, "haven't found a semicolom befor eof");
			}
			colom = 0;
			cur = this.getNextLine();
		} while(true);
		assert(false, "you should not reach this");
	}

	/*private string parseProduction(string cur, bool startOld = false) {
		string start;
		size_t colom;
		size_t semi = find!(char)(cur, ';');
		StringBuffer!(char) tmp = new StringBuffer!(char)(128);

		if(startOld) {
			colom = find!(char)(cur, '|');
			assert(colom < cur.length,
				format("should have found a colom %d %d %s", colom, cur.length,
				cur));
			start = this.productions.back().startSymbol;
			tmp.pushBack(cur[colom+1 .. semi]);
		} else {
			colom = findArr!(char)(cur, ":=");
			start = cur[0 .. colom];
			assert(colom < cur.length, 
				format("should have found a colom %d %d %s", colom, cur.length,
				cur));
			tmp.pushBack(cur[colom+2 .. semi]);
		}

		// as long as we find no semicolom
		while(semi == cur.length) {
			if(this.isEof()) {
				assert(false, "haven't found a semicolom befor eof");
			} else {
				cur = this.getNextLine();	
				semi = find!(char)(cur, ';');

				colom = find!(char)(cur, '|');
				assert(colom == cur.length, 
					format("found a pipe will parsing a production at line %u",
					this.getLineNumber()));
				colom = findArr!(char)(cur, ":=");
				assert(colom == cur.length, format("found a productionstart" ~
					" will parsing a production at line %u %s", 
					this.getLineNumber(), cur));
			}
			tmp.pushBack(cur[0 .. semi]);
		}
		if(startOld) { // semicolom was in first line
			Production last = this.productions.back();
			this.productions.pushBack(
				new Production(last.startSymbol, tmp.getString()));
		} else if(!startOld) { // semicolom wasn't in first line
			this.productions.pushBack(
				new Production(start, tmp.getString()));
		}
		this.productions.pushBack(new Production(start, tmp.getString()));
		return cur;
	}*/

	private string parseConflictIgnore(string cur) {
		size_t conStart = findArr!(char)(cur, "%{");	
		size_t conEnd = findArr!(char)(cur, "}%");	
		ConflictIgnore c = new ConflictIgnore();
		if(conStart < cur.length && conEnd < cur.length &&
				conStart < conEnd) {
			string between = cur[conStart+2 .. conEnd];		
			string[] prods = split(between, ';');
			enforce(prods.length > 1, format(
				"the conflict ignore block at line %d did only contain %u" ~
				" productions. at least two are needed", this.getLineNumber(),
				prods.length));

			foreach(it; prods) {
				string trimmed = trim(it);
				assert(trimmed.length > 0);
				enforce(!c.holdsRule(trimmed), format("the rule \"%s\" can " ~
					"only be added once. The error occured at line %u",
					trimmed, this.getLineNumber()));

				c.addRule(trimmed);
			}
			this.conflictIgnores.pushBack(c);
		} else if(conStart < cur.length && conEnd == cur.length) {
			StringBuffer!(char) tmp = new StringBuffer!(char)(1024);
			tmp.pushBack(cur[conStart+2 .. $]);
			do {
				cur = this.getNextLine();
				conEnd = findArr!(char)(cur, "}%");
				tmp.pushBack(cur[0 .. conEnd]);
			} while(conEnd == cur.length);

			string[] prods = split(tmp.getString(), ';');
			enforce(prods.length > 1, format(
				"the conflict ignore block at line %d did only contain %u" ~
				" productions. at least two are needed", this.getLineNumber(),
				prods.length));

			foreach(it; prods) {
				string trimmed = trim(it);
				assert(trimmed.length > 0);
				enforce(!c.holdsRule(trimmed), format("the rule \"%s\" can " ~
					"only be added once. The error occured at line %u",
					trimmed, this.getLineNumber()));

				c.addRule(trimmed);
			}
			this.conflictIgnores.pushBack(c);
		} else {
			assert(false, format("a conflict ignore didn't start at line %d",
				this.getLineNumber()));
		}

		return this.getNextLine();
	}

	private string parseProductionAction(string cur) {
		size_t actionStart = findArr!(char)(cur, "{:");	
		size_t actionEnd = findArr!(char)(cur, ":}");	
		// the action spans only one line
		if(actionStart < cur.length && actionEnd < cur.length && 
				actionStart < actionEnd) {
			this.productions.back().setAction(cur[actionStart+2 .. actionEnd]);
			return cur;
		// the action spans for more than one line
		} else if(actionStart < cur.length && actionEnd == cur.length) {
			StringBuffer!(char) tmp = new StringBuffer!(char)(128);
			// save the line
			tmp.pushBack(cur[actionStart+2 .. $]);
			tmp.pushBack('\n');
			// check if there is a end of action in the new line
			cur = this.getNextLine();
			actionEnd = findArr!(char)(cur, ":}");
			// if not, loop till we find a end of action
			while(actionEnd == cur.length) {
				tmp.pushBack(cur);
				tmp.pushBack('\n');
				cur = this.getNextLine();
				actionEnd = findArr!(char)(cur, ":}");
			}
			// save the rest
			tmp.pushBack(cur[0 .. actionEnd]);	
			tmp.pushBack('\n');
			this.stashString(cur[actionEnd+2 .. $]);
			this.productions.back().setAction(tmp.getString());
			return cur;
		} else {
			assert(false, "current line has no {: symbol");
		}
	}

	private string parseUserCode(string cur) {
		StringBuffer!(char) tmp = new StringBuffer!(char)();
		// this should allways work
		int userCodeIdxStart = userCodeParanthesis(cur);
		int userCodeIdxEnd = userCodeParanthesis(cur, userCodeIdxStart+2);
		// if we found the end in the same line
		if(userCodeIdxStart != -1 && userCodeIdxEnd != -1) {
			this.userCode.pushBack(cur[userCodeIdxStart+2 .. userCodeIdxEnd]);	
			this.stashString(cur[userCodeIdxEnd+2 .. $]);
			return cur;
		// while we didn't found anything save it
		} else if(userCodeIdxStart != -1 && userCodeIdxEnd == -1) {
			tmp.pushBack(cur[userCodeIdxStart+2 .. $]);	
			tmp.pushBack('\n');
			cur = this.getNextLine();
			userCodeIdxEnd = userCodeParanthesis(cur);
			while(userCodeIdxEnd == -1) {
				tmp.pushBack(cur);
				tmp.pushBack('\n');
				cur = this.getNextLine();
				userCodeIdxEnd = userCodeParanthesis(cur);
			}
			tmp.pushBack(cur[0 .. userCodeIdxEnd]);	
			tmp.pushBack('\n');
			this.stashString(cur[userCodeIdxEnd+2 .. $]);
			this.userCode.pushBack(tmp.getString());
			return cur;
		} 
		assert(false, "this should not be reached");
	}

	// a %% in a string
	private static int userCodeParanthesis(in string str, int start = 0) {
		int ret = -1;
		if(start < 0) {
			return ret;
		} else if(str.length < 2) {
			return ret;
		} else if(start >= str.length) {
			return ret;
		} else if(start == str.length-1) {
			return ret;
		}
	
		ret = 0;
		foreach(idx, it; str[start..$-1]) {
			if(it == '%' && str[start+idx+1] == '%') {
				return ret+start;	
			}
			ret++;	
			assert(ret-1 == idx, conv!(int,string)(ret-1) ~ " != " ~ 
				conv!(size_t,string)(idx));
		}
		return -1;
	}
	
	/// this function find some like {br in a given string
	private static int userCodeBrace(bool dir,char br)(in char[] str, 
			int start = 0) {
		if(start < 0) {
			return -1;
		} else if(str.length < 1)
			return -1;
		else if(start >= str.length)
			return -1;
		else if(start == str.length)
			return -1;
	
		static if(!dir) {
			foreach(idx, it; str[start..$-1]) {
				//if(it == '{' && str[idx+start+1] == ':') {
				if(it == '{' && str[idx+start+1] == br) {
					return conv!(size_t,int)(idx)+start;	
				} else if(!(it == ' ' || it == '\t')) {
					return -1;
				}
			}
		} else {
			foreach_reverse(idx, it; str[start+1..$]) {
				//if(it == '}' && str[start+idx] == ':') {
				if(it == '}' && str[start+idx] == br) {
					return conv!(size_t,int)(idx)+start;	
				} else if(!(it == ' ' || it == '\t')) {
					return -1;
				}
			}
		}
		return -1;
	}

	public string productionToString() {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);
		foreach(Production it; this.productions) {
			ret.pushBack('"');
			ret.pushBack(trim(it.startSymbol));
			ret.pushBack('"');
			ret.pushBack(" := ");
			ret.pushBack(trim(it.prodString));
			ret.pushBack('\n');
			if(it.action !is null && it.action != "") {
				ret.pushBack(" {: ");
				ret.pushBack(it.action is null ? "" : it.action);
				ret.pushBack(" :}");
				ret.pushBack('\n');
			}
			if(it.getPrecedence() !is null && it.getPrecedence() != "") {
				ret.pushBack("precedence = ");
				ret.pushBack(it.getPrecedence);
				ret.pushBack('\n');
			}
			ret.pushBack('\n');
		}
		return ret.getString();
	}

	public string userCodeToString() {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);
		foreach(string it; this.userCode) {
			ret.pushBack(it);
			ret.pushBack('\n');
		}
		return ret.getString();
	}

	public Iterator!(Production) getProductionIterator() {
		return this.productions.begin();
	}

	public MapSet!(int,string) getLeftAssociation() {
		return this.leftAssociation;
	}

	public MapSet!(int,string) getRightAssociation() {
		return this.rightAssociation;
	}

	public Set!(string) getNonAssociation() {
		return this.nonAssociation;
	}
}
