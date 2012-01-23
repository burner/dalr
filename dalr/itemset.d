module dalr.itemset;

import dalr.item;
import dalr.productionmanager;

import hurt.math.bigintbase10;
import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

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

	this(long id) {
		this.id = id;
		this.items = new Deque!(Item)();
	}

	public void addItem(Item item) {
		assert(item !is null);
		// check that there are not duplications
		assert(!this.items.contains(item));
		this.items.pushBack(item);
	}

	public ItemSet copy() {
		ItemSet ret = new ItemSet(this.id);	
		foreach(Item it; this.items) {
			assert(it !is null);
			Item copy = it.copy();
			assert(copy !is null);
			ret.addItem(copy);
		}
		
		// new follow set
		Map!(int,ItemSet) nfs = new Map!(int,ItemSet)(ISRType.HashTable);
		ISRIterator!(MapItem!(int,ItemSet)) it = this.followSets.begin();
		for(; it.isValid(); it++) {
			nfs.insert((*it).getKey, (*it).getData().copy());
		}
		assert(nfs == this.followSets);
		ret.setFollow(nfs);
		return ret;
	}

	public void makeFrontOfExtended(int prod, Deque!(int) extProd, bool last) {
		if(last) {
			extProd.pushFront(conv!(long,int)(this.id));
		} else {
			if(!this.followSets.contains(prod)) {
				extProd.pushFront(-1);
				extProd.pushFront(prod);
				extProd.pushFront(conv!(long,int)(this.id));
			} else {
				MapItem!(int, ItemSet) next = this.followSets.find(prod);
				next.getData().makeFrontOfExtended(prod, extProd, true);
				extProd.pushFront(prod);
				extProd.pushFront(conv!(long,int)(this.id));
			}
		}
	}

	public size_t makeExtendedProduction(size_t pos, const Deque!(int) prod, 
			Deque!(int) extProd) {

		extProd.pushBack(conv!(long,int)(this.id));
		if(pos < prod.getSize()) {
			//extProd.pushBack(prod.opIndexConst(pos));
			if(!this.followSets.contains(prod.opIndexConst(pos))) {
				throw new Exception(
					format("no followSet present for input %d", 
						prod.opIndexConst(pos)));
			} else {
				MapItem!(int, ItemSet) next = this.followSets.find(
					prod.opIndexConst(pos));
				extProd.pushBack(prod.opIndexConst(pos));
				next.getData().makeExtendedProduction(pos+1, prod, extProd);
			}
		}
		return extProd.getSize();
	}

	public Deque!(Item) getItems() {
		return this.items;
	}

	public size_t getItemCount() const {
		return this.items.getSize();
	}

	public void setItems(Deque!(Item) ne) {
		this.items = new Deque!(Item)(ne);
	}

	public Map!(int, ItemSet) getFollowSet() {
		return this.followSets;
	}

	public bool removeItem(Item item, ProductionManager pm) {
		size_t idx = this.items.find(item);
		// item not found
		if(idx == this.items.getSize()) {
			return false;
		} 
		this.items.remove(idx);
		// test that the remove worked, still not 100% sure if deque is all right
		idx = this.items.find(item);
		assert(idx == this.items.getSize());

		// remove the followSymbol from the folloSets because this is now
		// saved in the followSet of the subitem
		int followSymbol = pm.getSymbolFromProduction(item);
		MapItem!(int,ItemSet) followIt = this.followSets.find(followSymbol);	

		// sanity
		assert(followIt !is null);

		this.followSets.remove(followIt.getKey());
		followIt = this.followSets.find(followSymbol);	

		// sanity
		assert(followIt is null);

		return true;
	}

	public long getFollowOnInput(int input) {
		assert(this.followSets !is null);	
		MapItem!(int, ItemSet) found = this.followSets.find(input);
		if(found !is null) {
			return found.getData().getId();
		} else {
			return -99;
		}
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

		ulong tCnt = 0;
		ulong cCnt = 0;
		for(size_t idx; idx < this.items.getSize(); idx++) {
			tCnt += this.items.opIndexConst(idx).toHash();
		}
		for(size_t idx; idx < c.items.getSize(); idx++) {
			cCnt += c.items.opIndexConst(idx).toHash();
		}
		if(tCnt > cCnt) {
			return 1;
		} else if(tCnt < cCnt) {
			return -1;
		} else {
			assert(this == c);
			return 0;
		}
	}

	public override string toString() {
		StringBuffer!(char) ret = new StringBuffer!(char)();
		foreach(Item it; this.items) {
			ret.pushBack(it.toString());	
			ret.pushBack('\n');
		}
		return ret.getString();
	}

	public override bool opEquals(Object o) const {
		ItemSet item = cast(ItemSet)o;
		if(item.items.getSize() != this.items.getSize())
			return false;

		outer: for(size_t idx = 0; idx < this.items.getSize(); idx++) {
			for(size_t jdx = 0; jdx < item.items.getSize(); jdx++) {
				if(this.items.opIndexConst(idx) == 
						item.items.opIndexConst(jdx)) {
					continue outer;
				}
			}
			return false;
		}
		return true;
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

	ItemSet c = b.copy();
	assert(c == b);

	assert(a <= a);
	assert(a >= a);
	assert(b >= b);
	assert(b <= b);
	assert(a != b);
	bool cmp = a < b;
	assert((a > b) != cmp);

	map.insert(b, 22);
	assert(map.contains(a), "item not contained");
	assert(map.contains(b), "item not contained");
	assert(a == a);
	assert(a != b);
	assert(b == b);
	assert(b != a);
}
