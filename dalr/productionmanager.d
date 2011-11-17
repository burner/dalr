module dalr.productionmanager;

import dalr.item;
import dalr.itemset;
import dalr.symbolmanager;

import hurt.conv.conv;
import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.container.set;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

class ProductionManager {
	private Deque!(Deque!(int)) prod;

	private Set!(ItemSet) itemSets;
	private SymbolManager symbolManager;

	this() {
		this.prod = new Deque!(Deque!(int));
		this.itemSets = new Set!(ItemSet)();
	}

	this(SymbolManager symbolManager) {
		this();
		this.symbolManager = symbolManager;
	}

	public ItemSet getFirstItemSet() {
		return new ItemSet(new Deque!(dalr.item.Item)(
			[new dalr.item.Item(0, 1)]));
	}

	private Deque!(int) getProduction(const size_t idx) {
		if(idx >= this.prod.getSize()) {
			throw new Exception(format("index %d out of this.prod bound(%d)",
				idx, this.prod.getSize()));
		} else {
			return this.prod[idx];
		}
	}

	public Deque!(Deque!(int)) getProductions() {
		return this.prod;
	}

	private int getSymbolFromProduction(const Item item) {
		return this.getSymbolFromProduction(item.getProd(), 
			item.getDotPosition());
	}

	public Deque!(ItemSet) getItemSets() {
		Deque!(ItemSet) ret = new Deque!(ItemSet)(this.itemSets.getSize());
		ISRIterator!(ItemSet) it = this.itemSets.begin();
		for(size_t idx = 0; it.isValid(); it++, idx++) {
			if((*it).getId() == -1) {
				(*it).setId(conv!(size_t,long)(idx));
			}
			assert((*it).getId() != -1);
			ret.pushBack(*it);
		}
		return ret;
	}

	private int getSymbolFromProduction(const size_t prodIdx, 
			const size_t symIdx) {
		Deque!(int) pro = this.getProduction(prodIdx);
		if(symIdx >= pro.getSize()) {
			throw new Exception(format("index %d out of pro bound(%d)",
				symIdx, pro.getSize()));
		} else {
			return pro[symIdx];
		}
	}

	Deque!(size_t) getProdByStartSymbol(const int startSymbol) {
		Deque!(size_t) ret = new Deque!(size_t)();
		foreach(size_t idx, Deque!(int) it; this.prod) {
			if(it[0] == startSymbol) {
				ret.pushBack(idx);
			}
		}
		return ret;
	}

	private bool isDotAtEndOfProduction(const Item item) {
		Deque!(int) pro = this.getProduction(item.getProd());
		return pro.getSize() == item.getDotPosition();
	}
	
	private bool doesProductionExists(Deque!(int) toTest) {
		return this.prod.contains(toTest);
	}

	private void completeItemSet(ItemSet iSet) {
		Deque!(Item) de = iSet.getItems();
		Deque!(Item) stack = new Deque!(Item)(de);
		while(!stack.isEmpty()) {
			Item item = stack.popFront();
			if(this.isDotAtEndOfProduction(item))
				continue;
				
			int next = this.getSymbolFromProduction(item);

			// now check if it is non terminal, should that be the case insert
			// all productions not yet contained in de with a starting symbol 
			// simular to next
			if(this.symbolManager.getKind(next)) {
				Deque!(size_t) follow = this.getProdByStartSymbol(next);

				// for all matching productions, check if they exists and if
				// not insert it into the itemset and the stack
				foreach(size_t it; follow) {
					Item toAdd = new Item(it, 1);
					if(!de.contains(toAdd)) {
						de.pushBack(toAdd);
						stack.pushBack(toAdd);
					}
				}
			} 
		}
	}

