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
	private bool treeIdxPlaced;

	this(int typ) {
		this.typ = typ;
		this.treeIdxPlaced = false;
	}

	this(int typ, dstring value) {
		this(typ);
		this.value = value;
	}

	this(Location loc, int typ, dstring value = "") {
		this.loc = loc;
		this.typ = typ;
		this.value = value;
		this.treeIdx = 0;
	}

	this(Location loc, int typ, size_t treeIdx) {
		this.loc = loc;
		this.typ = typ;
		this.treeIdx = treeIdx;
		this.treeIdxPlaced = true;
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

	string toStringShort() const {
		if(this.treeIdxPlaced) {
			if(value is null || value == "") {
				return format("[%s ti %u]", idToString(typ), this.treeIdx);
			} else {
				return format("[%s v %s ti %u]", idToString(typ), 
					conv!(dstring,string)(value), this.treeIdx);
			}
		} else {
			if(value is null || value == "") {
				return format("[%s]", idToString(typ));
			} else {
				return format("[%s v %s]", idToString(typ), 
					conv!(dstring,string)(value));
			}
		}
	}

	public int getTyp() const {
		return this.typ;
	}

	public const(dstring) getValue() const {
		return this.value;
	}

	public Location getLoc() const {
		return this.loc;
	}

	public size_t getTreeIdx() const {
		return this.treeIdx;
	}
}
