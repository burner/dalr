module dalr.productionmanager;

import dalr.item;
import dalr.itemset;
import dalr.symbolmanager;

import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
//import hurt.container.multimap;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

class ProductionManager {
	private Deque!(Deque!(int)) prod;

	private Map!(ItemSet, ItemSet) itemSets;
	private SymbolManager symbolManager;

	this() {
		this.prod = new Deque!(Deque!(int));
		this.itemSets = new Map!(ItemSet, ItemSet)();
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

	private int getSymbolFromProduction(const Item item) {
		return this.getSymbolFromProduction(item.getProd(), item.getDotPosition());
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

	/** This creates a multimap containing all nonterminal symbols with the
	 * relevant items next in the itemset. Or put differently, creating the 
	 * left side of the productions to a given kernel.
	 *
	 * Example:
	 * 	S -> E .H
	 * 	S -> g .i
	 * 	S -> j .H
	 *  L -> I .P
	 *
	 * will lead to
	 *  H := S -> E .H, S -> j .H
	 *  P := L -> I .P
	 *
	private MultiMap!(int,dalr.item.Item) getFollowSymbols(ItemSet set) {
		MultiMap!(int,dalr.item.Item) ret = new MultiMap!(int,dalr.item.Item)();
		Deque!(dalr.item.Item) items = set.getItems();
		foreach(idx, it; items) {
			int followSymbol = this.getSymbolFromProduction(it.getProd(),
				it.getDotPosition());
			if(ret.contains(followSymbol)) {
				ret.insert(followSymbol, it);
				continue;
			} else if(this.symbolManager.getKind(followSymbol)) {
				ret.insert(followSymbol, it);
			}
		}
		return ret;
	}*/

	Deque!(size_t) getProdByStartSymbol(const int startSymbol) {
		Deque!(size_t) ret = new Deque!(size_t)();
		foreach(size_t idx, Deque!(int) it; this.prod) {
			if(it[0] == startSymbol) {
				ret.pushBack(idx);
			}
		}
		return ret;
	}

	private void completeItemSet(ItemSet iSet) {
		Deque!(Item) de = iSet.getItems();
		Deque!(Item) stack = new Deque!(Item)(de);
		while(!stack.isEmpty()) {
			Item item = stack.popFront();
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

	public void makeLRZeroItemSets() {
		ItemSet iSet = this.getFirstItemSet();
		this.completeItemSet(iSet);
		foreach(Item it; iSet.getItems()) {
			print(this.productionToString(this.prod[it.getProd()]));
		}

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
