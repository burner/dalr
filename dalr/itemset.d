module dalr.itemset;

import dalr.item;

import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;

// a set of items aka lr(0) set
class ItemSet {
	private Map!(int, ItemSet) followSets;
	private Deque!(Item) items;

	this(Item kernel) {
		this.items = new Deque!(Item)();
		this.followSets = new Map!(int,ItemSet)(ISRType.HashTable);
		this.items.pushBack(kernel);
	}
}
