module token;

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
}
