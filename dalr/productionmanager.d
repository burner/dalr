module dalr.productionmanager;

import dalr.extendeditem;
import dalr.finalitem;
import dalr.grammerparser;
import dalr.item;
import dalr.itemset;
import dalr.mergedreduction;
import dalr.symbolmanager;

import hurt.algo.sorting;
import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.container.set;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.math.mathutil;
import hurt.string.formatter;
import hurt.string.stringbuffer;
import hurt.util.pair;
import hurt.util.slog;

// -1 is $
// -2 is epsilon

class ProductionManager {
	// The grammer
	private Deque!(Deque!(int)) prod;
	private Deque!(Deque!(int)) extGrammer;

	// The extended grammer
	private Deque!(Deque!(ExtendedItem)) extGrammerComplex;
	private Map!(ExtendedItem,bool) extGrammerKind;
	private Deque!(Pair!(Deque!(ExtendedItem),Set!(int))) extGrammerFollow;

	// The first sets for normal and extended grammer
	private Map!(int,Set!(int)) firstNormal;
	private Map!(ExtendedItem,Set!(int)) firstExtended;

	// The follow sets for normal and extended grammer
	private Map!(int,Set!(int)) followNormal;
	private Map!(ExtendedItem,Set!(int)) followExtended;

	// Translation Table
	private Deque!(Deque!(int)) translationTable;

	// Final Table
	private Deque!(Deque!(Deque!(FinalItem))) finalTable;

	// Merged ExtendedRules
	private Map!(size_t, MergedReduction) mergedExtended;

	// The lr0 graph
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


	/************************************************************************* 
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
	

	/************************************************************************* 
	 *  Computation of the translation table
	 *
	 */

	public Deque!(Deque!(int)) getTranslationTable() {
		if(this.translationTable !is null) {
			return this.translationTable;
		} else {
			this.translationTable = this.computeTranslationTable();
			return this.translationTable;
		}
	}

	private Deque!(Deque!(int)) computeTranslationTable() {
		Deque!(Deque!(int)) ret = new Deque!(Deque!(int))(
			this.itemSets.getSize()+1);
		Deque!(int) tmp = new Deque!(int)(this.symbolManager.getSize());

		Pair!(Set!(int),Set!(int)) tAnT = 
			this.symbolManager.getTermAndNonTerm();

		// the first row with term and non-term names
		ISRIterator!(int) tIt = tAnT.first.begin();
		for(; tIt.isValid(); tIt++) {
			tmp.pushBack(*tIt);
		}
		ISRIterator!(int) ntIt = tAnT.second.begin();
		for(; ntIt.isValid(); ntIt++) {
			tmp.pushBack(*ntIt);
		}
		assert(tmp.getSize() == this.symbolManager.getSize()-2);
		foreach(int it; tmp) {
			assert(this.symbolManager.containsSymbol(it));
		}
		ret.pushBack(tmp);

		Deque!(ItemSet) iSet = this.getItemSets();
		foreach(ItemSet it; iSet) {
			Deque!(int) tmp2 = new Deque!(int)(this.symbolManager.getSize()+1);
			tmp2.pushBack(conv!(long,int)(it.getId()));
			foreach(size_t idx, int jt; tmp) {
				tmp2.pushBack(conv!(long,int)(it.getFollowOnInput(jt)));
			}
			ret.pushBack(tmp2);
		}

		return ret;
	}


	/************************************************************************* 
	 *  Computation of the final table
	 *
	 */

	public Deque!(Deque!(Deque!(FinalItem))) getFinalTable() {
		if(this.finalTable !is null) {
			return this.finalTable;
		} else {
			this.finalTable = this.computeFinalTable();
			return this.finalTable;
		}
	}

	private bool isAcceptingFinalState(ItemSet iSet) {
		foreach(Item it; iSet.getItems()) {
			if(it.getProd() == 0 && this.isDotAtEndOfProduction(it)) {
				return true;
			}
		}
		return false;
	}

