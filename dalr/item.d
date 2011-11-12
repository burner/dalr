module dalr.item;

// a production with a dot placed
class Item {
	private long prod;
	private long dotPos;

	this(long prod, long dotPos) {
		this.prod = prod;
		this.dotPos = dotPos;
	}

	public long getProd() const {
		return this.prod;
	}

	public long getDotPosition() const {
		return this.dotPos;
	}

	public override int opCmp(Object o) const {
		Item c = cast(Item)o;
		if(this.toHash() > c.toHash())
			return 1;
		else if(this.toHash() < c.toHash())
			return -1;
		else
			return 0;
	}

	public override bool opEquals(Object o) const {
		Item item = cast(Item)o;
		return this.prod == item.prod && this.dotPos == item.dotPos;
	}

	public override hash_t toHash() const {
		return cast(hash_t)(this.prod<<16) + this.dotPos;
	}
}