	private void fillFollowSet(ItemSet iSet) {
		Map!(int, ItemSet) follow = new Map!(int, ItemSet)();
		assert(iSet !is null);
		Deque!(Item) iSetItems = iSet.getItems();
		assert(iSetItems !is null);
		foreach(size_t idx, Item it; iSetItems) {
			if(this.isDotAtEndOfProduction(it))
				continue;
				
			int followSym = this.getSymbolFromProduction(it);	
			MapItem!(int, ItemSet) followItem = follow.find(followSym);
			if(followItem !is null) {
				followItem.getData().addItem(it.incrementItem());
			} else {
				ItemSet tmp = new ItemSet(
					new Deque!(Item)([it.incrementItem()]) );
				follow.insert(followSym, tmp);
			}
		}

		// make the itemsets complete
		ISRIterator!(MapItem!(int, ItemSet)) it = follow.begin();
		for(; it.isValid(); it++) {
			this.completeItemSet((*it).getData());	
		}

		// replace newly created itemsets with itemsets that have
		// been allready created
		it = follow.begin();
		for(; it.isValid(); it++) {
			ISRIterator!(ItemSet) found = this.itemSets.find((*it).getData());
			if(found.isValid()) {
				(*it).setData(*found);	
			} else {
				this.itemSets.insert((*it).getData());
			}
		}
		iSet.setFollow(follow);
	}

	private void insertItemsToProcess(Set!(ItemSet) processed, 
			Deque!(ItemSet) stack, Map!(int, ItemSet) toProcess) {
		ISRIterator!(MapItem!(int,ItemSet)) it = toProcess.begin();
		for(; it.isValid(); it++) {
			if(processed.contains((*it).getData())) {
				continue;
			} else {
				stack.pushBack((*it).getData());
			}
		}
	}

	public void makeLRZeroItemSets() {
		ItemSet iSet = this.getFirstItemSet();
		this.completeItemSet(iSet);
		this.fillFollowSet(iSet);
		this.itemSets.insert(iSet);
		Set!(ItemSet) processed = new Set!(ItemSet)();
		Deque!(ItemSet) stack = new Deque!(ItemSet)();
		this.insertItemsToProcess(processed, stack, iSet.getFollowSet());
		while(!stack.isEmpty()) {
			iSet = stack.popFront();
			//printf("%s", this.itemsetToString(iSet));
			this.completeItemSet(iSet);
			this.fillFollowSet(iSet);
			processed.insert(iSet);
			this.insertItemsToProcess(processed, stack, iSet.getFollowSet());
		}
	}

	public void makeExtendedGrammer() {

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

	public string productionItemToString(const int item) {
		if(this.symbolManager is null) {
			return conv!(int,string)(item);
		} else {
			return this.symbolManager.getSymbolName(item);
		}
	}

	private string itemToString(const Item item) {
		Deque!(int) de = this.getProduction(item.getProd());	
		StringBuffer!(char) ret = new StringBuffer!(char)(de.getSize()*4);
		foreach(size_t idx, int it; de) {
			if(idx == 0) {
				ret.pushBack(this.productionItemToString(it));
				ret.pushBack(" -> ");
				continue;
			}
			if(idx == item.getDotPosition()) {
				ret.pushBack(".");
				ret.pushBack(this.productionItemToString(it));
			} else {
				ret.pushBack(this.productionItemToString(it));
			}
			ret.pushBack(" ");
		}
		ret.popBack();
		if(de.getSize() == item.getDotPosition()) {
			ret.pushBack(".");
		}
		return ret.getString();
	}

	private string itemsetToString(ItemSet iSet) {
		StringBuffer!(char) sb = new StringBuffer!(char)();
		foreach(Item it; iSet.getItems()) {
			sb.pushBack(this.itemToString(it));
			sb.pushBack('\n');
		}
		sb.pushBack('\n');
		return sb.getString();
	}

	public string itemsetsToString() {
		StringBuffer!(char) sb = 
			new StringBuffer!(char)(this.itemSets.getSize() * 10);

		ISRIterator!(ItemSet) it = this.itemSets.begin();
		for(size_t idx = 0; it.isValid(); idx++, it++) {
			sb.pushBack(conv!(ulong,string)(idx));
			sb.pushBack('\n');
			sb.pushBack(this.itemsetToString(*it));
		}
		return sb.getString();
	}
	
	public override string toString() {
		assert(this.prod.getSize() > 0);
		StringBuffer!(char) sb = 
			new StringBuffer!(char)(this.prod.getSize()*10);

		foreach(Deque!(int) it; this.prod) {
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
