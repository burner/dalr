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

struct FinalItem {
	Type typ;
	int number;

	this(Type typ, int number) {
		this.typ = typ;
		this.number = number;
	}
}
