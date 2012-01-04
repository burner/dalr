module dalr.productionmanager;

import dalr.extendeditem;
import dalr.finalitem;
import dalr.grammerparser;
import dalr.item;
import dalr.itemset;
import dalr.mergedreduction;
import dalr.symbolmanager;
import dalr.tostring;

import hurt.algo.sorting;
import hurt.container.deque;
import hurt.container.isr;
import hurt.container.map;
import hurt.container.mapset;
import hurt.container.set;
import hurt.container.trie;
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
	private Deque!(ItemSet) itemSets;

	private SymbolManager symbolManager;

	this() {
		this.prod = new Deque!(Deque!(int));
		this.itemSets = new Deque!(ItemSet)();
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

	public Deque!(int) getProduction(const size_t idx) {
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
		Iterator!(ItemSet) it = this.itemSets.begin();
		for(size_t idx = 0; it.isValid(); it++, idx++) {
			if((*it).getId() == -1) {
				(*it).setId(conv!(size_t,long)(idx));
			}
			assert((*it).getId() != -1);
		}
	}

	public Deque!(ItemSet) getItemSets() {
		Deque!(ItemSet) ret = new Deque!(ItemSet)(this.itemSets.getSize());
		Iterator!(ItemSet) it = this.itemSets.begin();
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
				ISRIterator!(int) mt = this.extGrammerFollow[lt].second.
					begin();
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

		// the first row
		Deque!(Deque!(FinalItem)) tmp = 
			new Deque!(Deque!(FinalItem))(this.symbolManager.getSize());

		// -1 and ItemSet marks the top left corner as the ItemSet string
		tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.ItemSet, -1)]));

		this.mapExtendedFollowSetToGrammer();

		Pair!(Set!(int),Set!(int)) tAnT = 
			this.symbolManager.getTermAndNonTerm();

		// the first row with term and non-term names
		// termianl symbols
		ISRIterator!(int) tIt = tAnT.first.begin();
		for(; tIt.isValid(); tIt++) {
			assert(this.symbolManager.getKind(*tIt) == false);
			Deque!(FinalItem) fi = new Deque!(FinalItem)();
			fi.pushBack(FinalItem(Type.Term, *tIt));
			tmp.pushBack(fi);
		}
		// $ should also be placed
		tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.Term, -1)])); 

		// non-termianl symbols
		ISRIterator!(int) ntIt = tAnT.second.begin();
		for(; ntIt.isValid(); ntIt++) {
			assert(this.symbolManager.getKind(*ntIt) == true);
			Deque!(FinalItem) fi = new Deque!(FinalItem)();
			fi.pushBack(FinalItem(Type.NonTerm, *ntIt));
			tmp.pushBack(fi);
		}

		assert(tmp.getSize() == this.symbolManager.getSize());
		debug { // check if the symbols got copied right
			foreach(Deque!(FinalItem) it; tmp) {
				foreach(FinalItem jt; it) {
					assert(this.symbolManager.containsSymbol(jt.number));
					if(jt.typ == Type.Term) {
						assert(!this.symbolManager.getKind(jt.number));
					} else if(jt.typ == Type.NonTerm) {
						assert(this.symbolManager.getKind(jt.number));
					}
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
		debug { // make sure the itemset numbers are sorted
			foreach(size_t idx, Deque!(Deque!(FinalItem)) it; ret) {
				if(idx > 2) {
					if(it.front().front().typ == Type.ItemSet) {
						assert(ret[idx-1].front().front().number < 
							it.front().front().number, format("%u %u",
							ret[idx-1].front().front().number < 
							it.front().front().number));
					}
				}
			}
			size_t expSize = 0;
			Iterator!(Deque!(Deque!(FinalItem))) ht = ret.iterator(1);
			for(; ht.isValid(); ht++) {
				if(expSize == 0) {
					expSize = (*ht).getSize();
				} else {
					assert(expSize == (*ht).getSize(), format("%u %u", expSize,
						(*ht).getSize()));
				}

			}
		}

		// make the reduce stuff into the table
		this.reduceExtGrammerFollow();

		// run over all merged reductions
		// the key is the row
		ISRIterator!(MapItem!(size_t, MergedReduction)) it = 
			this.mergedExtended.begin();
		for(; it.isValid(); it++) {
			// the row
			assert((*it).getKey() == (*it).getData().getFinalSet());
			//Deque!(Deque!(FinalItem)) theRow = ret[(*it).getKey()];
			Deque!(Deque!(FinalItem)) theRow = null;
			int found = 0;
			Iterator!(Deque!(Deque!(FinalItem))) ot = ret.iterator(1);
			//foreach(Deque!(Deque!(FinalItem)) ot; ret) {
			for(; ot.isValid(); ot++) {
				if((*ot).front().front().number == (*it).getKey()) {
					theRow = *ot;
					found++;
					continue;
				}
			}
			assert(found == 1, format("found %d %d", found, (*it).getKey()));
			assert(theRow !is null);

			Map!(int, Set!(size_t)) follow = (*it).getData().getFollowMap();
			foreach(size_t idx, Deque!(FinalItem) tt; tmp) {
				assert(tt.getSize() == 1);
				if(tt[0].typ == Type.Term) {
					// get the follow set
					MapItem!(int,Set!(size_t)) s = follow.find(tt[0].number);
					if(s is null) {
						continue;
					} else {
						// if the follow set exists add all items to the deque 
						// entry
						ISRIterator!(size_t) rt = s.getData().begin();
						for(; rt.isValid(); rt++) {
							theRow[idx].pushBack(FinalItem(Type.Reduce, 
								conv!(size_t,int)(*rt)));
							/*log("%s %u %u", 
								this.symbolManager.getSymbolName(tt[0].number)
								, *rt, idx+1);*/
						}

					}
				}
			}
		}
		debug {
			if(ret.getSize() > 1) {
				assert(ret[0].getSize() == ret[1].getSize(),
					format("%u %u", ret[0].getSize(), ret[1].getSize()));
			}
			Iterator!(Deque!(Deque!(FinalItem))) gt = ret.iterator(1);
			for(;gt.isValid(); gt++) {
				foreach(size_t vdx, Deque!(FinalItem) vt; *gt) {
					if(vdx == 0) {
						assert(vt.getSize() == 1);
						assert(vt[0].typ == Type.ItemSet);
					} else {
						assert(vt.getSize() > 0);
						Type columnType = tmp[vdx-1][0].typ;
						foreach(FinalItem wt; vt) {
							if(columnType == Type.Term) {
								assert(wt.typ == Type.Shift ||
									wt.typ == Type.Reduce ||
									wt.typ == Type.Accept ||
									wt.typ == Type.Error,
									format("%s %s", typeToString(columnType),
									typeToString(wt.typ)));
							} else if(columnType == Type.NonTerm) {
								assert(wt.typ == Type.Goto ||
									wt.typ == Type.Error,
									format("%s %s", typeToString(columnType),
									typeToString(wt.typ)));
							}
						}
					}
				}
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
		assert(iSet !is null);
		Deque!(Item) de = iSet.getItems();
		Deque!(Item) stack = new Deque!(Item)(de);
		while(!stack.isEmpty()) {
			Item item = stack.popFront();
			assert(item !is null);
			if(this.isDotAtEndOfProduction(item))
				continue;
				
			int next = this.getSymbolFromProduction(item);

			// now check if it is non terminal, should that be the case insert
			// all productions not yet contained in de with a starting symbol 
			// simular to next
			if(this.symbolManager.getKind(next)) {
				Deque!(size_t) follow = this.getProdByStartSymbol(next);
				assert(follow !is null);

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
		sortDeque!(Item)(de, function(in Item a, in Item b) {
			return a.toHash() < b.toHash(); });
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
			Iterator!(ItemSet) found = this.itemSets.findIt((*it).getData());
			if(found.isValid()) {
				(*it).setData(*found);	
			} else {
				this.itemSets.pushBack((*it).getData());
			}
		}
		iSet.setFollow(follow);
	}

	private void insertItemsToProcess(Deque!(ItemSet) processed, 
			Trie!(ItemSet,Item) processedTrie,
			Deque!(ItemSet) stack, Map!(int, ItemSet) toProcess) {
		ISRIterator!(MapItem!(int,ItemSet)) it = toProcess.begin();
		for(; it.isValid(); it++) {
			if(processed.contains((*it).getData())) {
			//if(processedTrie.contains((*it).getData().getItems())) {
				assert(processedTrie.contains((*it).getData().getItems()));
				continue;
			} else {
				assert(!processedTrie.contains((*it).getData().getItems()));
				assert((*it).getData() !is null);
				stack.pushBack((*it).getData());
				assert(stack.back() !is null);
			}
		}
	}

	public void makeLRZeroItemSets() {
		//this.createExplicitStartProduction();
		ItemSet iSet = this.getFirstItemSet();
		this.completeItemSet(iSet);
		this.fillFollowSet(iSet);
		this.itemSets.pushBack(iSet);
		Deque!(ItemSet) processed = new Deque!(ItemSet)();
		Trie!(ItemSet,Item) processedTrie = new Trie!(ItemSet,Item)();
		Deque!(ItemSet) stack = new Deque!(ItemSet)();
		this.insertItemsToProcess(processed, processedTrie, stack, iSet.getFollowSet());
		int cnt = 0;
		while(!stack.isEmpty()) {
			if(cnt % 100 == 0) {
				log("%d %u %u", cnt, stack.getSize(), processed.getSize());
			}
			cnt++;
			iSet = stack.popFront();
			//printf("%s", this.itemsetToString(iSet));
			assert(iSet !is null, format("%u", stack.getSize()));
			this.completeItemSet(iSet);
			this.fillFollowSet(iSet);
			processed.pushBack(iSet);
			processedTrie.insert(iSet.getItems(), iSet);
			this.insertItemsToProcess(processed, processedTrie, stack, iSet.getFollowSet());
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

		Iterator!(ItemSet) iSetIt = this.itemSets.begin();
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

	public size_t insertProduction(Deque!(int) toInsert) {
		assert(toInsert.getSize() > 0, "empty production not allowed");
		if(this.doesProductionExists(toInsert)) {
			throw new Exception(
				format("production %s does allready exist", 
					productionToString(toInsert, 
					this.symbolManager)[0 .. $-1]));
		} else {
			assert(this.prod !is null);
			size_t oldSize = this.prod.getSize();
			this.prod.pushBack(toInsert);
			return this.prod.getSize() - 1;
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
		//new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);

		MapSet!(ExtendedItem,int) first = new MapSet!(ExtendedItem,int)();
		bool change = true;
		while(change) { // as long as anything changes, continue
			change = false;
			// cycle all productions
			level2: foreach(size_t idx, Deque!(ExtendedItem) it; 
					this.extGrammerComplex) {
				if(it.getSize() == 1) { // epsilon prod
					change = first.insert(it[0], -2) ? true : change;
					// terminal
				} else if(!this.extGrammerKind.find(it[1]).getData()) { 
					change = first.insert(it[0], it[1].getItem()) ? true : 
						change;
				} else { // rule 3
					Iterator!(ExtendedItem) jt = it.iterator(1);
					for(; jt.isValid(); jt++) {
						// if the nonterm only contains epsilon move to the
						// next term or nonterm
						if(*jt == it[0]) { 
							// well first(A) to first(A) makes no sense
							continue level2;
						} else if(first.containsOnly(*jt, -2)) {
							continue;
						} else if(!this.extGrammerKind.find(*jt).getData()) {
							// found a term in the production
							change = first.insert(it[0], (*jt).getItem()) ? 
								true : change;
							continue level2;
						} else if(!this.extGrammerKind.find(*jt).getData()) {
						//} else if(this.symbolManager.getKind(*jt)) {
							// found a nonterm that doesn't contain only
							// epsilon, so wie copy the first set
							ISRIterator!(int) kt = first.iterator(*jt);
							if(kt is null) {
								continue level2;
							}
							for(; kt.isValid(); kt++) {
								if(*kt != -2) { // don't add epsilon
									change = first.insert(it[0], *kt) ? true :
										change;
								}
							}
							continue level2;
						} else {
							continue level2;
						}
					}
					change = first.insert(it[0], -2) ? true : change;
				}
			}
		}
		this.firstExtended = first.getMap();
	}

	/************************************************************************* 
	 *  Getter for to string
	 *
	 */

	Deque!(Deque!(int))	getExtGrammer() {
		return this.extGrammer;
	}

	Deque!(Pair!(Deque!(ExtendedItem),Set!(int))) getExtGrammerFollow() {
		return this.extGrammerFollow;
	}

	Deque!(Deque!(int)) getProd() {
		return this.prod;
	}

	Map!(size_t, MergedReduction) getMergedExtended() {
		return this.mergedExtended;
	}

	Map!(ExtendedItem,Set!(int)) getFirstExtended() {
		return this.firstExtended;
	}

	Map!(ExtendedItem,Set!(int)) getFollowExtended() {
		return this.followExtended;
	}

	Map!(int,Set!(int)) getFollowNormal() {
		return this.followNormal;
	}

	Deque!(ItemSet) getItemSet() {
		return this.itemSets;
	}

	Deque!(Deque!(ExtendedItem)) getExtGrammerComplex() {
		return this.extGrammerComplex;
	}



	/************************************************************************* 
	 *  Computation of normal first symbols below
	 *
	 */

	public void makeNormalFirstSet() {
		MapSet!(int,int) first = new MapSet!(int,int)();
		bool change = true;
		while(change) { // as long as anything changes, continue
			change = false;
			// cycle all productions
			level2: foreach(size_t idx, Deque!(int) it; prod) {
				if(it.getSize() == 1) { // epsilon prod
					change = first.insert(it[0], -2) ? true : change;
				} else if(!this.symbolManager.getKind(it[1])) { // terminal
					change = first.insert(it[0], it[1]) ? true : change;
				} else { // rule 3
					Iterator!(int) jt = it.iterator(1);
					for(; jt.isValid(); jt++) {
						// if the nonterm only contains epsilon move to the
						// next term or nonterm
						if(*jt == it[0]) { 
							// well first(A) to first(A) makes no sense
							continue level2;
						} else if(first.containsOnly(*jt, -2)) {
							continue;
						} else if(!this.symbolManager.getKind(*jt)) {
							// found a term in the production
							change = first.insert(it[0], *jt) ? true : change;
							continue level2;
						} else if(this.symbolManager.getKind(*jt)) {
							// found a nonterm that doesn't contain only
							// epsilon, so wie copy the first set
							ISRIterator!(int) kt = first.iterator(*jt);
							if(kt is null) {
								continue level2;
							}
							for(; kt.isValid(); kt++) {
								if(*kt != -2) { // don't add epsilon
									change = first.insert(it[0], *kt) ? true :
										change;
								}
							}
							continue level2;
						} else {
							continue level2;
						}
					}
					change = first.insert(it[0], -2) ? true : change;
				}
			}
		}
		this.firstNormal = first.getMap();
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
	assert("1" == productionItemToString(1,null));
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
	ISRIterator!(MapItem!(int,Set!(int))) it = map.begin();
	for(; it.isValid(); it++) {
		printfln("%d", (*it).getKey());
	}
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
	sm = new SymbolManager();
	gp = new GrammerParser(sm);
	pm = new ProductionManager(sm);
	pm.insertProduction(gp.processProduction("S := A B C"));
	pm.insertProduction(gp.processProduction("A :="));
	pm.insertProduction(gp.processProduction("B :="));
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
	//assert(mi.getData().contains(sm.getSymbolId("a")));
	assert(mi.getData().contains(-2));
}
