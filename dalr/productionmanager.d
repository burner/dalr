module dalr.productionmanager;

import dalr.dotfilewriter;
import dalr.extendeditem;
import dalr.filereader;
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
import hurt.container.stack;
import hurt.container.trie;
import hurt.conv.conv;
import hurt.io.stdio;
import hurt.io.progressbar;
import hurt.math.mathutil;
import hurt.string.formatter;
import hurt.string.stringbuffer;
import hurt.time.stopwatch;
import hurt.util.pair;
import hurt.util.slog;
import hurt.util.stacktrace;

import core.thread;

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
	private MapSet!(ExtendedItem,int) firstExtendedMS;
	private MapSet!(ExtendedItem,int) firstExtendedFasterMS;

	// The follow sets for normal and extended grammer
	private Map!(int,Set!(int)) followNormal;
	private Map!(ExtendedItem,Set!(int)) followExtended;
	private Map!(ExtendedItem,Set!(int)) followExtendedLinear;
	private Map!(ExtendedItem,Set!(int)) followExtendedEven;
	private Map!(ExtendedItem,Set!(int)) followExtendedFaster;
	private Map!(ExtendedItem,Set!(int)) followExtendedThread;
	private Map!(ExtendedItem,Set!(int)) followExtendedEpsilon;

	// Translation Table
	private Deque!(Deque!(int)) translationTable;

	// Final Table
	private Deque!(Deque!(Deque!(FinalItem))) finalTable;
	public Deque!(Deque!(Deque!(FinalItem))) finalTableNew;

	// Merged ExtendedRules
	private Map!(size_t, MergedReduction) mergedExtended;

	// The lr0 graph
	private Deque!(ItemSet) itemSets;

	private SymbolManager symbolManager;

	// followset cache
	Trie!(Item,Map!(int, ItemSet)) followSetCache; 

	// complete ItemSet cache
	Trie!(Item,Deque!(Item)) completeItemSetCache;

	// production index -> Production mapping
	Map!(size_t,Production) prodMapping;

	Deque!(ConflictIgnore) conflictIgnore;

	this() {
		this.prod = new Deque!(Deque!(int));
		this.itemSets = new Deque!(ItemSet)();
		this.followSetCache = new Trie!(Item,Map!(int, ItemSet))();
		this.completeItemSetCache = new Trie!(Item,Deque!(Item))();
	}

	this(SymbolManager symbolManager, bool glr) {
		this();
		this.symbolManager = symbolManager;
	}

	public void setConflictIgnore(Deque!(ConflictIgnore) ignore) {
		this.conflictIgnore = ignore;
	}
	
	public Pair!(Set!(int),string) makeAll(string graphFileName, 
			int printAround, bool glr, bool printAll) {

		log("makeLRZeroItemSets");
		StopWatch lrzero;
		lrzero.start();
		this.makeLRZeroItemSets();
		log("\b toke %f sec", lrzero.stop());
		log("makeExtendedGrammer");
		this.makeExtendedGrammer();
		//log("makeExtendedFirstSet");
		//print(extendedGrammerToString(pm, sm));
		//log();
		//pm.makeNormalFirstSet();
		//print(normalFirstSetToString(pm, sm));
		//log();
		//this.makeExtendedFirstSet();
		log("makeExtendedFirstSetFaster");
		this.makeExtendedFirstSetFaster();
		/*log("are firstExtended and firstExtendedFaster equal %b", 
			this.firstExtendedMS == this.firstExtendedFasterMS);
		if(this.firstExtendedMS != this.firstExtendedFasterMS) {
			log("old firstExtended %s\n\n\n", extendedTSetToString!("First")(
				this.firstExtendedMS.getMap(), this.symbolManager));
			log("new firstExtended %s", extendedTSetToString!("First")(
				this.firstExtendedFasterMS.getMap(), this.symbolManager));
			assert(false, format("old %d, new %d", 
				this.firstExtendedMS.getSize(),
				this.firstExtendedFasterMS.getSize()));
		}*/
		this.firstExtended = this.firstExtendedFasterMS.getMap();
		//print(extendedFirstSetToString(pm, sm));
		//log();
		//pm.makeNormalFollowSet();
		//println(normalFollowSetToString(pm, sm));
		log("makeExtendedFollowSet");
		//this.makeExtendedFollowSet();
		//this.makeExtendedFollowSetLinear();
		//this.makeExtendedFollowSetFaster();
		this.makeExtendedFollowSetEvenFaster();
		//this.makeExtendedFollowSetEpsilonFree();
		//this.makeExtendedFollowSetThreaded();
		println(extendedGrammerItemsToString(this, this.symbolManager));
		//log("normal %u linear %u", this.followExtended.getSize(),
		//	this.followExtendedLinear.getSize());
		/*log("epsilon %u evenFaster %u", this.followExtendedEpsilon.getSize(),
			this.followExtendedEven.getSize());
		if(this.followExtendedEpsilon != this.followExtendedEven) {
			log("even %s\n\n", extendedTSetToString!("Follow")(
				this.followExtendedEven, this.symbolManager));
			log("epsilon %s\n\n", extendedTSetToString!("Follow")(
				this.followExtendedEpsilon, this.symbolManager));
			//assert(false);
		}*/
		
	
		//log("linear = %s", extendedTSetToString!("Follow")(
		//	this.followExtendedLinear, this.symbolManager));
		//log("normal = %s", extendedTSetToString!("Follow")(
		//	this.followExtended, this.symbolManager));
		//log("Faster = %s\nequalToNormal %b", extendedTSetToString!("Follow")(
		//	this.followExtendedFaster, this.symbolManager), 
		//	this.followExtended == this.followExtendedFaster);
		//log("evenFaster = %s\nequalToNormal %b", extendedTSetToString!(
		//	"Follow")(this.followExtendedEven, this.symbolManager),
		//	this.followExtended == this.followExtendedEven);
		//log("%b", this.followExtendedEven is this.followExtended);

		//this.followExtended = this.followExtendedEven;
		this.followExtended = this.followExtendedEven;
		//log("%b", this.followExtendedEven == this.followExtendedThread);

		if(graphFileName.length > 0 && printAround == -1) {
			log("writeGraph");
			writeLR0Graph(this.getItemSets(), this.symbolManager, 
				this.getProductions(), graphFileName, this);
		}
		/*log("computeTranslationTable");
		this.computeTranslationTable();*/

		log("makeFinalTable");
		this.makeFinalTable();

		this.finalTable = this.finalTableNew;

		/*log("computeFinalTable");
		//println(transitionTableToString(this, this.symbolManager));
		//println(mergedExtendedToString(pm, sm));
		this.computeFinalTable();*/
		log("applyPrecedence");
		return this.applyPrecedence(glr);
	}


	/************************************************************************* 
	 *  Setter
	 *
	 */

	public void setProdMapping(Map!(size_t,Production) prodMapping) {
		this.prodMapping = prodMapping;
	}


	/************************************************************************* 
	 *  Getter
	 *
	 */

	public Map!(size_t,Production) getProdMapping() {
		return this.prodMapping;
	}

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

	public int getSymbolFromProduction(const Item item) {
		return this.getSymbolFromProduction(item.getProd(), 
			item.getDotPosition());
	}

	public void finalizeItemSet() {
		Iterator!(ItemSet) it = this.itemSets.begin();
		size_t idx = 1;
		for(; it.isValid(); it++) {
			if((*it).contains(0,1)) {
				(*it).setId(0);
			} else if((*it).getId() == -1) {
				(*it).setId(conv!(size_t,long)(idx++));
			}
			assert((*it).getId() != -1);
		}
		sortDeque!(ItemSet)(this.itemSets, 
			function(in ItemSet a, in ItemSet b) {
				return a.getId() < b.getId(); });
			
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
	 *  Apply the precedence rules
	 *
	 */

	private static bool itemContains(Type typ)(Deque!(FinalItem) item) {
		foreach(FinalItem it; item) {
			if(it.typ == typ) {
				return true;
			}
		}
		return false;
	}

	/** Returns the precedence of the given item. No matter if it is an
	 *  shift or reduce.
	 */
	private int getPrecedence(FinalItem item, size_t idx) {
		if(item.typ == Type.Shift) {
			Deque!(Deque!(Deque!(FinalItem))) table = this.getFinalTable();
			FinalItem shiftSymbol = table[0][idx][0];
			assert(shiftSymbol.typ == Type.Term);
			return this.symbolManager.getPrecedence(shiftSymbol.number).second;
		} else if(item.typ == Type.Reduce) {
			// precedence for rule was defined with %prec
			MapItem!(size_t,Production) prItem = 
				this.prodMapping.find(item.number);
			assert(prItem !is null);
			Production pr = prItem.getData();

			if(pr.getPrecedence() !is null && pr.getPrecedence() != "") {
				if(pr.getPrecedence() == "glr") { // glr
					log();
					return int.max;
				}
				int prPrec = this.symbolManager.getPrecedence(
					pr.getPrecedence()).second;

				if(prPrec != 0) {	
					return prPrec; // a precedence was defined for this rule
				}
			}

			// find the last terminal
			foreach_reverse(size_t idx, int it; this.prod[item.number]) {
				if(!this.symbolManager.getKind(it)) { // found a terminal
					return this.symbolManager.getPrecedence(it).second;
				}
			}
			// rule doesn't contain terminal
			return 0;
		} else if(item.typ == Type.Error) {
			return -99;
		}
		assert(false, format("getPrecedence for Type %s isn't a valid call",
			typeToString(item.typ)));
	}

	/** Returns the FinalItem with the hightest precedence.
	 *  This is used in the applyPrecedence method get the item not to delete
	 *  from the Table entry.
	 */
	private FinalItem getHighestPrecedence(Deque!(FinalItem) items, 
			size_t idx) {
		FinalItem ret = FinalItem(Type.Error, int.min);
		foreach(size_t idx, FinalItem it; items) {
			if(ret.typ == Type.Error && ret.number == int.min) {
				ret = it;
				continue;
			} else {
				int prec = this.getPrecedence(it, idx);
				if(prec == int.max) {
					continue;
				} else if(prec > this.getPrecedence(ret, idx)) {
					ret = it;	
				}
			}
		}
		return ret;
	}

	private static size_t removeAllButOneError(Deque!(FinalItem) de) {
		bool found = false;
		size_t remove = 0;
		for(size_t i = 0; i < de.getSize();) {
			if(!found && de[i].typ == Type.Error) {
				found = true;
			} else if(found && de[i].typ == Type.Error) {
				remove++;
				de.remove(i);
				continue;
			}
			i++;
		}
		return remove;
	}

	public bool canBeIgnored(Deque!(FinalItem) item, int shiftSym) {
		/*foreach(it; item) {
			log("%s", finalitemToString(it, this, this.symbolManager));
		}*/
		Deque!(int) shiftDeque = new Deque!(int)([shiftSym]);
		outer: foreach(idx, it; this.conflictIgnore) {
			foreach(jdx, jt; item) {
				if(jt.typ == Type.Shift) {
					if(!it.holdsRule(shiftDeque)) {
						continue outer;
					}
				} else if(jt.typ == Type.Reduce || jt.typ == Type.Accept) {
					if(!it.holdsRule(this.prod[jt.number])) {
						continue outer;
					}
				}
			}
			it.increCnt();
			return true;
		}
		return false;
	}

	private Pair!(Set!(int),string) applyPrecedence(bool glr) {
		scope Trace st = new Trace("applyPrecedence");
		Set!(int) ambiSet = new Set!(int)();
		StringBuffer!(char) amStrBuf = new StringBuffer!(char)(2048);

		Deque!(Deque!(Deque!(FinalItem))) table = this.getFinalTable();
		bool ret = false;

		foreach(size_t idx, Deque!(Deque!(FinalItem)) row; table) {
			if(idx % 100 == 0) {
				log("%u of %u", idx, table.getSize());
			}
			if(idx == 0) { // ignore the first row
				continue;
			}

			foreach(size_t jdx, Deque!(FinalItem) item; row) {
				if(jdx == 0) { // ignore the itemset
					continue;
				} else if(item.getSize() == 1) {
					continue; // no ambiguity
				} else { // got a conflict, resolve by precedence
					bool canIgnore = this.canBeIgnored(item, 
						table[0][jdx][0].number);
					// found the accept symbol
					if(itemContains!(Type.Accept)(item)) { 
						item.removeFalse(delegate(FinalItem toTest) {
							return toTest.typ == Type.Accept;
						});
						assert(item.getSize() == 1);
						assert(item[0].typ == Type.Accept);
					} else {
						// sometimes there is more than one error item
						removeAllButOneError(item);

						// get the item with the hightest precedence
						FinalItem highPrec = 
							this.getHighestPrecedence(item, jdx);

						// get the highest precedence
						int highPrecValue = this.getPrecedence(highPrec, jdx);

						if(highPrec.typ == Type.Error && //double error in item
								highPrec.number == int.min) {
							item.popBack();
							continue;
						}

						log(false && highPrec.typ == Type.Shift, 
							"%u %u prec %d %s %s", 
							idx, jdx, highPrecValue, 
							typeToString(highPrec.typ), 
							this.symbolManager.getSymbolName(highPrec.number));

						log(false && highPrec.typ == Type.Reduce, 
							"%u %u prec %d %s %s", 
							idx, jdx, highPrecValue, 
							typeToString(highPrec.typ), 
							this.getPrecedence(highPrec, jdx));

						// remove all the items that have lower precedence
						// than that of the highest, there might be more
						// than one item that fulfills this requirement
						//if(!glr) {
							item.removeFalse(delegate(FinalItem toTest) {
								return this.getPrecedence(toTest, jdx) >= 
									highPrecValue;
							});
						//}

						// warn the user about ambiguities
						/*warn(item.getSize() > 1, 
							"conflict in itemset %u with lookahead token "
							~ "%s", table[idx][0][0].number, 
							this.symbolManager.getSymbolName(table[0][jdx][0].
							number));*/
						if(!canIgnore && item.getSize() == 2 && 
								item[0].typ == Type.Reduce
								&& item[1].typ == Type.Reduce) {
							ambiSet.insert(table[idx][0][0].number);
							warn("conflict in itemset %d", 
								table[idx][0][0].number);
							amStrBuf.pushBack("conflict in itemset %d\n", 
								table[idx][0][0].number);
							warn(item[0].number < this.prod.getSize() &&
								item[1].number < this.prod.getSize(), 
								"reduce recduce conflict with rule %d " ~
								"and rule %d\n%s\n%s", 
								item[0].number, 
								item[1].number, 
								productionToString(this.prod[item[0].number], 
									this.symbolManager),
								productionToString(this.prod[item[1].number], 
									this.symbolManager));
							if(item[0].number < this.prod.getSize() &&
								item[1].number < this.prod.getSize()) {
								amStrBuf.pushBack("reduce recduce conflict with rule %d"
									~ " and rule %d\n%s\n%s\n", item[0].number, 
									item[1].number, 
									productionToString(this.prod[
										item[0].number], this.symbolManager),
									productionToString(this.prod[
										item[1].number], this.symbolManager));
							}
							ret = true;
						} else if(!canIgnore && item.getSize() == 2 &&
								item[0].typ == Type.Reduce
								&& item[1].typ == Type.Shift) {
							ambiSet.insert(table[idx][0][0].number);
							amStrBuf.pushBack("conflict in itemset %u with " ~
								" lookahead token %s\nwith reduction rule " ~
								"%d %s\n", table[idx][0][0].number, 
								this.symbolManager.
								getSymbolName(table[1][jdx][0].number),
								item[0].number, 
								productionToString(this.prod[item[0].number],
								this.symbolManager));
							warn("conflict in itemset %u with lookahead token "
							~ "%s\nwith reduction rule %d %s", 
								table[idx][0][0].number, 
								this.symbolManager.
								getSymbolName(table[1][jdx][0].number),
								item[0].number, 
								productionToString(this.prod[item[0].number],
								this.symbolManager));
							// so if we are not creating a glr parser we do as 
							// yacc does
							/*if(!this.glr) {
								item.popFront();
							}*/
							ret = true;
						} else if(!canIgnore && item.getSize() == 2 &&
								item[0].typ == Type.Shift
								&& item[1].typ == Type.Reduce) {
							ambiSet.insert(table[idx][0][0].number);
							amStrBuf.pushBack("conflict in itemset %u with " ~
								" lookahead token %s\nwith reduction rule " ~
								"%d %s\n", table[idx][0][0].number, 
								this.symbolManager.
								getSymbolName(table[0][jdx][0].number),
								item[1].number, 
								productionToString(this.prod[item[1].number],
								this.symbolManager));
							warn("conflict in itemset %u with lookahead token "
							~ "%s\nwith reduction rule %d %s", 
								table[idx][0][0].number, 
								this.symbolManager.
								getSymbolName(table[0][jdx][0].number),
								item[1].number, 
								productionToString(this.prod[item[1].number],
								this.symbolManager));
							// so if we are not creating a glr parser we do as 
							// yacc does
							/*if(!this.glr) {
								item.popBack();
							}*/
							ret = true;
						} else if(!canIgnore && item.getSize() > 2) {
							warn("last conflict comprised of more " ~
								"than two items %u", table[idx][0][0].number);
							amStrBuf.pushBack("last conflict comprised of more " 
								~ "than two items %u\n", 
								table[idx][0][0].number);
							foreach(FinalItem gt; item) {
								warn(gt.typ == Type.Shift, "type %s number %s",
									typeToString(gt.typ), this.symbolManager.
									getSymbolName(gt.number));
								if(gt.typ == Type.Shift) {
									amStrBuf.pushBack(
										"type %s number %s\n", 
										typeToString(gt.typ), 
										this.symbolManager.getSymbolName
										(gt.number));
								}
								if(gt.typ == Type.Reduce) {
									if(gt.number < this.prod.getSize()) {
										if(gt.typ == Type.Reduce) {
											amStrBuf.pushBack("type %s number %u %s\n", 
												typeToString(gt.typ), 
												gt.number, productionToString(
												this.prod[gt.number],
												this.symbolManager));
										}
										warn(gt.typ == Type.Reduce, 
											"type %s number %u %s", 
											typeToString(gt.typ), gt.number,
											productionToString(
											this.prod[gt.number],
											this.symbolManager));
									} else {
										warn(gt.typ == Type.Reduce, 
											"type %s number %u", 
											typeToString(gt.typ), gt.number);
										if(gt.typ == Type.Reduce) {
											amStrBuf.pushBack("type %s number %u\n"
											, typeToString(gt.typ), gt.number);
										}
									}
								}
							}
							ret = true;
						}
					}
				}
			}
		}
		return Pair!(Set!(int),string)(ambiSet,amStrBuf.getString());
	}

	private bool isThereAValidItem(Deque!(FinalItem) item) {
		foreach(FinalItem it; item) {
			if(it.typ == Type.Shift || it.typ == Type.Reduce ||
					it.typ == Type.Accept || it.typ == Type.Goto) {
				return true;
			}
		}
		return false;
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

	private void makeFinalTable() {
		scope Trace st = new Trace("makeFinalTable");
		this.mapExtendedFollowSetToGrammer();
		this.reduceExtGrammerFollow();
		
		// the final table
		auto ret = new Deque!(Deque!(Deque!(FinalItem)))();

		Pair!(Set!(int),Set!(int)) tAnT = 
			this.symbolManager.getTermAndNonTerm();

		auto tmp = new Deque!(Deque!(FinalItem))(this.symbolManager.getSize());
		// place the itemset corner sym, this is just whitespace later
		tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.ItemSet, -1)]));

		// place the $ symbol as first term item
		tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.Term, -1)])); 

		// place all term item
		foreach(int it; tAnT.first) {
			tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.Term, it)]));
		}
		// place all non-term item
		foreach(int it; tAnT.second) {
			tmp.pushBack(new Deque!(FinalItem)([FinalItem(Type.NonTerm, it)]));
		}

		ret.pushBack(tmp);

		foreach(ItemSet it; this.getItemSets()) {
			auto row = new Deque!(Deque!(FinalItem))(128);
			// the first entry is the itemset
			row.pushBack(
				new Deque!(FinalItem)([FinalItem(Type.ItemSet,
					conv!(long,int)(it.getId()))]) 
				);

			foreach(size_t idx, Deque!(FinalItem) j; tmp) {
				if(idx == 0) { // ignore the itemset entry
					continue;
				}
				int jt = j[0].number;
				Type jTyp = j[0].typ;
				auto tmp2 = new Deque!(FinalItem)();

				// the shift or goto symbol
				int toInsert = conv!(long,int)(it.getFollowOnInput(jt));
				if(toInsert != -99) {
					// if it's a term we need to shift if it's a non-term
					// we need to goto
					tmp2.pushBack(FinalItem(
						jTyp == Type.Term ? Type.Shift : Type.Goto, 
						toInsert));
				}

				// insert the reductions
				auto mrMi = this.mergedExtended.find(it.getId());
				MergedReduction mr = mrMi !is null ? mrMi.getData() : null;
				if(mr !is null) {
					ISRIterator!(size_t) kt = mr.iterator(jt);
					for(; kt !is null && kt.isValid(); kt++) {
						if(*kt == 0) { 
							tmp2.pushBack(FinalItem(Type.Accept, 
								conv!(size_t,int)(*kt)));
						} else {
							tmp2.pushBack(FinalItem(Type.Reduce, 
								conv!(size_t,int)(*kt)));
						}
					}
				}

				// nothing inserted means error
				if(tmp2.isEmpty()) {
					tmp2.pushBack(FinalItem(Type.Error, -99));
				}

				// save it all
				row.pushBack(tmp2);
			}

			ret.pushBack(row);
		}
		this.finalTableNew = ret;
	}

	private Deque!(Deque!(int)) computeTranslationTable() {
		scope Trace st = new Trace("computeTranslationTable");
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
			size_t cnt = 0;
			foreach(size_t idx, int jt; tmp) {
				int toInsert = conv!(long,int)(it.getFollowOnInput(jt));
				cnt = cnt + (toInsert != -99 ? 1 : 0);
				tmp2.pushBack(toInsert);
			}
			assert(cnt == it.getFollowSet.getSize(), "this should be equal");
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
		scope Trace st = new Trace("mapExtendedFollowSetToGrammer");
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
		scope Trace st = new Trace("reduceExtGrammerFollow");
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

			assert(tmp.getFollowMap() !is null);
			assert(tmp.getExtFollowMap() !is null);
		}

		this.mergedExtended = mr;
	}

	public Deque!(Deque!(Deque!(FinalItem))) computeFinalTable() {
		scope Trace st = new Trace("computeFinalTable");
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

		int ambiguityCnt = 0;

		// run over all merged reductions
		// the key is the row
		ISRIterator!(MapItem!(size_t, MergedReduction)) it = 
			this.mergedExtended.begin();
		for(size_t tid = 0; it.isValid(); it++, tid++) {
			//log("%u from %u", tid, this.mergedExtended.getSize());
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

			MapItem!(size_t, MergedReduction) mItem = (*it);
			assert(mItem !is null);
			MergedReduction mr = mItem.getData();
			assert(mr !is null);
			//Map!(int, Set!(size_t)) follow = (*it).getData().getFollowMap();
			Map!(int, Set!(size_t)) follow = mr.getFollowMap();
			assert(follow !is null);
			foreach(size_t idx, Deque!(FinalItem) tt; tmp) {
				//log("%u row size %u", idx, theRow.getSize());
				assert(tt !is null);
				assert(theRow !is null);
				assert(tt.getSize() == 1);
				if(tt[0].typ == Type.Term) {
					// get the follow set
					MapItem!(int,Set!(size_t)) s = follow.find(tt[0].number);
					if(s is null) {
						continue;
					} else {
						// if the follow set exists add all items to the deque 
						// entry
						assert(s !is null);
						Set!(size_t) rtSet = s.getData();
						assert(rtSet !is null);
						ISRIterator!(size_t) rt = rtSet.begin();
						for(; rt.isValid(); rt++) {
							theRow[idx].pushBack(FinalItem(Type.Reduce, 
								conv!(size_t,int)(*rt)));
							if(theRow[idx].getSize() > 1) {
								/*log("ambiguity cnt %d", ambiguityCnt++);
								log("%s %u %u", 
									this.symbolManager.getSymbolName(
									tt[0].number) , *rt, idx+1);
								*/
							}
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

	public bool isDotAtEndOfProduction(const Item item) {
		Deque!(int) pro = this.getProduction(item.getProd());
		return pro.getSize() == item.getDotPosition();
	}
	
	private bool doesProductionExists(Deque!(int) toTest) {
		return this.prod.contains(toTest);
	}

	private void completeItemSet(ItemSet iSet) {
		scope Trace st = new Trace("completeItemSet");
		assert(iSet !is null);
		Deque!(Item) de = iSet.getItems();
		// sort them so the completed itemset can be found
		sortDeque!(Item)(de, function(in Item a, in Item b) {
			return a.toHash() < b.toHash(); });

		Deque!(Item) tmpOld;
		Deque!(Item) foundOld;
		// lets check if we hace make the itemset allready
		if(this.completeItemSetCache.contains(de)) {
			foundOld = this.completeItemSetCache.find(de);
			iSet.setItems(foundOld);
			return;
		} else {
			// if we haven't found it we need to save the deque we
			// create
			tmpOld = new Deque!(Item)(de);
		}
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
		// it needs to be sorted so the items of the itemset can
		// be used in a trie
		sortDeque!(Item)(de, function(in Item a, in Item b) {
			return a.toHash() < b.toHash(); });

		// well we have created a new complete itemset that we need to cache
		if(foundOld !is null) {
			assert(de == foundOld, format("%u %U", de.getSize(), 
				foundOld.getSize()));
		}
		if(tmpOld !is null && !this.completeItemSetCache.contains(tmpOld)) {
			assert(tmpOld !is null);
			this.completeItemSetCache.insert(tmpOld, de);
		}

	}

	private void fillFollowSet(ItemSet iSet) {
		scope Trace st = new Trace("fillFollowSet");
		assert(iSet !is null);
		Deque!(Item) iSetItems = iSet.getItems();
		sortDeque!(Item)(iSetItems, function(in Item a, in Item b) {
			return a.toHash() < b.toHash(); });
		Deque!(Item) iSetItemsCopy = new Deque!(Item)(iSetItems);

		// check if there is something allready created for the iSetItems
		Map!(int,ItemSet) followFoundCache = null;
		if(this.followSetCache.contains(iSetItems)) {
			followFoundCache = this.followSetCache.find(iSetItems);
			// set the follow map of the item
			iSet.setFollow(followFoundCache);
			return;
		}

		// well the cache missed so lets make the map
		Map!(int, ItemSet) follow = new Map!(int, ItemSet)();
		assert(iSetItems !is null);
		foreach(size_t idx, Item it; iSetItems) {
			if(this.isDotAtEndOfProduction(it)) {
				continue;
			}
				
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

		// set the follow map of the item
		iSet.setFollow(follow);

		// save the created follow map into the cache
		if(!this.followSetCache.contains(iSetItemsCopy)) {
			this.followSetCache.insert(	iSetItemsCopy, follow);
		} 
	}

	private void insertItemsToProcess(Deque!(ItemSet) processed, 
			Trie!(Item,ItemSet) processedTrie,
			Deque!(ItemSet) stack, Map!(int, ItemSet) toProcess) {
		scope Trace st = new Trace("insertItemsToProcess");

		ISRIterator!(MapItem!(int,ItemSet)) it = toProcess.begin();
		for(; it.isValid(); it++) {
			//if(processed.contains((*it).getData())) {
			if(processedTrie.contains((*it).getData().getItems())) {
				//assert(processedTrie.contains((*it).getData().getItems()),
				//	printBoth(processed, processedTrie));
				continue;
			} else {
				//assert(!processedTrie.contains((*it).getData().getItems()),
				//	printBoth(processed, processedTrie));
				assert((*it).getData() !is null);
				stack.pushBack((*it).getData());
				assert(stack.back() !is null);
			}
		}
	}

	private string printBoth(Deque!(ItemSet) de, Trie!(Item,ItemSet) trie) {
		StringBuffer!(char) ret = new StringBuffer!(char)();
		foreach(ItemSet it; de) {
			if(!trie.contains(it.getItems())) {
				ret.pushBack(it.toString());	
			}
		}
		return ret.getString();
	}

	public void makeLRZeroItemSets() {
		scope Trace st = new Trace("makeLRZeroItemSets");
		//this.createExplicitStartProduction();
		ItemSet iSet = this.getFirstItemSet();
		this.completeItemSet(iSet);
		this.fillFollowSet(iSet);
		this.itemSets.pushBack(iSet);
		Deque!(ItemSet) processed = new Deque!(ItemSet)();
		Trie!(Item,ItemSet) processedTrie = new Trie!(Item,ItemSet)();
		Deque!(ItemSet) stack = new Deque!(ItemSet)();
		this.insertItemsToProcess(processed, processedTrie, stack, 
			iSet.getFollowSet());

		int cnt = 0;
		while(!stack.isEmpty()) {
			if(cnt % 100 == 0) {
				version(DALR) {
				log("%d %u %u %u", cnt, stack.getSize(), processed.getSize(),
					processedTrie.getSize());
				Trace.printStats();
				}
			}
			cnt++;
			iSet = stack.popFront();
			//printf("%s", this.itemsetToString(iSet));
			assert(iSet !is null, format("%u", stack.getSize()));
			this.completeItemSet(iSet);
			this.fillFollowSet(iSet);
			//processed.pushBack(iSet);
			processedTrie.insert(iSet.getItems(), iSet);
			this.insertItemsToProcess(processed, processedTrie, stack, 
				iSet.getFollowSet());
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
		/*foreach(size_t j, ExtendedItem jt; items) {
			if(j < jdx) {
				continue;
			}

			foreach(Deque!(ExtendedItem) it; prod) {
				if(it.front() == jt) {
					return false;
				}
			}
		}*/
		for(size_t j = jdx; j < items.getSize(); j++) {
			foreach(Deque!(ExtendedItem) it; prod) {
				if(it.front() == items[j]) {
					return false;
				}
			}
		}
		return true;
	}

	private void insertAllButEpsilon(MapSet!(ExtendedItem,int) follow, 
			ExtendedItem from, ExtendedItem to) {

		// over all first element except epsilon from "from"
		if(!this.firstExtended.contains(from)) { // nothing in the first set
			/*log("%u from = %s to = %s", this.firstExtended.getSize(),
				extendedGrammerItemToString(this, this.symbolManager,from),
				extendedGrammerItemToString(this, this.symbolManager,to));*/
			ISRIterator!(MapItem!(ExtendedItem,Set!(int))) it = 
				this.firstExtended.begin();
			for(; it.isValid(); it++) {
				if((*it).getKey() == from) {
					assert(false,"found it in the firstExtended\n\n");
				}
			}
			//log("check if this is valid");
			//follow.insert(to,from.getItem());
			return;
		}
		MapItem!(ExtendedItem,Set!(int)) mi = this.firstExtended.find(from);
		//log("%u", mi.getData().getSize());
		ISRIterator!(int) it = mi.getData().begin();
		for(; it.isValid(); it++) {
			if(*it != -2) {
				follow.insert(to, *it);
			}
		}
	}

	private bool containsEpsilon(Map!(ExtendedItem,Set!(int)) first,
			ExtendedItem item) {
		MapItem!(ExtendedItem,Set!(int)) mi = first.find(item);
		if(mi is null) {
			return false;
		} else {
			Set!(int) miSet = mi.getData();
			return miSet.contains(-2);
		}
	}

	// check if the first set of item contains only epsilon aka
	// first(item) == {-2}
	private bool containsOnlyEpsilon(Map!(ExtendedItem,Set!(int)) first,
			ExtendedItem item) {
		MapItem!(ExtendedItem,Set!(int)) mi = first.find(item);
		if(mi is null) {
			return false;
		} else {
			Set!(int) miSet = mi.getData();
			return miSet.contains(-2) && miSet.getSize() == 1;
		}
	}

	private bool getKindOfExtendedItem(ExtendedItem item) {
		MapItem!(ExtendedItem,bool) kindItem = this.extGrammerKind.find(item);
		assert(kindItem !is null);
		return kindItem.getData();
	}

	public void makeExtendedFollowSetLinear() {
		scope Trace st = new Trace("makeExtendedFollowSetLinear");
		assert(this.firstExtended !is null);
		assert(this.firstExtended.getSize() > 0);

		// the resulting followSet
		MapSet!(ExtendedItem,int) followSets = 
			new MapSet!(ExtendedItem,int)();

		// the copy rules. at the end every thing from the key must be
		// mapped to the set
		MapSet!(ExtendedItem,ExtendedItem) mapping = new
			MapSet!(ExtendedItem,ExtendedItem)(
			ISRType.HashTable,ISRType.HashTable);

		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 . this is rule 1 */
		followSets.insert(this.findFirstItemOfExtendedItem(
			this.extGrammerComplex), -1);

		foreach(size_t idx, Deque!(ExtendedItem) it; this.extGrammerComplex) {
			for(size_t jdx = 0; jdx < it.getSize()-1; jdx++) {
				if(jdx == 0 /*|| !getKindOfExtendedItem(it[jdx])*/) {
					continue;
				}
				
				// rule 2
				insertAllButEpsilon(followSets, it[jdx+1], it[jdx]);
				mapping.insert(it[jdx+1], it[jdx]);
 				// prep for rule 3
				if(jdx+2 == it.getSize() && containsEpsilon(this.firstExtended,
						it[jdx+1])) {
					mapping.insert(it[jdx], it[0]);
				}
				if(jdx+1 == it.getSize()) {
					mapping.insert(it[jdx], it[0]);
				}
			}
		}
		log("after rule two %u; mappingSize %u", followSets.getSize(),
			mapping.getSize());

		int cnt = 0;
		bool changed = true;
		StopWatch sw;
		sw.start();
		while(changed) { // run as long as the follow set change
			changed = false;
			size_t oldSize = followSets.getSize();
			
			ISRIterator!(MapItem!(ExtendedItem,Set!(ExtendedItem))) mapIt = 
				mapping.getMap().begin();
			
			for(; mapIt.isValid(); mapIt++) { // for all keys
				ISRIterator!(int) followIt = followSets.iterator((*mapIt).
					getKey());
				if(followIt is null) { // no followset present
					continue;
				}

				// run over all follow items
				for(; followIt.isValid(); followIt++) { 
					ISRIterator!(ExtendedItem) setIt = (*mapIt).getData().
						begin();
					for(; setIt.isValid(); setIt++) { 
						// insert all items into the follow mapping
						followSets.insert(*setIt, *followIt);
					}
				}
			}
			if(followSets.getSize() > oldSize) {
				changed = true;
			}
		}
		log("runtime %f", sw.stop());


		// save the followSet
		this.followExtendedLinear = followSets.getMap();
	}

	public void makeExtendedFollowSetThreaded() {
		scope Trace st = new Trace("makeExtendedFollowThreaded");
		Deque!(Deque!(ExtendedItem)) grammer = 
			new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);
		MapSet!(ExtendedItem,int) followSets = 
			new MapSet!(ExtendedItem,int)(ISRType.HashTable, 
			ISRType.HashTable);

		ExtendedItem first = this.findFirstItemOfExtendedItem(grammer);

		immutable numThreads = 4;
		Thread[numThreads] thre;

		for(int i = 0; i< numThreads; i++) {
			thre[i] = new ExtendedWorker(
				(grammer.getSize() / numThreads) * i,
				(grammer.getSize() / numThreads) * (i+1), grammer,
				this.extGrammerKind, this.firstExtended, first);
			thre[i].start();
		}


		for(int i = 0; i < numThreads; i++) {
			thre[i].join();
			ExtendedWorker ew = cast(ExtendedWorker)thre[i];
			foreach(key, value; ew.followSets) {
				followSets.insert(key,value);
			}
		}

		size_t oldSize = 0;
		while(oldSize < followSets.getSize()) {
			oldSize = followSets.getSize();
			for(int i = 0; i < numThreads; i++) {
				ExtendedWorker ew = cast(ExtendedWorker)thre[i];
				foreach(from, to; ew.mapping) {
					followSets.insert(from, followSets.getSet(to));
				}
			}
		}

		this.followExtendedThread = followSets.getMap();

	}

	public void makeExtendedFollowSetEpsilonFree() {
		Set!(ExtendedItem) nonTerm = new Set!(ExtendedItem)(ISRType.HashTable);
		bool termOrNonTerm(ExtendedItem item) {
			if(nonTerm.contains(item)) {
				return true;
			} else {
				return false;
			}
		}

		scope Trace st = new Trace("makeExtendedFollowSetEpsilonFree");
		log("first %s", extendedFirstSetToString(this, this.symbolManager));
		assert(this.firstExtended !is null);
		auto grammar = this.extGrammerComplex;

		foreach(Deque!(ExtendedItem) it; grammar) {
			nonTerm.insert(it[0]);
		}

		MapSet!(ExtendedItem,int) followSets = 
			new MapSet!(ExtendedItem,int)(ISRType.HashTable, 
			ISRType.HashTable);

		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		followSets.insert(this.findFirstItemOfExtendedItem(grammar), -1);

		auto mapping = new MapSet!(ExtendedItem,ExtendedItem)
			(ISRType.HashTable, ISRType.HashTable);

		foreach(size_t idx, Deque!(ExtendedItem) it; grammar) {
			foreach(size_t jdx, ExtendedItem jt; it) {
				if(jdx == 0 || !termOrNonTerm(jt)) {
					continue;
				}

				// rule 3
				if(jdx+1 == it.getSize()) {
					mapping.insert(jt, it[0]);
					continue;
				}

				if(termOrNonTerm(it[jdx+1])) {
					log();
					mapping.insert(it[jdx+1], jt);
				}
				auto zt = this.firstExtended.find(it[jdx+1]);
				if(zt is null) {
					followSets.insert(jt, it[jdx+1].getItem());
					log("(%s%s%s)", it[jdx+1].getLeft() == -1 ? "$" : 
						conv!(int,string)(it[jdx+1].getLeft()),
						productionItemToString(it[jdx+1].getItem(), 
						this.symbolManager), it[jdx+1].getRight() == -1 ? "$" : 
						conv!(int,string)(it[jdx+1].getRight()));
					continue;
				} else {
					log();
					for(auto kt = zt.getData().begin(); kt.isValid(); 
							kt++) {
						followSets.insert(jt, *kt);
					}
				}
			}
		}

		size_t oldSize = followSets.getSize();
		do {
			oldSize = followSets.getSize();
			foreach(from, to; mapping) {
				followSets.insert(to, followSets.getSet(from));
			}
		} while(followSets.getSize() > oldSize);


		this.followExtendedEpsilon = followSets.getMap();
	}

	public void makeExtendedFollowSetEvenFaster() {
		scope Trace st = new Trace("makeExtendedFollowSetEvenFaster");
		assert(this.firstExtended !is null);
		Deque!(Deque!(ExtendedItem)) grammer = 
			new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);

		Set!(ExtendedItem) nonTerm = new Set!(ExtendedItem)(ISRType.HashTable);
		foreach(Deque!(ExtendedItem) it; grammer) {
			nonTerm.insert(it[0]);
		}

		MapSet!(ExtendedItem,int) followSets = 
			new MapSet!(ExtendedItem,int)(ISRType.HashTable, 
			ISRType.HashTable);

		Set!(int) tmp = new Set!(int)();
		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		tmp.insert(-1); 
		followSets.insert(this.findFirstItemOfExtendedItem(grammer), tmp);

		tmp = null;

		size_t oldSize = followSets.getSize();
		size_t tmpSize = followSets.getSize();
		size_t oldSizeSave;

		int innerCnt = 0;
		log("processing %u grammer rules", grammer.getSize());
		outer: do {
			oldSize = tmpSize;
			if(innerCnt % 100 == 0) {
				log("extendedFollow cnt %d grammarSize %d", innerCnt, 
					grammer.getSize());
			}
			innerCnt++;
			oldSizeSave = oldSize;
			foreach(size_t idx, Deque!(ExtendedItem) it; grammer) {
				updateBar( conv!(size_t,int)(idx), conv!(size_t,int)(
					grammer.getSize()*2));
				foreach(size_t jdx, ExtendedItem jt; it) {
					if(jdx == 0) {
						continue;
					} else if(jdx+1 < it.getSize()) { // rule 2
						MapItem!(ExtendedItem,bool) kindItem = 
							this.extGrammerKind.find(jt);
						assert(kindItem !is null);
						bool kind = kindItem.getData();
						if(kind) {
							ProductionManager.insertFollowItems!(ExtendedItem)
								(followSets.getMap(), jt, this.firstExtended, 
								it[jdx+1]);
						}
					}
				}
			}

			inner: foreach(size_t idx, Deque!(ExtendedItem) it; grammer) { 
				updateBar( conv!(size_t,int)(idx+grammer.getSize()), 
					conv!(size_t,int)(grammer.getSize()*2));
				foreach(size_t jdx, ExtendedItem jt; it) {
					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(it.back());
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind && ( (jdx+1 == it.getSize()) || 
							ProductionManager.restIsTerm(idx,
							jdx, nonTerm, grammer))) {

						ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets.getMap(), it.back, followSets.getMap(),
							it[0], true);
						/*
						hasChanged = hasChanged || 
							ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets, it.back, followSets, it[0],true);
						*/
					}
				}
			}
			barDone(conv!(size_t,int)(grammer.getSize()*2));
			tmpSize = followSets.getSize();
			if(tmpSize > oldSize) {
				log("oldSize %u tmpSize %u", oldSize, tmpSize);
				//oldSize = tmpSize;
				//continue outer;
			}
		} while(tmpSize > oldSize);
		this.followExtendedEven = followSets.getMap();
	}

	private static bool restIsTerm(size_t idx, size_t jdx, 
			Set!(ExtendedItem) nonTerm, Deque!(Deque!(ExtendedItem)) grammar) {
		Deque!(ExtendedItem) items = grammar[idx];

		for(size_t j = jdx; j < items.getSize(); j++) {
			if(nonTerm.contains(items[j])) {
				return false;
			}
		}
		return true;
	}

	public void makeExtendedFollowSetFaster() {
		scope Trace st = new Trace("makeExtendedFollowSetFaster");
		assert(this.firstExtended !is null);
		Deque!(Deque!(ExtendedItem)) grammer = 
			new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);

		MapSet!(ExtendedItem,int) followSets = 
			new MapSet!(ExtendedItem,int)(ISRType.HashTable, 
			ISRType.HashTable);

		Set!(int) tmp = new Set!(int)();
		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		tmp.insert(-1); 
		followSets.insert(this.findFirstItemOfExtendedItem(grammer), tmp);

		tmp = null;

		size_t oldSize = followSets.getSize();
		size_t tmpSize = followSets.getSize();
		size_t oldSizeSave;

		int innerCnt = 0;
		log("processing %u grammer rules", grammer.getSize());
		outer: do {
			oldSize = tmpSize;
			if(innerCnt % 100 == 0) {
				log("extendedFollow cnt %d grammarSize %d", innerCnt, 
					grammer.getSize());
			}
			innerCnt++;
			oldSizeSave = oldSize;
			foreach(size_t idx, Deque!(ExtendedItem) it; grammer) {
				updateBar( conv!(size_t,int)(idx), conv!(size_t,int)(
					grammer.getSize()*2));
				foreach(size_t jdx, ExtendedItem jt; it) {
					if(jdx == 0) {
						continue;
					} else if(jdx+1 < it.getSize()) { // rule 2
						MapItem!(ExtendedItem,bool) kindItem = 
							this.extGrammerKind.find(jt);
						assert(kindItem !is null);
						bool kind = kindItem.getData();
						if(kind) {
							ProductionManager.insertFollowItems!(ExtendedItem)
								(followSets.getMap(), jt, this.firstExtended, 
								it[jdx+1]);
						}
					}
				}
			}
			/*if(tmpSize > oldSize) {
				oldSize = tmpSize;
				continue outer;
			}*/
			// rule 3
			inner: foreach(size_t idx, Deque!(ExtendedItem) it; grammer) { 
				updateBar( conv!(size_t,int)(idx+grammer.getSize()), 
					conv!(size_t,int)(grammer.getSize()*2));
				foreach(size_t jdx, ExtendedItem jt; it) {
					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(it.back());
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind && ( (jdx+1 == it.getSize()) || 
							ProductionManager.areExtendedItemEpsilon(idx,
							jdx, grammer))) {

						ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets.getMap(), it.back, followSets.getMap(),
							it[0], true);
						/*
						hasChanged = hasChanged || 
							ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets, it.back, followSets, it[0],true);
						*/
					}
				}
			}
			tmpSize = followSets.getSize();
			barDone(conv!(size_t,int)(grammer.getSize()*2));
			if(tmpSize > oldSize) {
				log("oldSize %u tmpSize %u", oldSize, tmpSize);
				//oldSize = tmpSize;
				//continue outer;
			}
		} while(tmpSize > oldSize);
		this.followExtendedFaster = followSets.getMap();
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
							hasChanged = hasChanged || 
								ProductionManager.insertFollowItems
								!(ExtendedItem)(followSets, jt, 
								this.firstExtended, it[jdx+1]);
						}
					}
				}
			}
			if(hasChanged) {
				continue outer;
			}
			log();
			hasChanged = false;
			int innerCnt = 0;
			// rule 3
			inner: foreach(size_t idx, Deque!(ExtendedItem) it; grammer) { 
				if(innerCnt % 100 == 0) {
					log("inner cnt %d", innerCnt);
				}
				innerCnt++;
				foreach(size_t jdx, ExtendedItem jt; it) {
					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(it.back());
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind && ( (jdx+1 == it.getSize()) || 
							ProductionManager.areExtendedItemEpsilon(idx,
							jdx, grammer))) {
						hasChanged = hasChanged || 
							ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets, it.back, followSets, it[0],true);
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
		scope Trace st = new Trace("makeExtendedGrammar");
		// This looks ugly because itemset numbers as well
		// as items are mixed and both are encoded as ints.
		// Every even indexed item in a deque!(int) is a symbol.
		Deque!(Deque!(int)) extendedGrammer = new Deque!(Deque!(int))(
			this.itemSets.getSize()*2);

		Iterator!(ItemSet) iSetIt = this.itemSets.begin();
		for(size_t jdx = 0; iSetIt.isValid(); iSetIt++, jdx++) {
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
			/*foreach(size_t idx, ExtendedItem jt; it) {
				if(jt == toTest && idx == 0) {
					return true;
				}
			} old */
			if(it[0] == toTest) {
				return true;
			}
		}
		return false;
	}

	private void constructExtendedKind() {
		this.extGrammerKind = new Map!(ExtendedItem,bool)();
		/*foreach(Deque!(ExtendedItem) it; this.extGrammerComplex) {
			foreach(size_t idx, ExtendedItem jt; it) {
				log("%s", extendedGrammerItemToString(this, this.symbolManager,
						jt));
				if(this.extGrammerKind.contains(jt)) {
					assert(this.extGrammerKind.find(jt).getKey() == jt);
					continue;	
				} else {
					this.extGrammerKind.insert(jt, 
						this.testExtendedItemKind(jt));
				}
			}
		}*/
		int maxLeft = 0;
		int maxRight = 0;
		int maxItem = 0;
		foreach(Deque!(ExtendedItem) it; this.extGrammerComplex) {
			foreach(size_t idx, ExtendedItem jt; it) {
				MapItem!(ExtendedItem,bool) item = 
					this.extGrammerKind.find(jt);
				maxLeft = jt.getLeft() > maxLeft ? jt.getLeft() : maxLeft;
				maxRight = jt.getRight() > maxRight ? jt.getRight() : maxRight;
				maxItem = jt.getItem() > maxItem ? jt.getItem() : maxItem;
				if(item is null) {
					this.extGrammerKind.insert(jt, idx == 0);
				} else {
					item.setData(item.getData() ? item.getData() : idx == 0);
				}
			}
		}
		//log("%d %d %d", maxLeft, maxRight, maxItem);
		debug {
			foreach(Deque!(ExtendedItem) it; this.extGrammerComplex) {
				foreach(size_t idx, ExtendedItem jt; it) {
					assert(this.extGrammerKind.contains(jt),
						extendedGrammerItemToString(this, this.symbolManager,
						jt));
				}
			}
		}
	}

	public void makeExtendedFirstSetFaster() {
		scope Trace st = new Trace("makeExtendedFirstSetFaster");
		this.constructExtendedKind();
		assert(this.extGrammerComplex !is null);
		assert(this.extGrammerKind !is null);

		MapSet!(ExtendedItem,int) first = new MapSet!(ExtendedItem,int)(
			ISRType.HashTable, ISRType.HashTable);

		foreach(ExtendedItem key, bool kind; this.extGrammerKind) {
			if(!kind) {
				first.insert(key, key.getItem());
			}
		}

		MapSet!(ExtendedItem,ExtendedItem) bli = new MapSet!(
			ExtendedItem,ExtendedItem)(ISRType.HashTable, ISRType.HashTable);

		size_t oldSize = 0;
		foreach(idx, Deque!(ExtendedItem) it; this.extGrammerComplex) {
			assert(it !is null, "no null productions allowed");	
			assert(it.getSize() > 1, "no empty productions allowed");
			
			// if the first symbol is a terminal
			MapItem!(ExtendedItem, bool) mi = 
				this.extGrammerKind.find(it[1]);

			assert(mi !is null);
			bool kind = mi.getData();
			if(!kind) {
				assert(it[1].getItem() != -2, "no epsilon allowed");
				first.insert(it[0], it[1].getItem());
			} else {
				/*auto jt = first.iterator(it[1]);
				for(; jt !is null && jt.isValid(); jt++) {
					assert(*jt != -2, "no epsilon allowed");
					first.insert(it[0], *jt);
				}*/
				bli.insert(it[1], it[0]);
			}
		}
		do {
			oldSize = first.getSize();
			foreach(from, to; bli) {
				first.insert(to, first.getSet(from));
			}
		} while(first.getSize() > oldSize);

		this.firstExtendedFasterMS = first;
	}


	public void makeExtendedFirstSet() {
		scope Trace st = new Trace("makeExtendedFirstSet");
		this.constructExtendedKind();
		//log();
		//new Deque!(Deque!(ExtendedItem))(this.extGrammerComplex);
		assert(this.extGrammerComplex !is null);
		assert(this.extGrammerKind !is null);

		MapSet!(ExtendedItem,int) first = new MapSet!(ExtendedItem,int)(
			ISRType.HashTable, ISRType.HashTable);

		foreach(ExtendedItem key, bool kind; this.extGrammerKind) {
			if(!kind) {
				first.insert(key, key.getItem());
			}
		}
		bool change = true;
		size_t changeCnt = 0;
		while(change) { // as long as anything changes, continue
			//log("%d", changeCnt++);
			change = false;
			// cycle all productions
			level2: foreach(size_t idx, Deque!(ExtendedItem) it; 
					this.extGrammerComplex) {
				//log("%d %d", changeCnt, idx);
				assert(it !is null);
				assert(it.getSize() > 0);
				if(it.getSize() == 1) { // epsilon prod
					change = first.insert(it[0], -2) ? true : change;
					assert(false, "we shouldn't have epsilon productions");
					// terminal
				} else if(this.extGrammerKind.contains(it[1]) &&
						!this.extGrammerKind.find(it[1]).getData()) { 
					change = first.insert(it[0], it[1].getItem()) ? true : 
						change;
				} else { // rule 3
					Iterator!(ExtendedItem) jt = it.iterator(1);
					for(; jt.isValid(); jt++) {
						assert(*jt !is null);
						// if the nonterm only contains epsilon move to the
						// next term or nonterm
						if(*jt == it[0]) { 
							// well first(A) to first(A) makes no sense
							continue level2;
						} else if(first.containsOnly(*jt, -2)) {
							continue;
						} else if(this.extGrammerKind.contains(*jt) &&
								!this.extGrammerKind.find(*jt).getData()) {
							// found a term in the production
							change = first.insert(it[0], (*jt).getItem()) ? 
								true : change;
							continue level2;
						//} else if(!this.extGrammerKind.find(*jt).getData()) {
						//} else if(this.symbolManager.getKind(*jt)) {
						} else if(this.extGrammerKind.contains(*jt) &&
								this.extGrammerKind.find(*jt).getData()) {
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
							log();
							continue level2;
						}
					}
					change = first.insert(it[0], -2) ? true : change;
				}
			}
		}
		this.firstExtendedMS = first;
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
	ProductionManager pm = new ProductionManager(sm, false);
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
		version(DALR) {
			printfln("%d", (*it).getKey());
		}
	}
	assert(mi !is null);
	assert(mi.getData().contains(-2));

	sm = new SymbolManager();
	gp = new GrammerParser(sm);
	pm = new ProductionManager(sm, false);
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
	pm = new ProductionManager(sm, false);
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
	pm = new ProductionManager(sm, false);
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

