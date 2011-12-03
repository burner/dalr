module dalr.extendeditem;

class ExtendedItem {
	private int left, right, item;

	this() {
		this.left = -99;
		this.right = -99;
		this.item = -99;
	}

	this(const ExtendedItem toCopy) {
		this.left = toCopy.getLeft();
		this.item = toCopy.getItem();
		this.right = toCopy.getRight();
	}

	this(int left, int item, int right) {
		this.left = left;
		this.item = item;
		this.right = right;
	}

	public int getLeft() const {
		return this.left;
	}

	public int getRight() const {
		return this.right;
	}

	public int getItem() const {
		return this.item;
	}

	public void setLeft(int left) {
		this.left = left;
	}

	public void setRight(int right) {
		this.right = right;
	}

	public void setItem(int item) {
		this.item = item;
	}

	// TODO this will only work correctly on 64 bit machines 
	public override hash_t toHash() const {
		return (this.left << 32) + (this.item<<16) + this.right;
	}

	public override int opCmp(Object o) const {
		ExtendedItem e = cast(ExtendedItem)o;
		hash_t t = this.toHash();
		hash_t c = e.toHash();
		if(t > c)
			return 1;
		else if(t < c)
			return -1;
		else
			return 0;
	}

	public override bool opEquals(Object o) const {
		ExtendedItem item = cast(ExtendedItem)o;
		return this.left == item.left && this.item == item.item &&
			this.right == item.right;
	}
}
