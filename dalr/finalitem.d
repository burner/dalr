module dalr.finalitem;

enum Type {
	Term,
	NonTerm,
	Reduce,
	Shift,
	Goto,
	ItemSet
}

struct FinalItem {
	Type typ;
	int number;

	this(Type typ, int number) {
		this.typ = typ;
		this.number = number;
	}
}
