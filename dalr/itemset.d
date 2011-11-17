module dalr.itemset;

import dalr.item;

import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;

// a set of items aka lr(0) set
class ItemSet {
	private Map!(int, ItemSet) followSets;
	private Deque!(Item) items;
	private long id;

	this(Deque!(Item) kernel, long id = -1) {
		assert(kernel !is null);
		this.items = new Deque!(Item)(kernel);
		this.followSets = new Map!(int,ItemSet)(ISRType.HashTable);
		this.id = id;
	}

	public void addItem(Item item) {
		assert(item !is null);
		assert(!this.items.contains(item));
		this.items.pushBack(item);
	}

	public Deque!(Item) getItems() {
		return this.items;
	}

	public Map!(int, ItemSet) getFollowSet() {
		return this.followSets;
	}

	public void setFollow(Map!(int,ItemSet) follow) {
		this.followSets = follow;
	}

	public void setId(long id) {
		this.id = id;
	}

	public long getId() const {
		return this.id;
	}

	public override int opCmp(Object o) const {
		ItemSet c = cast(ItemSet)o;
		int cntT = 0, cntC = 0;
		for(size_t idx = 0; idx < this.items.getSize(); idx++) {
			if(idx >= c.items.getSize()) {
				cntT++;
			} else if(this.items.opIndexConst(idx) > 
					c.items.opIndexConst(idx)) {
				cntT++;
			} else if(this.items.opIndexConst(idx) < 
					c.items.opIndexConst(idx)) {
				cntC++;
			} else if(this.items.opIndexConst(idx) == 
					c.items.opIndexConst(idx)) {
				continue;
			} else {
				assert(false, "invalid case");
			}
		}
		if(cntT == cntC)
			return 0;
		else if(cntT > cntC)
			return 1;
		else if(cntT < cntC)
			return -1;
		else
			assert(false, "invalid case");
	}

	public override bool opEquals(Object o) const {
		ItemSet item = cast(ItemSet)o;
		return this.items == item.items;
	}

	public override hash_t toHash() const {
		hash_t ret = this.items.getSize();
		for(size_t idx; idx < this.items.getSize(); idx++) {
			ret += this.items.opIndexConst(idx).toHash();
		}
		return ret;
	}
}

unittest {
	Map!(ItemSet,int) map = new Map!(ItemSet,int)();
	Deque!(Item) de = new Deque!(Item)([new Item(0,1), new Item(1,1), 
		new Item(1,0)]);
	ItemSet a = new ItemSet(de);
	map.insert(a, 11);
	assert(map.contains(a), "item not contained");
	de.pushBack(new Item(2,0));
	ItemSet b = new ItemSet(de);
	map.insert(b, 22);
	assert(map.contains(a), "item not contained");
	assert(map.contains(b), "item not contained");
	assert(a == a);
	assert(a != b);
	assert(b == b);
	assert(b != a);
}