	/** This maps the followItem of the extended follow set to the
	 *  extendend grammer rules.
	 *
	 *	For example:
	 *		4E5 := 5t4 4z5 ( $, t, z)
	 */
	private void mapExtendedFollowSetToGrammer() {
		this.extGrammerFollow = new Deque!(Pair!(Deque!(ExtendedItem),
			Set!(int)))(this.extGrammerComplex.getSize());

		foreach(size_t idx, Deque!(ExtendedItem) it; this.extGrammerComplex) {
			// copy the grammer rule
			Deque!(ExtendedItem) tmpG = new Deque!(ExtendedItem)(
				it.getSize());
			foreach(size_t jdx, ExtendedItem jt; it) {
				tmpG.pushBack(new ExtendedItem(jt));
			}

			// get the follow set for the first item of the copied rule
			MapItem!(ExtendedItem, Set!(int)) item = this.followExtended.
				find(tmpG[0]);
			if(item is null) {
				continue;
			}

			// copy the items into a new set
			ISRIterator!(int) lt = item.getData().begin();
			Set!(int) tmpS = new Set!(int)();
			for(; lt.isValid(); lt++) {
				tmpS.insert(*lt);
			}

			// pair the copied rule and the set
			this.extGrammerFollow.pushBack(Pair!(Deque!(ExtendedItem),
				Set!(int))(tmpG, tmpS));
		}
	}

	/** This one checks if the two rules have the same item and end on the same
	 *  number.
	 */
	private static bool compareExtended(Deque!(ExtendedItem) a, 
			Deque!(ExtendedItem) b) {
		// if the size is unequal they can't be equal
		if(a.getSize() != b.getSize()) {
			return false;
		}
		foreach(size_t idx, ExtendedItem it; a) {
			// if only one item is unequal they can't be equal
			if(b[idx].getItem() != it.getItem()) {
				return false;
			}
		}
		// compare the last number of the last item
		return a.back().getRight() == b.back().getRight();
	}

	private static MergedReduction getOrCreate(
			Map!(size_t, MergedReduction) map, size_t idx) {
		MapItem!(size_t, MergedReduction) mi = map.find(idx);
		if(mi !is null) {
			return mi.getData();
		} else {
			MergedReduction ret = new MergedReduction(idx);
			map.insert(idx, ret);
			return ret;
		}
	}

	private size_t getProductionIdFromExtended(Deque!(ExtendedItem) extGrm) {
		outer: foreach(size_t idx, Deque!(int) it; this.prod) {
			if(extGrm.getSize() != it.getSize()) {
				continue;
			}
			foreach(size_t jdx, int jt; it) {
				if(jt != extGrm[jdx].getItem()) {
					continue outer;
				}
			}
			return idx;
		}
		assert(false, "grammer rule not found");
	}

	/** Merge rules of the extendend rule follow set.
	 *
	 *  What we gone do is to find rules that start with the same Non-Term
	 *  and end on the same number. This could lead to reduce reduce confilcts.
	 */
	public void reduceExtGrammerFollow() {
		Map!(size_t, MergedReduction) mr = 
			new Map!(size_t,MergedReduction)();
		Set!(size_t) allreadyProcessed = new Set!(size_t)();
		foreach(size_t idx, Pair!(Deque!(ExtendedItem), Set!(int)) it; 
				this.extGrammerFollow) {
			// allready processed extended rules doesn't need to be processed
			if(allreadyProcessed.contains(idx)) {
				continue;
			}

			// store which pairs are to merge
			Deque!(size_t) which = new Deque!(size_t)([idx]);

			// iterator over all following pairs
			Iterator!(Pair!(Deque!(ExtendedItem), Set!(int))) jt = 
				this.extGrammerFollow.iterator(idx+1);
			for(size_t kdx = idx+1; jt.isValid(); jt++, kdx++) {
				// handle if they can be merged
				if(ProductionManager.compareExtended(it.first, (*jt).first)) {
					which.pushBack(kdx);
					allreadyProcessed.insert(kdx);
				}
			}
			
			// join the which deque into the MergedProduction
			MergedReduction tmp = ProductionManager.getOrCreate(mr, 
				it.first.back().getRight());

			// get all merged productions in the which deque and put them into
			// the MergedReduction
			foreach(size_t lt; which) {
				// get the index of the rule in the 
				size_t theRule = this.getProductionIdFromExtended(
					this.extGrammerFollow[lt].first);

				// map the rule for all follow symbols
				ISRIterator!(int) mt = this.extGrammerFollow[lt].second.begin();
				for(; mt.isValid(); mt++) {
					tmp.insert(*mt, theRule, lt);
				}
			}
		}

		this.mergedExtended = mr;
	}

