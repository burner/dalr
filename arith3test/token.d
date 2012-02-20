module token;

import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.util.slog;
import hurt.conv.conv;

import lextable;
import parsetable;

struct Token {
	Location loc;
	int type;
	dstring value;

	this(Location loc, int type, dstring value = "") {
		this.loc = loc;
		this.type = type;
		this.value = value;
	}

	string toString() const {
		scope StringBuffer!(char) ret = new StringBuffer!(char)(128);	

		// the location
		ret.pushBack(format("%s:%d.%d ", loc.getFile(), loc.getRow(), 
			loc.getColumn()));
		
		// the payload
		ret.pushBack(format("%s %s", idToString(type), 
			conv!(dstring,string)(value)));

		return ret.getString();
	}
}
