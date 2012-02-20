module token;

import hurt.string.stringbuffer;
import hurt.string.formatter;
import lextable;

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
		ret.pushBack(format("%s:%d.%d ", loc.getFile(), loc.getRow(), loc.getColumn()));
		ret.pushBack(format("%d %s", type, value));
		return ret.getString();
	}
}