unittest {
	Map!(size_t, Production) actions = new Map!(size_t, Production)(
		ISRType.HashTable);
	auto sm = new SymbolManager();
	auto gp = new GrammerParser(sm);
	auto pm = new ProductionManager(sm, false);
	actions.insert(pm.insertProduction(gp.processProduction("S := N")), 
		new Production("S", "N"));
	actions.insert(pm.insertProduction(gp.processProduction("N := V = E")), 
		new Production("N", "V = E"));
	actions.insert(pm.insertProduction(gp.processProduction("N := E")), 
		new Production("N", "E"));
	actions.insert(pm.insertProduction(gp.processProduction("E := V")), 
		new Production("E", "V"));
	actions.insert(pm.insertProduction(gp.processProduction("V := x")), 
		new Production("V", "x"));
	actions.insert(pm.insertProduction(gp.processProduction("V := * E")), 
		new Production("V", "* E"));
	pm.setProdMapping(actions);
	/*
	sm.checkIfPrecedenceIsCorrect(new MapSet!(int,string)(), 
		new MapSet!(int,string)(), new Set!(string)());
	auto rslt = pm.makeAll("unittest2", 0, false, false);
	version(unittest) {
		printfln("%s", finalTransitionTableToString(pm,sm));
	}*/
}

private class ExtendedWorker : Thread {
	private size_t start;
	private size_t stop;
	private Deque!(Deque!(ExtendedItem)) grammer;
	public MapSet!(ExtendedItem,int) followSets;
	public MapSet!(ExtendedItem,ExtendedItem) mapping;
	private Map!(ExtendedItem,bool) extGrammerKind;
	private Map!(ExtendedItem,Set!(int)) firstExtended;

