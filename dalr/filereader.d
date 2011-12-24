module dalr.filereader;

import dalr.grammerparser;
import dalr.productionmanager;

import hurt.container.deque;
import hurt.conv.conv;
import hurt.io.stream;
import hurt.io.file;
import hurt.util.pair;

private enum ParseState {
	None,
	UserCode,
	Production,
	ProductionCode
}

class FileReader {
	// the name of the input file
	private string filename;
	private Deque!(string) userCode;
	private Deque!(Pair!(string,string)) productions;
	
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
		foreach(size_t idx, char[] it; this.inFile) {
			ParseState ps = ParseState.None;			
			final switch(ps) {
				case ParseState.None:
					int userCodeIdxLeft = userCodeParanthesis(it);
					// found a userCode start
					if(userCodeIdxLeft != -1) {
						int userCodeIdxRight = userCodeParanthesis(it, 
							userCodeIdxLeft+2);
						if(userCodeIdxRight != -1) {
							this.userCode.pushBack(it[userCodeIdxLeft+2 ..
								userCodeIdxRight].idup);

						} else {
							ps = ParseState.UserCode;
						}
					}
				case ParseState.UserCode:
				case ParseState.Production:
				case ParseState.ProductionCode:
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