	private Deque!(Deque!(Deque!(FinalItem))) computeFinalTable() {
		Deque!(Deque!(Deque!(FinalItem))) ret = 
			new Deque!(Deque!(Deque!(FinalItem)))(this.itemSets.getSize()+1);
		Deque!(Deque!(FinalItem)) tmp = 
			new Deque!(Deque!(FinalItem))(this.symbolManager.getSize());

		this.mapExtendedFollowSetToGrammer();

		Pair!(Set!(int),Set!(int)) tAnT = 
			this.symbolManager.getTermAndNonTerm();

		// the first row with term and non-term names
		// termianl symbols
		ISRIterator!(int) tIt = tAnT.first.begin();
		for(; tIt.isValid(); tIt++) {
			Deque!(FinalItem) fi = new Deque!(FinalItem)();
			fi.pushBack(FinalItem(Type.Term, *tIt));
			tmp.pushBack(fi);
		}
		// $ should also be placed
		tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.Term, -1)])); 

		// non-termianl symbols
		ISRIterator!(int) ntIt = tAnT.second.begin();
		for(; ntIt.isValid(); ntIt++) {
			Deque!(FinalItem) fi = new Deque!(FinalItem)();
			fi.pushBack(FinalItem(Type.Term, *ntIt));
			tmp.pushBack(fi);
		}

		assert(tmp.getSize() == this.symbolManager.getSize()-1);
		debug {
			foreach(Deque!(FinalItem) it; tmp) {
				foreach(FinalItem jt; it) {
					if(jt.number == -1) {
						continue;
					}
					assert(this.symbolManager.containsSymbol(jt.number));
				}
			}
		}
		ret.pushBack(tmp);

		// make the shift symbols
		Deque!(ItemSet) iSet = this.getItemSets();
		foreach(ItemSet it; iSet) {
			Deque!(Deque!(FinalItem)) tmp2 = 
				new Deque!(Deque!(FinalItem))(this.symbolManager.getSize()+1);

			// what itemset aka row
			tmp2.pushBack(new Deque!(FinalItem)(
				[FinalItem(Type.ItemSet,conv!(long,int)(it.getId()))] ));

			// travel all terms non-term and $
			foreach(size_t idx, Deque!(FinalItem) jt; tmp) {
				// check the $ aka -1 
				if(jt[0].typ == Type.Term && jt[0].number == -1) {
					// check if the itemset is accepting
					if(this.isAcceptingFinalState(it)) {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Accept, -1)] ));
					} else {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Error, -99)] ));	
					}
				// if itemset contains the term mark for shift
				} else if(jt[0].typ == Type.Term && jt[0].number != -1) {
					long follow = it.getFollowOnInput(jt[0].number);
					if(follow == -99) {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Error, -99)] ));
					} else {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Shift, conv!(long,int)(follow))]));
					}
				// if itemset contains the non-term mark for goto
				} else if(jt[0].typ == Type.NonTerm && jt[0].number != -1) {
					long follow = it.getFollowOnInput(jt[0].number);
					if(follow == -99) {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Error, -98)] ));
					} else {
						tmp2.pushBack(new Deque!(FinalItem)(
							[FinalItem(Type.Goto, conv!(long,int)(follow))]));
					}
				}
			}
			ret.pushBack(tmp2);
		}

		// make the reduce stuff into the table
		this.reduceExtGrammerFollow();

		// run over all merged reductions
		// the key is the row
		ISRIterator!(MapItem!(size_t, MergedReduction)) it = 
			this.mergedExtended.begin();
		for(; it.isValid(); it++) {
			Map!(int, Set!(size_t)) follow = (*it).getData().getFollowMap();
			foreach(size_t idx, Deque!(FinalItem) it; tmp) {

			}
		}


		return ret;
	}



	/**************************************************************************
	 *  Computation of item sets
	 *
	 */

	private void createExplicitStartProduction() {
		Deque!(int)	newStart = new Deque!(int)();
		newStart.pushBack(this.symbolManager.insertSymbol("S'", true));
		newStart.pushBack(this.prod[0][0]);
		this.prod.pushFront(newStart);
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
		//this.createExplicitStartProduction();
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

	/************************************************************************* 
	 *  Generic functions for the follow set
	 *
	 */

	private static bool insertFollowItems(T)(Map!(T,Set!(int)) follow,
			T into, Map!(T,Set!(int)) first, T from, bool kind = false) 
				if(is(T == int) || is(T == ExtendedItem)) {

		MapItem!(T,Set!(int)) followMapItem = follow.find(into);
		Set!(int) followSet;
		bool created = false;
		if(followMapItem is null) {
			followSet = new Set!(int)();	
			follow.insert(into, followSet);
			return true;
		} else {
			followSet = followMapItem.getData();
		}
		
		assert(followSet !is null);

		size_t oldSize = followSet.getSize();

		MapItem!(T,Set!(int)) firstMapItem = first.find(from);
		if(firstMapItem !is null) {
			ISRIterator!(int) it = firstMapItem.getData().begin();
			for(; it.isValid(); it++) {
				if(*it != -2) {
					followSet.insert(*it);
				}
			}
		} else {
			static if(is(T == int)) {
				followSet.insert(from);
			} else {
				if(!kind) {
					followSet.insert(from.getItem());
				}
			}
		}

		return oldSize != followSet.getSize();
	}


	/************************************************************************* 
	 *  functions for the extended follow set
	 *
	 */

	private ExtendedItem findFirstItemOfExtendedItem(
			Deque!(Deque!(ExtendedItem)) toFindIn) {
		foreach(size_t idx, Deque!(ExtendedItem) it; toFindIn) {
			assert(it.getSize() > 0);
			if(it[0].getRight() == -1) {
				return it[0];
			}
		}
		assert(false, "well you should have found $ by now");
	}

	private static bool areExtendedItemEpsilon(size_t idx, size_t jdx, 
			Deque!(Deque!(ExtendedItem)) prod) {
		Deque!(ExtendedItem) items = prod[idx];
		foreach(size_t j, ExtendedItem jt; items) {
			if(j < jdx) {
				continue;
			}

			foreach(Deque!(ExtendedItem) it; prod) {
				if(it.front() == jt) {
					return false;
				}
			}
		}
		return true;
	}

	public void makeExtendedFollowSet() {
		assert(this.firstExtended !is null);
		Deque!(Deque!(ExtendedItem)) grammer = 
			new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);

		Map!(ExtendedItem,Set!(int)) followSets = 
			new Map!(ExtendedItem,Set!(int))();

		Set!(int) tmp = new Set!(int)();
		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		tmp.insert(-1); 
		followSets.insert(this.findFirstItemOfExtendedItem(grammer), tmp);

		tmp = null;

		bool hasChanged = false;

		outer: do {
			hasChanged = false;
			foreach(size_t idx, Deque!(ExtendedItem) it; grammer) {
				foreach(size_t jdx, ExtendedItem jt; it) {
					if(jdx == 0) {
						continue;
					} else if(jdx+1 < it.getSize()) { // rule 2
						MapItem!(ExtendedItem,bool) kindItem = 
							this.extGrammerKind.find(jt);
						assert(kindItem !is null);
						bool kind = kindItem.getData();
						if(kind) {
							hasChanged = ProductionManager.insertFollowItems
								!(ExtendedItem)(followSets, jt, 
								this.firstExtended, it[jdx+1]);
							if(hasChanged) {
								continue outer;
							}
						}
					}
				}
			}
			inner:
			foreach(size_t idx, Deque!(ExtendedItem) it; grammer) { // rule 3
				foreach(size_t jdx, ExtendedItem jt; it) {
					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(it.back());
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind && ( (jdx+1 == it.getSize()) || 
							ProductionManager.areExtendedItemEpsilon(idx,
							jdx, grammer))) {
						hasChanged = ProductionManager.insertFollowItems
							!(ExtendedItem)(followSets, it.back, followSets, 
							it[0],true);
						if(hasChanged) {
							goto inner;
						}
					}
				}
			}
		} while(hasChanged);
		this.followExtended = followSets;
	}


	/************************************************************************* 
	 *  functions for the normal follow set
	 *
	 */

	public void makeNormalFollowSet() {
		assert(this.firstNormal !is null);
		Deque!(Deque!(int)) grammer = new Deque!(Deque!(int))(
			this.prod);

		Map!(int,Set!(int)) followSets = new Map!(int,Set!(int))();
		Set!(int) tmp = new Set!(int)();
		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		tmp.insert(-1); 
		followSets.insert(grammer[0][0], tmp);

		tmp = null;

		bool hasChanged = false;

		outer: do {
			hasChanged = false;
			foreach(size_t idx, Deque!(int) it; grammer) {
				foreach(size_t jdx, int jt; it) {
					if(jdx == 0) {
						continue;
					} else if(jdx+1 < it.getSize()) { // rule 2
						if(this.symbolManager.getKind(jt)) {
							hasChanged = ProductionManager.insertFollowItems(
								followSets, jt, this.firstNormal, it[jdx+1]);
							if(hasChanged) {
								continue outer;
							}
						}
					}
				}
			}
			inner:
			foreach(size_t idx, Deque!(int) it; grammer) {
				foreach(size_t jdx, int jt; it) {
					if(this.symbolManager.getKind(it.back)) {
						hasChanged = ProductionManager.insertFollowItems(
							followSets, it.back, followSets, it[0]);
						if(hasChanged) {
							goto inner;
						}
					}
				}
			}
		} while(hasChanged);
		this.followNormal = followSets;
	}


	/************************************************************************* 
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
			Deque!(ExtendedItem) tmpDe = new Deque!(ExtendedItem)();
			ExtendedItem tmp = new ExtendedItem(it[0], it[1], it[2]);
			tmpDe.pushBack(tmp);
			for(size_t jdx = 4; jdx < it.getSize(); jdx++) {
				if(jdx % 2 == 1) {
					tmp = new ExtendedItem(it[jdx-2], it[jdx-1], it[jdx]);
					tmpDe.pushBack(tmp);
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
	

	/************************************************************************* 
	 *  generic for first symbol
	 *
	 */

	private static void insertIntoFirstNormalSet(T)(Map!(T,Set!(int)) first, 
			T sSymbol, Map!(T,Set!(int)) toInsert, T toInsertIdx,
			ProductionManager pm) {

		// copy all first symbols except epsilon
		MapItem!(T, Set!(int)) mi = toInsert.find(toInsertIdx);
		if(mi is null) {
			static if(is(T == int)) {
				assert(false, format("no first set with name for %s present",
					pm.productionItemToString(toInsertIdx)));
			} else {
				assert(false, 
					format("no first set with name for %d%s%d present",
					toInsertIdx.getLeft(), 
					pm.productionItemToString(toInsertIdx.getItem()),
					toInsertIdx.getRight()));
			}
		}
		ISRIterator!(int) it = mi.getData().begin();
		for(; it.isValid(); it++) {
			if(*it != -1) {
				ProductionManager.insertIntoFirstNormal(first, sSymbol, *it);
			}
		}
	}

	private static void insertIntoFirstNormal(T)(Map!(T,Set!(int)) first, 
			T sSymbol, int firstSymbol) {

		MapItem!(T, Set!(int)) f = first.find(sSymbol);
		if(f !is null) {
			f.getData().insert(firstSymbol);
		} else {
			Set!(int) tmp = new Set!(int)();
			tmp.insert(firstSymbol);
			first.insert(sSymbol, tmp);
		}
	}

	private static bool isFirstComplete(T)(T nTerm, 
			Deque!(Deque!(T)) allProd) {
		foreach(Deque!(T) it; allProd) {
			assert(!it.isEmpty(), "empty productions are not allowed");
			if(it[0] == nTerm) {
				return false;
			}
		}
		return true;
	}

	private static bool isFirstOnlyEpislon(T)(Map!(T,Set!(int)) first, T idx, 
			ProductionManager pm) {
		MapItem!(T, Set!(int)) mi = first.find(idx);
		if(mi is null) {
			static if(is(T == int)) {
				assert(false, format("no first set with name for %s present",
					pm.productionItemToString(idx)));
			} else {
				assert(false, 
					format("no first set with name for %d%s%d present",
					idx.getLeft(), pm.productionItemToString(idx.getItem()),
					idx.getRight()));
			}
		}
		if(mi.getData().getSize() > 1) {
			return false;
		} else {
			return mi.getData().contains(-2);
		}
	}


	/************************************************************************* 
	 *  Computation of the extended first symbols (extended grammer rules)
	 *
	 */

	private bool testExtendedItemKind(const ExtendedItem toTest) {
		foreach(Deque!(ExtendedItem) it; this.extGrammerComplex) {
			foreach(size_t idx, ExtendedItem jt; it) {
				if(jt == toTest && idx == 0) {
					return true;
				}
			}
		}
		return false;
	}

	private void constructExtendedKind() {
		this.extGrammerKind = new Map!(ExtendedItem,bool)();
		foreach(Deque!(ExtendedItem) it; this.extGrammerComplex) {
			foreach(size_t idx, ExtendedItem jt; it) {
				if(this.extGrammerKind.contains(jt)) {
					continue;	
				} else {
					this.extGrammerKind.insert(jt, 
						this.testExtendedItemKind(jt));
				}
			}
		}
	}

	public void makeExtendedFirstSet() {
		this.constructExtendedKind();

		Map!(ExtendedItem,Set!(int)) first = new Map!(ExtendedItem,Set!(int));
		Deque!(Deque!(ExtendedItem)) allProd = 
			new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);

		// rule 2
		outer: while(!allProd.isEmpty()) {
			Deque!(ExtendedItem) it = allProd.popFront();
			if(it.getSize() == 1) { // epsilon prod
				// -2 is epsilon
				ProductionManager.insertIntoFirstNormal(first, it[0], -2);

				// first is terminal
			} else if(!this.extGrammerKind.find(it[1]).getData()) { 
				ProductionManager.
					insertIntoFirstNormal!(ExtendedItem)(first, it[0], 
					it[1].getItem());
			} else {
				// rule 3
				Iterator!(ExtendedItem) jt = it.begin();
				jt++;
				for(; jt.isValid(); jt++) {
					if(ProductionManager.isFirstComplete(*jt, allProd) &&
							!ProductionManager.isFirstOnlyEpislon(first, *jt, 
							this)) {

						ProductionManager.insertIntoFirstNormalSet(first, 
							it[0], first, *jt, this);	
						continue outer;
					} else if(ProductionManager.isFirstComplete(*jt, allProd)
							&& ProductionManager.isFirstOnlyEpislon(first, *jt,
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
		this.firstExtended = first;
	}


	/************************************************************************* 
	 *  Computation of normal first symbols below
	 *
	 */

	public void makeNormalFirstSet() {
		Map!(int,Set!(int)) first = new Map!(int,Set!(int));
		Deque!(Deque!(int)) allProd = new Deque!(Deque!(int))(this.prod);

		// rule 2
		outer: while(!allProd.isEmpty()) {
			Deque!(int) it = allProd.popFront();
			if(it.getSize() == 1) { // epsilon prod
				// -2 is epsilon
				ProductionManager.insertIntoFirstNormal(first, it[0], -2);
			} else if(!this.symbolManager.getKind(it[1])) { //first is terminal
				ProductionManager.insertIntoFirstNormal(first, it[0], it[1]);
			} else {
				// rule 3
				Iterator!(int) jt = it.begin();
				jt++;
				for(; jt.isValid(); jt++) {
					if(ProductionManager.isFirstComplete(*jt, allProd) &&
							!ProductionManager.isFirstOnlyEpislon(first, *jt, 
							this)) {

						ProductionManager.insertIntoFirstNormalSet(first, 
							it[0], first, *jt, this);	
						continue outer;
					} else if(ProductionManager.isFirstComplete(*jt, allProd) 
							&& ProductionManager.isFirstOnlyEpislon(first, *jt,
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


	/************************************************************************* 
	 *  To String methodes for productions, items, item, itemsets and this
	 *
	 */

	public string extFollowRulesToString() {
		StringBuffer!(char) tmp = new StringBuffer!(char)(256);
		Deque!(string) ruleString = new Deque!(string)(16);
		Deque!(string) ruleFollow = new Deque!(string)(16);
		size_t maxRuleLen = 0;
		size_t maxFollowLen = 0;
		foreach(size_t idx, Pair!(Deque!(ExtendedItem),Set!(int)) it; 
				this.extGrammerFollow) {

			// the extended rule to string
			ruleString.pushBack(this.extendedGrammerItemRuleToString(it.first));

			// for each follow symbol create string
			tmp.clear();
			tmp.pushBack("{");

			ISRIterator!(int) jt = it.second.begin();
			for(; jt.isValid(); jt++) {
				tmp.pushBack(this.symbolManager.getSymbolName(*jt));	
				tmp.pushBack(' ');
			}
			tmp.popBack();
			tmp.pushBack("}");
			ruleFollow.pushBack(tmp.getString());

			// get the max length
			maxRuleLen = ruleString.back().length > maxRuleLen ? 
				ruleString.back().length : maxRuleLen;
			maxFollowLen = ruleFollow.back().length > maxFollowLen ? 
				ruleFollow.back().length : maxFollowLen;
		}
		assert(ruleString.getSize() == ruleFollow.getSize());

		// make the format rules
		string ruleFor = "%" ~ conv!(size_t,string)(maxRuleLen) ~ "s";
		string ruleFol = "%" ~ conv!(size_t,string)(maxFollowLen) ~ "s";

		// make the return string
		StringBuffer!(char) ret = new StringBuffer!(char)(256);
		foreach(size_t idx, string it; ruleString) {
			ret.pushBack(format("%3d:  ", idx));
			ret.pushBack(format(ruleFor, it));
			ret.popBack();
			ret.pushBack("   ");
			ret.pushBack(format(ruleFol, ruleFollow[idx]));
			ret.pushBack("\n");
		}
		return ret.getString();
	}

	private size_t longestProduction() {
		size_t ret = 0;
		foreach(Deque!(int) it; this.prod) {
			size_t tmp = 0;
			foreach(int jt; it) {
				tmp = tmp + this.symbolManager.getSymbolName(jt).length + 1;
			}
			ret = tmp > ret ? tmp : ret;
		}
		assert(ret > 0);
		return ret;
	}

	public string mergedExtendedToString() {
		StringBuffer!(char) ret = new StringBuffer!(char)(256);
		ISRIterator!(MapItem!(size_t, MergedReduction)) it = 
			this.mergedExtended.begin();
		string followSymbolFormat = "%" 
			~ conv!(size_t,string)(this.symbolManager.longestItem()) ~ "s";

		for(; it.isValid(); it++) {
			ret.pushBack(format("%u\n", (*it).getKey()));
			Map!(int, Set!(size_t)) theFollowMapSet = (*it).getData().
				getFollowMap();

			ISRIterator!(MapItem!(int, Set!(size_t))) jt = theFollowMapSet.
				begin();
			for(; jt.isValid(); jt++) {
				// the input symbol
				ret.pushBack(format(followSymbolFormat, 
					this.symbolManager.getSymbolName((*jt).getKey())));

				// the old extended rules id
				Map!(int, Set!(size_t)) oldRules = (*it).getData().
					getExtFollowMap();
				MapItem!(int, Set!(size_t)) theRule = oldRules.find((*jt).
					getKey());

				ISRIterator!(size_t) mt = theRule.getData().begin();
				for(; mt.isValid(); mt++) {
					ret.pushBack(format(" %d", *mt));
				}
				ret.pushBack("\n");

				// the productions
				ISRIterator!(size_t) kt = (*jt).getData().begin();
				for(; kt.isValid(); kt++) {
					ret.pushBack(format(followSymbolFormat, " "));
					ret.popBack();
					ret.pushBack(this.productionToString(this.prod[*kt]));
					ret.pushBack("\n");
				}
			}
		}
		return ret.getString();
	}

	public string transitionTableToString(T)() {
		static if(is(T == int)) {
			Deque!(Deque!(T)) table = this.getTranslationTable();
		} else {
			Deque!(Deque!(Deque!(T))) table = this.computeFinalTable();
		}
		StringBuffer!(char) ret = new StringBuffer!(char)(
			table.getSize() * table[0].getSize() * 3);

		// For every 10 states the length of the output per item must be
		// increased by one so no two string occupy the same space.
		size_t size = "ItemSet".length;

		static if(is(T == int)) {
			foreach(size_t i, Deque!(T) it; table) {
				foreach(size_t j, T jt; it) {
					if(i == 0 && j > 0 && 
							this.symbolManager.getSymbolName(jt).length 
							> size) {
						size = this.symbolManager.getSymbolName(jt).length;
					} 
				}
			}
		} else { // T == Deque!(FinalItem)
			foreach(size_t i, Deque!(Deque!(T)) it; table) {
				foreach(size_t j, Deque!(T) jt; it) {
					foreach(size_t k, T kt; jt) {
						if(i == 0 && j > 0 && 
								this.symbolManager.getSymbolName(kt.number).
								length > size) {
							size = this.symbolManager.getSymbolName(kt.number).
								length;
						}
					}
				}
			}
		}
		
		// create the table
		static if(is(T == int)) {
			immutable string stringFormat = "%" ~ conv!(size_t,string)(size) 
				~ "s";
			immutable string longFormat = "%" ~ conv!(size_t,string)(size) 
				~ "d";
			immutable string inputFormat = "%" ~ conv!(size_t,string)(size) 
				~ "s";
		} else static if(is(T == FinalItem)) {
			immutable string shiftFormat = "%" ~ conv!(size_t,string)(size-1) 
				~ "ds";
			immutable string reduceFormat = "%" ~ conv!(size_t,string)(size-1) 
				~ "dr";
			immutable string gotFormat = "%" ~ conv!(size_t,string)(size) 
				~ "d";
			immutable string inputFormat = "%" ~ conv!(size_t,string)(size) 
				~ "s";
			immutable string longFormat = "%" ~ conv!(size_t,string)(size) 
				~ "d";
			immutable string acceptFormat = "%" ~ conv!(size_t,string)(size) 
				~ "s";
		}
		ret.pushBack(format(inputFormat, "ItemSet"));
		// their might be multiple items in a single cell (conflicts), this 
		// leads to the extra foreach loop
		StringBuffer!(char) tStrBuf = new StringBuffer!(char)(size);
		static if(is(T == FinalItem)) {
			foreach(size_t i, Deque!(Deque!(T)) it; table) {
				foreach(size_t j, Deque!(T) jt; it) {
					tStrBuf.clear();
					foreach(size_t k, T kt; jt) {
						if(i == 0) {
							ret.pushBack(format(inputFormat, 
								this.symbolManager.getSymbolName(kt.number)));
						} else if(j == 0) {
							ret.pushBack(format(longFormat, kt.number));
						} else if(kt.typ == Type.Reduce) {
							//ret.pushBack(format(shiftFormat, kt.number));
							tStrBuf.pushBack(conv!(int,string)(kt.number));
							tStrBuf.pushBack('r');
						} else if(kt.typ == Type.Shift) {
							tStrBuf.pushBack(conv!(int,string)(kt.number));
							tStrBuf.pushBack('s');
							//ret.pushBack(format(shiftFormat, kt.number));
						} else if(kt.typ == Type.Accept) {
							ret.pushBack(format(acceptFormat, "$"));
						} else {
							if(kt.number == -99 || kt.number == -98) {
								ret.pushBack(format(inputFormat, " "));
							} else {
								ret.pushBack(format(longFormat, kt.number));
							}
						}
					}
					if(tStrBuf.getSize() > 0) {
						ret.pushBack(format(inputFormat, tStrBuf.getString));
					}
				}
				ret.pushBack("\n");
			}
		} else static if(is(T == int)) {
			foreach(size_t i, Deque!(T) it; table) {
				foreach(size_t j, T jt; it) {
					if(i == 0) {
						ret.pushBack(format(stringFormat, 
							this.symbolManager.getSymbolName(jt)));
					} else {
						if(jt != -99) {
							ret.pushBack(format(longFormat, jt));
						} else {
							ret.pushBack(format(stringFormat, " "));
						}
					}
				}
				ret.pushBack("\n");
			}
		}
		ret.pushBack("\n");
		return ret.getString();
	}

	public string extendedFirstSetToString() {
		return this.extendedTSetToString!("First")(this.firstExtended);
	}

	public string extendedFollowSetToString() {
		return this.extendedTSetToString!("Follow")(this.followExtended);
	}

	private string extendedTSetToString(string type)(Map!(ExtendedItem, 
			Set!(int)) map) {
		ISRIterator!(MapItem!(ExtendedItem, Set!(int))) it = map.begin();
		StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
		for(size_t idx = 0; it.isValid(); idx++, it++) {
			sb.pushBack(type);
			sb.pushBack(format("(%s%s%s) = {", 
				(*it).getKey().getLeft() == -1 ? "$" : 
				conv!(int,string)((*it).getKey().getLeft()),
				this.productionItemToString((*it).getKey().getItem()), 
				(*it).getKey().getRight() == -1 ? "$" : 
				conv!(int,string)((*it).getKey().getRight())));
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

	public string normalFollowSetToString() {
		return this.normalFollowSetToString(this.followNormal);
	}

	private string normalFollowSetToString(Map!(int, Set!(int)) map) {
		ISRIterator!(MapItem!(int, Set!(int))) it = map.begin();
		StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
		for(size_t idx = 0; it.isValid(); it++) {
			sb.pushBack("Follow(");
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

	public string extendedGrammerItemsToString() {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);
		foreach(size_t idx, Deque!(ExtendedItem) it; this.extGrammerComplex) {
			ret.pushBack(format("%2d: ", idx));
			ret.pushBack(this.extendedGrammerItemRuleToString(it));
			ret.pushBack("\n");
		}
		return ret.getString();
	}

	public string extendedGrammerItemRuleToString(Deque!(ExtendedItem) pro) {
		StringBuffer!(char) ret = new StringBuffer!(char)(pro.getSize() * 4);
		foreach(idx, it; pro) {
			if(idx == 1) {
				ret.pushBack("=> ");
			}
			ret.pushBack(it.getLeft() != -1 ? conv!(int,string)(it.getLeft())
				: "$");
			ret.pushBack(this.symbolManager.getSymbolName(it.getItem()));
			ret.pushBack(it.getRight() != - 1 ? 
				conv!(int,string)(it.getRight()) : 
				"$");
			ret.pushBack(" ");
		}
		return ret.getString();
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
