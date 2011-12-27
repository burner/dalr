module dalr.filereader;

import dalr.grammerparser;
import dalr.productionmanager;

import hurt.container.deque;
import hurt.conv.conv;
import hurt.io.stream;
import hurt.io.file;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.string.stringutil;
import hurt.util.pair;
import hurt.util.array;
import hurt.util.slog;

class Production {
	string startSymbol;
	string prodString;
	string action;

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
}

class FileReader {
	// the name of the input file
	private string filename;
	private Deque!(string) userCode;
	private Deque!(Production) productions;
	private Deque!(string) stash;
	
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
		if(!FileReader.isWellFormedFilename(filename))
			throw new Exception("Filename not well formed");
	
		// test if the file exists
		if(!exists(this.filename))
			throw new Exception("File does not Exist");

		// open the file
		this.inFile = new File(filename);
		this.userCode = new Deque!(string)();
		this.productions = new Deque!(Production)();
		this.stash = new Deque!(string)();
	}

	public string getNextLine() {
		if(this.inFile.eof()) {
			throw new Exception("No more lines present");
		} else if(!this.stash.isEmpty()) {
			return this.stash.popBack();	
		} else {
			return this.inFile.readLine().idup;
		}
	}

	public bool isEof() {
		return this.inFile.eof();
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
			// check for usercode
			int userCodeIdx = userCodeParanthesis(cur);
			if(userCodeIdx != -1 && userCodeIdx < comment) {
				this.parseUserCode(cur);
			}
			size_t prodStart = findArr!(char)(cur, ":=");
			if(prodStart < cur.length && prodStart < comment) {
				this.parseProduction(cur);
			}
		}
	}

	private void parseProduction(string cur) {
		StringBuffer!(char) tmp = new StringBuffer!(char)();
		size_t colom = findArr!(char)(cur, ":=");
		assert(colom < cur.length, 
			format("should have found a colom %d %d %s", colom, cur.length,
			cur));
		string start = cur[0 .. colom];
		size_t prodCodeStart = findArr!(char)(cur, "{:", colom+2);
		size_t prodCodeEnd = findArr!(char)(cur, ":}", colom+2);
		if(prodCodeStart < cur.length && prodCodeEnd < cur.length) {
			this.productions.pushBack(new Production(start, 
				cur[colom+2 .. prodCodeStart], 
				cur[prodCodeStart+2 .. prodCodeEnd]));
		}
	}

	private void parseUserCode(string cur) {
		StringBuffer!(char) tmp = new StringBuffer!(char)();
		// this should allways work
		int userCodeIdxStart = userCodeParanthesis(cur);
		int userCodeIdxEnd = userCodeParanthesis(cur, userCodeIdxStart+2);
		// if we found the end in the same line
		if(userCodeIdxStart != -1 && userCodeIdxEnd != -1) {
			this.userCode.pushBack(cur[userCodeIdxStart+2 .. userCodeIdxEnd]);	
			this.stashString(cur[userCodeIdxEnd+2 .. $]);
			return;
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
			return;
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
			ret.pushBack(it.startSymbol);
			ret.pushBack(" := ");
			ret.pushBack(it.prodString);
			ret.pushBack(" {: ");
			ret.pushBack(it.action is null ? "" : it.action);
			ret.pushBack(" :}");
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
}
