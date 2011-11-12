module dalr.productionmanager;

import dalr.item;
import dalr.itemset;

import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

class ProductionManager {
	private Deque!(Deque!(int)) prod;

	private Map!(Item, ItemSet) itemSets;

	this() {
		this.prod = new Deque!(Deque!(int));
		this.itemSets = new Map!(Item, ItemSet)(ISRType.HashTable);
	}

	public void makeLRZeroItemSets() {

	}

	private bool doesProductionExists(Deque!(int) toTest) {
		return this.prod.contains(toTest);
	}

	public void insertProduction(Deque!(int) toInsert) {
		assert(toInsert.getSize() > 0, "empty production not allowed");
		if(this.doesProductionExists(toInsert)) {
			throw new Exception(
				format("production %s does allready exist", 
					this.productionToString(toInsert)[0 .. $-1]));
		} else {
			assert(this.prod !is null);
			size_t oldSize = this.prod.getSize();
			this.prod.pushBack(toInsert);
			assert(oldSize+1 == this.prod.getSize());
		}
	}

	public string productionToString(Deque!(int) pro) {
		assert(pro.getSize() > 0);
		StringBuffer!(char) sb = new StringBuffer!(char)(pro.getSize() * 4);
		foreach(idx, it; pro) {
			sb.pushBack(this.productionItemToString(it));
			if(idx == 0) {
				sb.pushBack(" -> ");
			} else {
				sb.pushBack(" ");
			}
		}
		sb.pushBack("\n");
		string ret = sb.getString();
		assert(ret != "");
		return ret;
	}

	public string productionItemToString(const int item) const {
		return conv!(int,string)(item);
	}
	
	public override string toString() {
		assert(this.prod.getSize() > 0);
		StringBuffer!(char) sb = 
			new StringBuffer!(char)(this.prod.getSize()*10);

		foreach(it; this.prod) {
			sb.pushBack(this.productionToString(it));
		}
		return sb.getString();
	}
}

unittest {
	ProductionManager pm = new ProductionManager();
	pm.insertProduction(new Deque!(int)([0,6,2,7]));
	bool thrown = false;
	try {
		pm.insertProduction(new Deque!(int)([0,6,2,7]));
	} catch(Exception e) {
		thrown = true;
	}
	assert(thrown);
	assert("1" == pm.productionItemToString(1));
}
