module dalr.finalitem;

enum Type {
	Term,
	NonTerm,
	Reduce,
	Shift,
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
