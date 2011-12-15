module dalr.finalitem;

enum Type {
	Accept,
	Error,
	Goto,
	ItemSet,
	NonTerm,
	Reduce,
	Shift,
	Term
}

pure string typeToString(Type t) {
	final switch(t) {
		case Type.Accept:
			return "Accept";
		case Type.Goto:
			return "Goto";
		case Type.ItemSet:
			return "ItemSet";
		case Type.NonTerm:
			return "NonTerm";
		case Type.Reduce:
			return "Reduce";
		case Type.Shift:
			return "Shift";
		case Type.Term:
			return "Term";
		case Type.Error:
			return "Error";
	}
}

struct FinalItem {
	Type typ;
	int number;

	this(Type typ, int number) {
		this.typ = typ;
		this.number = number;
	}
}