	this(size_t start, size_t stop, Deque!(Deque!(ExtendedItem)) grammer,
			Map!(ExtendedItem,bool) extGrammerKind, 
			Map!(ExtendedItem,Set!(int)) firstExtended, 
			ExtendedItem startItem) {
		super(&run);
		this.start = start;
		this.stop = stop;
		this.grammer = grammer;
		this.extGrammerKind = extGrammerKind;
		this.firstExtended = firstExtended;

		this.followSets = new MapSet!(ExtendedItem,int)(ISRType.HashTable, 
			ISRType.HashTable);

		this.mapping = new MapSet!(ExtendedItem,ExtendedItem)(
			ISRType.HashTable, ISRType.HashTable);

		Set!(int) tmp = new Set!(int)();
		/* the first non terminal of the first prod should contain the 
		 * $ Symbol aka -1 */
		tmp.insert(-1); 
		followSets.insert(startItem, tmp);
	}

	public void run() {
		foreach(size_t idx, Deque!(ExtendedItem) it; grammer) {
			if(idx % 100 == 0) {
				log("%d of %d", idx, grammer.getSize());
			}
			foreach(size_t jdx, ExtendedItem jt; it) {
				if(jdx > 0 && jdx+1 < it.getSize()) { // rule 2
					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(jt);
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind) {
						ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets.getMap(), jt, this.firstExtended, 
							it[jdx+1]);
						//mapping.insert(it[jdx+1], jt);
					}
				}
				if((jdx+1 == it.getSize()) || 
							ProductionManager.areExtendedItemEpsilon(idx,
							jdx, grammer)) {

					MapItem!(ExtendedItem,bool) kindItem = 
						this.extGrammerKind.find(it.back());
					assert(kindItem !is null);
					bool kind = kindItem.getData();
					if(kind) {
						ProductionManager.insertFollowItems!(ExtendedItem)
							(followSets.getMap(), it.back, followSets.getMap(),
							it[0], true);
						mapping.insert(it.back, it[0]);
					}
				}
			}
		}
	}
}
