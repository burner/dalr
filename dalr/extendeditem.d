module dalr.extendeditem;

class ExtendedItem {
	private int left, right, item;

	this() {
		this.left = -99;
		this.right = -99;
		this.item = -99;
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
}
