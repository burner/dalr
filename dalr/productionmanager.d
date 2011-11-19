module dalr.productionmanager;

import dalr.extendeditem;
import dalr.item;
import dalr.itemset;
import dalr.symbolmanager;
import dalr.grammerparser;

import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.container.set;
import hurt.conv.conv;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.string.formatter;
import hurt.string.stringbuffer;

class ProductionManager {
	private Deque!(Deque!(int)) prod;
	private Deque!(Deque!(int)) extGrammer;
	private Deque!(Deque!(ExtendedItem)) extGrammerComplex;

	private Map!(int,Set!(int)) firstNormal;
	private Map!(int,Set!(int)) firstExtended;

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


	/************************************************************************** 
	 *  Getter
	 *
	 */

	public Map!(int,Set!(int)) getFirstNormal() {
		return this.firstNormal;
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

	public void finalizeItemSet() {
		ISRIterator!(ItemSet) it = this.itemSets.begin();
		for(size_t idx = 0; it.isValid(); it++, idx++) {
			if((*it).getId() == -1) {
				(*it).setId(conv!(size_t,long)(idx));
			}
			assert((*it).getId() != -1);
		}
	}

	public Deque!(ItemSet) getItemSets() {
		Deque!(ItemSet) ret = new Deque!(ItemSet)(this.itemSets.getSize());
		ISRIterator!(ItemSet) it = this.itemSets.begin();
		for(size_t idx = 0; it.isValid(); it++, idx++) {
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


	/************************************************************************** 
	 *  Computation of item sets
	 *
	 */

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
		this.finalizeItemSet();
	}


	/************************************************************************** 
	 *  Computation of the extended Grammer rules
	 *
	 */

	public void makeExtendedGrammer() {
		// This looks ugly because itemset numbers as well
		// as items are mixed and both are encoded as ints.
		// Every even indexed item in a deque!(int) is a symbol.
		Deque!(Deque!(int)) extendedGrammer = new Deque!(Deque!(int))(
			this.itemSets.getSize()*2);

		ISRIterator!(ItemSet) iSetIt = this.itemSets.begin();
		outer: for(; iSetIt.isValid(); iSetIt++) {
			foreach(size_t idx, Item it; (*iSetIt).getItems()) {
				if(it.getDotPosition() != 1) {
					continue;
				} else {
					Deque!(int) p = this.getProduction(it.getProd());
					Deque!(int) extProd = new Deque!(int)();
					size_t s = (*iSetIt).makeExtendedProduction(1, p, extProd);
					(*iSetIt).makeFrontOfExtended(p[0], extProd, false);
					extendedGrammer.pushBack(extProd);
				}
			}
		}

		this.extGrammer = extendedGrammer;
		this.extGrammerComplex = this.constructExtendedItem(extendedGrammer);
	}

	private Deque!(Deque!(ExtendedItem)) constructExtendedItem(
			Deque!(Deque!(int)) ext) {

		Deque!(Deque!(ExtendedItem)) ret = 
			new Deque!(Deque!(ExtendedItem))(ext.getSize());

		foreach(size_t idx, Deque!(int) it; ext) {
			Deque!(ExtendedItem) tmpDe = new Deque!(ExtendedItem)(it.getSize());
			ExtendedItem tmp = new ExtendedItem();
			foreach(size_t jdx, int jt; it) {
				if(jdx == 0) {
					tmp.setLeft(jt);
				} else if(jdx == 1) {
					tmp.setItem(jt);
				} else if(jdx == 2) {
					tmp.setRight(jt);
					tmpDe.pushBack(tmp);
				} else {
					if(jdx / 3 == 0) {
						tmp = new ExtendedItem(it[jdx-2], it[jdx-1], it[jdx]);	
						tmpDe.pushBack(tmp);
					}
				}
			}
			ret.pushBack(tmpDe);
		}
		return ret;
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


	/************************************************************************** 
	 *  Computation of normal first symbols below
	 *
	 */

	private static void insertIntoFirstNormal(Map!(int,Set!(int)) first, 
			int sSymbol, Map!(int,Set!(int)) toInsert, int toInsertIdx,
			ProductionManager pm) {

		// copy all first symbols except epsilon
		MapItem!(int, Set!(int)) mi = toInsert.find(toInsertIdx);
		if(mi is null) {
			assert(false, format("no first set with name for %s present",
				pm.productionItemToString(toInsertIdx)));
		}
		ISRIterator!(int) it = mi.getData().begin();
		for(; it.isValid(); it++) {
			if(*it != -1) {
				ProductionManager.insertIntoFirstNormal(first, sSymbol, *it);
			}
		}
	}

	private static void insertIntoFirstNormal(Map!(int,Set!(int)) first, 
			int sSymbol, int firstSymbol) {

		MapItem!(int, Set!(int)) f = first.find(sSymbol);
		if(f !is null) {
			f.getData().insert(firstSymbol);
		} else {
			Set!(int) tmp = new Set!(int)();
			tmp.insert(firstSymbol);
			first.insert(sSymbol, tmp);
		}
	}

	private static bool isFirstComplete(int nTerm, 
			Deque!(Deque!(int)) allProd) {
		foreach(Deque!(int) it; allProd) {
			assert(!it.isEmpty(), "empty productions are not allowed");
			if(it[0] == nTerm) {
				return false;
			}
		}
		return true;
	}

	private static bool isFirstOnlyEpislon(Map!(int,Set!(int)) first, int idx,
			ProductionManager pm) {
		MapItem!(int, Set!(int)) mi = first.find(idx);
		if(mi is null) {
			assert(false, format("no first set with name for %s present",
				pm.productionItemToString(idx)));
		}
		if(mi.getData().getSize() > 1) {
			return false;
		} else {
			return mi.getData().contains(-2);
		}
	}

	public void makeNormalFirstSet() {
		Map!(int,Set!(int)) first = new Map!(int,Set!(int));
		Deque!(Deque!(int)) allProd = new Deque!(Deque!(int))(this.prod);

		// rule 2
		outer: while(!allProd.isEmpty()) {
			Deque!(int) it = allProd.popFront();
			if(it.getSize() == 1) { // epsilon prod
				// -2 is epsilon
				ProductionManager.insertIntoFirstNormal(first, it[0], -2);
			} else if(!this.symbolManager.getKind(it[1])) { // fist is terminal
				ProductionManager.insertIntoFirstNormal(first, it[0], it[1]);
			} else {
				Iterator!(int) jt = it.begin();
				jt++;
				for(; jt.isValid(); jt++) {
					if(ProductionManager.isFirstComplete(*jt, allProd) &&
							!ProductionManager.isFirstOnlyEpislon(first, *jt, 
							this)) {

						ProductionManager.insertIntoFirstNormal(first, it[0],
							first, *jt, this);	
						continue outer;
					} else if(ProductionManager.isFirstComplete(*jt, allProd) &&
							ProductionManager.isFirstOnlyEpislon(first, *jt, 
							this)) {
						continue;
					} else if(!ProductionManager.isFirstComplete(*jt, 
							allProd)) {
						allProd.pushBack(it);	
						continue outer;
					} else {
						assert(false, "this should be unreachable");
					}
				}
				ProductionManager.insertIntoFirstNormal(first, it[0], -2);
			}
		}
		this.firstNormal = first;
	}


	/************************************************************************** 
	 *  To String methodes for productions, items, item, itemsets and this
	 *
	 */

	public string normalFirstSetToString() {
		return this.normalFirstSetToString(this.firstNormal);
	}

	private string normalFirstSetToString(Map!(int, Set!(int)) map) {
		ISRIterator!(MapItem!(int, Set!(int))) it = map.begin();
		StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
		for(size_t idx = 0; it.isValid(); it++) {
			sb.pushBack("First(");
			sb.pushBack(this.productionItemToString((*it).getKey()));
			sb.pushBack(") = {");
			ISRIterator!(int) jt = (*it).getData().begin();
			int cnt = 0;
			for(; jt.isValid(); jt++) {
				cnt++;
				sb.pushBack(this.productionItemToString(*jt));
				sb.pushBack(", ");
			}
			if(cnt > 0) {
				sb.popBack();
				sb.popBack();
			}
			sb.pushBack("}\n");
		}
		return sb.getString();
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
		if(item == -1) {
			return "$";
		} else if(this.symbolManager is null) {
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

	public string extendedGrammerToString() {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);
		foreach(it; this.extGrammer) {
			ret.pushBack(this.extendedGrammerRuleToString(it));
			ret.pushBack("\n");
		}
		return ret.getString();
	}

	public string extendedGrammerRuleToString(Deque!(int) pro) {
		StringBuffer!(char) ret = new StringBuffer!(char)(pro.getSize() * 4);
		for(size_t idx = 0; idx < 3; idx++) {
			if(idx % 2 == 0) {
				if(pro[idx] == -1) 
					ret.pushBack('$');
				else
					ret.pushBack(conv!(int,string)(pro[idx]));
			} else {
				ret.pushBack(this.symbolManager.getSymbolName(pro[idx]));
			}
		}
		ret.pushBack(" => ");
		for(size_t idx = 3; idx < pro.getSize(); idx++) {
			if(idx % 2 == 1) {
				if(pro[idx] == -1) 
					ret.pushBack('$');
				else
					ret.pushBack(conv!(int,string)(pro[idx]));
			} else {
				ret.pushBack(this.symbolManager.getSymbolName(pro[idx]));
			}
		}
		return ret.getString();
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

unittest {
	SymbolManager sm = new SymbolManager();
	GrammerParser gp = new GrammerParser(sm);
	ProductionManager pm = new ProductionManager(sm);
	pm.insertProduction(gp.processProduction("S := A B C"));
	pm.insertProduction(gp.processProduction("A :="));
	pm.insertProduction(gp.processProduction("B :="));
	pm.insertProduction(gp.processProduction("C :="));
	pm.makeNormalFirstSet();
	Map!(int,Set!(int)) map = pm.getFirstNormal();
	assert(map !is null);
	MapItem!(int,Set!(int)) mi = map.find(sm.getSymbolId("S"));
	assert(mi !is null);
	assert(mi.getData().contains(-2));

	sm = new SymbolManager();
	gp = new GrammerParser(sm);
	pm = new ProductionManager(sm);
	pm.insertProduction(gp.processProduction("S := A B C"));
	pm.insertProduction(gp.processProduction("A :="));
	pm.insertProduction(gp.processProduction("B := a"));
	pm.insertProduction(gp.processProduction("C :="));
	pm.makeLRZeroItemSets();
	pm.makeExtendedGrammer();
	//print(pm.extendedGrammerToString());
	pm.makeNormalFirstSet();
	map = null;
	map = pm.getFirstNormal();
	mi = null;
	mi = map.find(sm.getSymbolId("S"));
	assert(mi !is null);
	assert(mi.getData().contains(sm.getSymbolId("a")));
	mi = null;
	mi = map.find(sm.getSymbolId("B"));
	assert(mi !is null);
	assert(mi.getData().contains(sm.getSymbolId("a")));

	sm = new SymbolManager();
	gp = new GrammerParser(sm);
	pm = new ProductionManager(sm);
	pm.insertProduction(gp.processProduction("S := A B C"));
	pm.insertProduction(gp.processProduction("A :="));
	pm.insertProduction(gp.processProduction("B :="));
	pm.insertProduction(gp.processProduction("C := a"));
	pm.makeLRZeroItemSets();
	pm.makeExtendedGrammer();
	//print(pm.extendedGrammerToString());
	pm.makeNormalFirstSet();
	map = null;
	map = pm.getFirstNormal();
	mi = null;
	mi = map.find(sm.getSymbolId("S"));
	assert(mi !is null);
	assert(mi.getData().contains(sm.getSymbolId("a")));
	mi = null;
	mi = map.find(sm.getSymbolId("C"));
	assert(mi !is null);
	assert(mi.getData().contains(sm.getSymbolId("a")));
}
