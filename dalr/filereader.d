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
import hurt.util.slog;

private enum ParseState {
	None,
	UserCode,
	Production,
	ProductionCode
}

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
	}

	public void parse() {
		StringBuffer!(char) tmp = new StringBuffer!(char)(128);
		ParseState ps = ParseState.None;			
		foreach(size_t idx, char[] it; this.inFile) {
			final switch(ps) {
				case ParseState.None:
					int userCodeIdxLeft = userCodeParanthesis(it);
					log("%d", userCodeIdxLeft);
					// found a userCode start
					if(userCodeIdxLeft != -1) {
						int userCodeIdxRight = userCodeParanthesis(it, 
							userCodeIdxLeft+2);
						// does the userCode end in this line
						log("%d", userCodeIdxRight);
						if(userCodeIdxRight != -1) {
							this.userCode.pushBack(it[userCodeIdxLeft+2 ..
								userCodeIdxRight].idup);
						} else {
							tmp.pushBack(it[userCodeIdxLeft+2..$]);
							tmp.pushBack('\n');
							ps = ParseState.UserCode;
						}
						break;
					}
					// find the start of an production
					size_t colom = findArr!(char)(it, ":=");
					// check if the colom appears after the start of a comment
					size_t comment = findArr!(char)(it, "//");
					log("colom %d comment %d %d", colom, comment, it.length);
					if(colom < it.length && colom < comment) {
						string[] startSym = split!(char)(it[0..colom].idup,
							' ');
						assert(startSym.length == 1, 
							"Start of a production must be unique");

						// check if the code for the production starts on the
						// same line
						size_t productionCodeIdx = findArr!(char)(it, "{:", 
							colom+2);

						if(productionCodeIdx < it.length) {
							this.productions.pushBack(
								new Production(startSym[0], 
								it[colom+2 .. productionCodeIdx].idup));

							// does the production code end on the same line
							size_t productionCodeIdxEnd = findArr!(char)(it,
								":}", productionCodeIdx+2);

							if(productionCodeIdxEnd < it.length) {
								this.productions.back().setAction(it[
									productionCodeIdx+2 .. 
									productionCodeIdxEnd].idup);
								ps = ParseState.None;
							} else {
								ps = ParseState.ProductionCode;
							}
						} else {
							// well, we didn't find the start of the user code
							// so the production might be longer than one line
							tmp.pushBack(it[colom+2 .. productionCodeIdx]);
							this.productions.pushBack(new Production(
								startSym[0]));
							ps = ParseState.Production;
						}
					}
					break;
				case ParseState.UserCode: {
					// check if the userCode block ends
					int userCodeIdx = userCodeParanthesis(it);
					log("%d", userCodeIdx);
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
					size_t nextProd = find!(char)(it, '|');
					size_t productionCodeIdxEnd = findArr!(char)(it, "{:");
					size_t newProd = findArr!(char)(it, ":=");
					log("nextProd %d productionCodeIdxEnd %d it.length %d",
						nextProd, productionCodeIdxEnd, it.length);
					if(newProd < it.length) {
						this.productions.back().setProdString(tmp.getString());
						tmp.clear();
						goto case ParseState.None;
					} else if(nextProd < it.length || 
							productionCodeIdxEnd < it.length) {
						// found a | so a new production starts
						if(nextProd < it.length) { 
							this.productions.back().setProdString(
								tmp.getString());
							tmp.clear();
							this.productions.pushBack(new Production(
								this.productions.back().startSymbol));
							// the new productions ends on the same line
							if(productionCodeIdxEnd < it.length) {
								this.productions.back().setProdString(
									it[nextProd+1 .. productionCodeIdxEnd].
									idup);
								size_t prodCodeEnd = findArr!(char)(it, ":}");
								// the prod code ends on the same line
								if(prodCodeEnd < it.length) {
									this.productions.back().setAction(
										it[prodCodeEnd+2 .. prodCodeEnd].idup);
								}
							} else { // or the productions goes for more lines
								tmp.pushBack(it[nextProd+1 .. $]);
								ps = ParseState.Production;
							}
						// a production is done and a prod code starts
						} else if(productionCodeIdxEnd < it.length) {
							tmp.pushBack(it[0 .. productionCodeIdxEnd]);
							log("%s", tmp.getString);
							this.productions.back().setProdString(
								tmp.getString());
							assert(this.productions.back().prodString !is null);
							// clear the stringbuffer and save the rest of the
							// production
							tmp.clear();
							size_t proCodeEnd = findArr!(char)(it, ":}");
							if(proCodeEnd < it.length) {
								this.productions.back().setProdString(
									tmp.getString());
								this.productions.back().setAction(	
									it[productionCodeIdxEnd+2 .. proCodeEnd].
									idup);
								tmp.clear();
							} else {
								tmp.pushBack(it[productionCodeIdxEnd+2 .. $]);
							}
							

						}
					} else { // the production is not done
						tmp.pushBack(it);
					}
					break;
				case ParseState.ProductionCode:
					size_t productionCodeIdxEnd = findArr!(char)(it,
						":}");
					if(productionCodeIdxEnd < it.length) {
						tmp.pushBack(it[0 .. productionCodeIdxEnd]);
						this.productions.back().setAction(tmp.getString());
						ps = ParseState.None;
					} else {
						tmp.pushBack(it);
					}
					break;
			}
		}
		if(ps == ParseState.Production) {
			this.productions.back().setProdString(tmp.getString);	
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
