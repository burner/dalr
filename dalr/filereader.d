module dalr.filereader;

import dalr.grammerparser;
import dalr.productionmanager;

import hurt.container.deque;
import hurt.conv.conv;
import hurt.io.stream;
import hurt.io.file;
import hurt.string.stringbuffer;
import hurt.string.stringutil;
import hurt.util.pair;
import hurt.util.array;

private enum ParseState {
	None,
	UserCode,
	Production,
	ProductionCode
}

struct Production {
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
}

class FileReader {
	// the name of the input file
	private string filename;
	private Deque!(string) userCode;
	private Deque!(Production) productions;
	
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
	}

	public void parse() {
		StringBuffer!(char) tmp = new StringBuffer!(char)(128);
		foreach(size_t idx, char[] it; this.inFile) {
			ParseState ps = ParseState.None;			
			final switch(ps) {
				case ParseState.None:
					int userCodeIdxLeft = userCodeParanthesis(it);
					// found a userCode start
					if(userCodeIdxLeft != -1) {
						int userCodeIdxRight = userCodeParanthesis(it, 
							userCodeIdxLeft+2);
						// does the userCode end in this line
						if(userCodeIdxRight != -1) {
							this.userCode.pushBack(it[userCodeIdxLeft+2 ..
								userCodeIdxRight].idup);

						} else {
							tmp.pushBack(it[userCodeIdxLeft+2..$]);
							tmp.pushBack('\n');
							ps = ParseState.UserCode;
							break;
						}
					}
					// find the start of an production
					size_t colom = findArr!(char)(it, ":=");
					// check if the colom appears after the start of a comment
					size_t comment = findArr!(char)(it, "//");
					if(colom < it.length && colom < comment) {
						string[] startSym = split!(char)(it[0..colom].idup,
							' ');
						assert(startSym.length == 1, 
							"Start of a production must be unique");
						this.productions.pushBack(Production(startSym[0]));

						// check if the code for the production starts on the
						// same line
						size_t productionCodeIdx = findArr!(char)(it, "{:", 
							colom+2);

						if(productionCodeIdx < it.length) {
							this.productions.pushBack(Production(startSym[0], 
								it[colom+2 .. productionCodeIdx].idup));

							// does the production code end on the same line
							size_t productionCodeIdxEnd = findArr!(char)(it,
								":}", productionCodeIdx+2);

							if(productionCodeIdxEnd != it.length) {
								this.productions.back().action = it[
									productionCodeIdx+2 .. 
									productionCodeIdxEnd].idup;
							} else {
								ps = ParseState.ProductionCode;
							}
						} else {
							// well, we didn't find the start of the user code
							// so the production might be longer than one line
							tmp.pushBack(it[colom+2 .. productionCodeIdx]);
							ps = ParseState.Production;
						}
					}
					break;
				case ParseState.UserCode: {
					// check if the userCode block ends
					int userCodeIdx = userCodeParanthesis(it);
					if(userCodeIdx < it.length) {
						// push the rest to the strinbuffer
						tmp.pushBack(it[0 .. userCodeIdx]);
						tmp.pushBack("\n");
						// save the string as usercode
						userCode.pushBack(tmp.getString());

						//clean up
						tmp.clear();
						ps = ParseState.None;
					} else {
						tmp.pushBack(it);
						tmp.pushBack('\n');
					}
					break;
				}
				case ParseState.Production:
					break;
				case ParseState.ProductionCode:
					break;
			}
		}
	}

	// a %% in a string
	private static int userCodeParanthesis(in char[] str, int start = 0) {
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
}
