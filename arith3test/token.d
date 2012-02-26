module token;

import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.util.slog;
import hurt.conv.conv;

import lextable;
import parsetable;

struct Token {
	private Location loc;
	// if this is -3 treeIdx gives you the index of the ast node
	private int typ; 
	private dstring value;
	private size_t treeIdx; // the index of the ast node in the ast array

	this(int typ) {
		this.typ = typ;
	}

	this(Location loc, int typ, dstring value = "") {
		this.loc = loc;
		this.typ = typ;
		this.value = value;
		this.treeIdx = size_t.max;
	}

	string toString() const {
		scope StringBuffer!(char) ret = new StringBuffer!(char)(128);	

		// the location
		ret.pushBack(format("%s:%d.%d ", loc.getFile(), loc.getRow(), 
			loc.getColumn()));
		
		// the payload
		ret.pushBack(format("%s %s", idToString(typ), 
			conv!(dstring,string)(value)));

		return ret.getString();
	}

	public int getTyp() const {
		return this.typ;
	}

	public const(dstring) getValue() const {
		return this.value;
	}
}
