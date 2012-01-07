module dalr.tostring;

import dalr.finalitem;
import dalr.item;
import dalr.itemset;
import dalr.extendeditem;
import dalr.productionmanager;
import dalr.mergedreduction;
import dalr.symbolmanager;

import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.conv.conv;
import hurt.container.deque;
import hurt.container.isr;
import hurt.container.set;
import hurt.container.map;
import hurt.util.pair;

public string extFollowRulesToString(ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) tmp = new StringBuffer!(char)(256);
	Deque!(string) ruleString = new Deque!(string)(16);
	Deque!(string) ruleFollow = new Deque!(string)(16);
	size_t maxRuleLen = 0;
	size_t maxFollowLen = 0;
	foreach(size_t idx, Pair!(Deque!(ExtendedItem),Set!(int)) it; 
			pm.getExtGrammerFollow()) {

		// the extended rule to string
		ruleString.pushBack(extendedGrammerItemRuleToString(it.first, pm, sm));

		// for each follow symbol create string
		tmp.clear();
		tmp.pushBack("{");

		ISRIterator!(int) jt = it.second.begin();
		for(; jt.isValid(); jt++) {
			tmp.pushBack(sm.getSymbolName(*jt));	
			tmp.pushBack(' ');
		}
		if(tmp.getSize() > 1) {
			tmp.popBack();
		}
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

private size_t longestProduction(ProductionManager pm, SymbolManager sm) {
	size_t ret = 0;
	foreach(Deque!(int) it; pm.getProd()) {
		size_t tmp = 0;
		foreach(int jt; it) {
			tmp = tmp + sm.getSymbolName(jt).length + 1;
		}
		ret = tmp > ret ? tmp : ret;
	}
	assert(ret > 0);
	return ret;
}

public string mergedExtendedToString(ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(256);
	ISRIterator!(MapItem!(size_t, MergedReduction)) it = 
		pm.getMergedExtended().begin();
	string followSymbolFormat = "%" 
		~ conv!(size_t,string)(sm.longestItem()) ~ "s";

	for(; it.isValid(); it++) {
		// the itemset is stored in the key
		ret.pushBack(format("%u\n", (*it).getKey()));
		Map!(int, Set!(size_t)) theFollowMapSet = (*it).getData().
			getFollowMap();

		ISRIterator!(MapItem!(int, Set!(size_t))) jt = theFollowMapSet.
			begin();
		for(; jt.isValid(); jt++) {
			// the input symbol
			ret.pushBack(format(followSymbolFormat, 
				sm.getSymbolName((*jt).getKey())));

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
				ret.pushBack(productionToString(pm.getProd()[*kt], sm));
				ret.pushBack("\n");
			}
		}
	}
	return ret.getString();
}

public string finalTransitionTableToString(ProductionManager pm, 
		SymbolManager sm) {
	Deque!(Deque!(Deque!(FinalItem))) fi = pm.getFinalTable();	
	Deque!(Deque!(string)) tmp = new Deque!(Deque!(string))(fi.getSize());

	// for alignment of the table
	size_t maxLength = 0;

	// tmp row, this is later inserted into fi
	foreach(size_t idx, Deque!(Deque!(FinalItem)) it; fi) {
		Deque!(string) row = new Deque!(string)(32);
		// top row, simple because the third dimension should allways be
		// one item long
		if(idx == 0) {
			foreach(Deque!(FinalItem) jt; it) {
				assert(jt.getSize() == 1, format("%u", jt.getSize()));
				// find the corner
				if(jt[0].typ == Type.ItemSet && jt[0].number == -1) {
					row.pushBack("ItemSet");
				} else if(jt[0].typ == Type.Term || 
						jt[0].typ == Type.NonTerm) {
					row.pushBack(sm.getSymbolName(jt[0].number));
				} else {
					assert(false, "You shouldn't have reached this");
				}
				maxLength = row.back().length > maxLength ? 
					row.back().length : maxLength;
			}
			tmp.pushBack(row);
		} else {
			foreach(size_t jdx, Deque!(FinalItem) jt; it) {
				assert(jt.getSize() > 0, format("%u", jt.getSize()));
				if(jdx == 0) {
					assert(jt.getSize() == 1 && jt[0].typ == 
						Type.ItemSet);
					row.pushBack(conv!(int,string)(jt[0].number));
				} else {
					// for every normal entry
					StringBuffer!(char) sTmp = new StringBuffer!(char)(16);
					foreach(FinalItem gt; jt) {
						if(gt.typ == Type.Accept) {
							sTmp.pushBack("$");
						} else if(gt.typ == Type.Shift) {
							sTmp.pushBack(format("s%d,", gt.number));
						} else if(gt.typ == Type.Reduce) {
							sTmp.pushBack(format("r%d,", gt.number));
						} else if(gt.typ == Type.Goto) {
							sTmp.pushBack(format("g%d,", gt.number));
						}
					}
					if(sTmp.getSize() > 0) {
						sTmp.popBack();
						row.pushBack(sTmp.getString());
					} else {
						row.pushBack(" ");
					}

				}
				maxLength = row.back().length > maxLength ? 
					row.back().length : maxLength;
			}
			tmp.pushBack(row);
		}
	}
	debug { // every row must have the same size
		assert(tmp.getSize() > 0);
		size_t unionSize = tmp[0].getSize();
		foreach(Deque!(string) it; tmp) {
			assert(it.getSize() == unionSize);
		}
		assert(maxLength >= "ItemSet".length, format("%u", maxLength));
	}

	// make the return string
	StringBuffer!(char) ret = new StringBuffer!(char)(tmp.getSize() *
		tmp[0].getSize() * maxLength);
	string formatString = "%" ~ conv!(size_t,string)(maxLength+1) ~ "s";
	
	// for every row
	foreach(Deque!(string) it; tmp) {
		// for every item in every row
		foreach(string jt; it) {
			ret.pushBack(format(formatString, jt));
		}
		// a line done
		ret.pushBack("\n");
	}
	ret.pushBack("\n");


	return ret.getString();
}

public string transitionTableToString(ProductionManager pm, SymbolManager sm) {
	Deque!(Deque!(int)) table = pm.getTranslationTable();
	StringBuffer!(char) ret = new StringBuffer!(char)(
		table.getSize() * table[0].getSize() * 3);

	// For every 10 states the length of the output per item must be
	// increased by one so no two string occupy the same space.
	size_t size = "ItemSet".length;

	foreach(size_t i, Deque!(int) it; table) {
		foreach(size_t j, int jt; it) {
			if(i == 0 && j > 0 && sm.getSymbolName(jt).length > size) {
				size = sm.getSymbolName(jt).length;
			} 
		}
	}
	
	// create the table
	immutable string stringFormat = "%" ~ conv!(size_t,string)(size) 
		~ "s";
	immutable string longFormat = "%" ~ conv!(size_t,string)(size) 
		~ "d";
	immutable string inputFormat = "%" ~ conv!(size_t,string)(size) 
		~ "s";
	ret.pushBack(format(inputFormat, "ItemSet"));
	// their might be multiple items in a single cell (conflicts), this 
	// leads to the extra foreach loop
	StringBuffer!(char) tStrBuf = new StringBuffer!(char)(size);
	foreach(size_t i, Deque!(int) it; table) {
		foreach(size_t j, int jt; it) {
			if(i == 0) {
				ret.pushBack(format(stringFormat, sm.getSymbolName(jt)));
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
	
	ret.pushBack("\n");
	return ret.getString();
}

public string extendedFirstSetToString(ProductionManager pm, SymbolManager sm) {
	return extendedTSetToString!("First")(pm.getFirstExtended(), sm);
}

public string extendedFollowSetToString(ProductionManager pm, 
		SymbolManager sm) {
	return extendedTSetToString!("Follow")(pm.getFollowExtended(), sm);
}

private string extendedTSetToString(string type)(Map!(ExtendedItem, 
		Set!(int)) map, SymbolManager sm) {
	ISRIterator!(MapItem!(ExtendedItem, Set!(int))) it = map.begin();
	StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
	for(size_t idx = 0; it.isValid(); idx++, it++) {
		sb.pushBack(type);
		sb.pushBack(format("(%s%s%s) = {", 
			(*it).getKey().getLeft() == -1 ? "$" : 
			conv!(int,string)((*it).getKey().getLeft()),
			productionItemToString((*it).getKey().getItem(), sm), 
			(*it).getKey().getRight() == -1 ? "$" : 
			conv!(int,string)((*it).getKey().getRight())));
		ISRIterator!(int) jt = (*it).getData().begin();
		int cnt = 0;
		for(; jt.isValid(); jt++) {
			cnt++;
			sb.pushBack(productionItemToString(*jt, sm));
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

public string normalFollowSetToString(ProductionManager pm, SymbolManager sm) {
	return normalFollowSetToString(pm.getFollowNormal(), sm);
}

private string normalFollowSetToString(Map!(int, Set!(int)) map, 
		SymbolManager sm) {
	ISRIterator!(MapItem!(int, Set!(int))) it = map.begin();
	StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
	for(size_t idx = 0; it.isValid(); it++) {
		sb.pushBack("Follow(");
		sb.pushBack(productionItemToString((*it).getKey(), sm));
		sb.pushBack(") = {");
		ISRIterator!(int) jt = (*it).getData().begin();
		int cnt = 0;
		for(; jt.isValid(); jt++) {
			cnt++;
			sb.pushBack(productionItemToString(*jt, sm));
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

public string normalFirstSetToString(ProductionManager pm, SymbolManager sm) {
	return normalFirstSetToString(pm.getFirstNormal(), sm);
}

private string normalFirstSetToString(Map!(int, Set!(int)) map,
		SymbolManager sm) {
	ISRIterator!(MapItem!(int, Set!(int))) it = map.begin();
	StringBuffer!(char) sb = new StringBuffer!(char)(map.getSize() * 20);
	for(size_t idx = 0; it.isValid(); it++) {
		sb.pushBack("First(");
		sb.pushBack(productionItemToString((*it).getKey(), sm));
		sb.pushBack(") = {");
		ISRIterator!(int) jt = (*it).getData().begin();
		int cnt = 0;
		for(; jt.isValid(); jt++) {
			cnt++;
			sb.pushBack(productionItemToString(*jt, sm));
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

public string normalProductionToString(ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) sb = new StringBuffer!(char)(
		pm.getProd().getSize() * 10);
	foreach(size_t idx, Deque!(int) pro; pm.getProd()) {
		sb.pushBack(conv!(size_t,string)(idx));
		sb.pushBack(": ");
		sb.pushBack(productionToString(pro,sm));
	}
	return sb.getString();
}

public string productionToString(Deque!(int) pro, SymbolManager sm) {
	assert(pro.getSize() > 0);
	StringBuffer!(char) sb = new StringBuffer!(char)(pro.getSize() * 4);
	foreach(idx, it; pro) {
		sb.pushBack(productionItemToString(it,sm));
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

public string productionItemToString(const int item, SymbolManager sm) {
	if(item == -1) {
		return "$";
	} else if(sm is null) {
		return conv!(int,string)(item);
	} else {
		return sm.getSymbolName(item);
	}
}

private string itemToString(const Item item, ProductionManager pm, 
		SymbolManager sm) {
	Deque!(int) de = pm.getProduction(item.getProd());	
	StringBuffer!(char) ret = new StringBuffer!(char)(de.getSize()*4);
	foreach(size_t idx, int it; de) {
		if(idx == 0) {
			ret.pushBack(productionItemToString(it, sm));
			ret.pushBack(" -> ");
			continue;
		}
		if(idx == item.getDotPosition()) {
			ret.pushBack(".");
			ret.pushBack(productionItemToString(it, sm));
		} else {
			ret.pushBack(productionItemToString(it, sm));
		}
		ret.pushBack(" ");
	}
	ret.popBack();
	if(de.getSize() == item.getDotPosition()) {
		ret.pushBack(".");
	}
	return ret.getString();
}

private string itemsetToString(ItemSet iSet, ProductionManager pm, 
		SymbolManager sm) {
	StringBuffer!(char) sb = new StringBuffer!(char)();
	foreach(Item it; iSet.getItems()) {
		sb.pushBack(itemToString(it, pm, sm));
		sb.pushBack('\n');
	}
	sb.pushBack('\n');
	return sb.getString();
}

public string itemsetsToString(ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) sb = 
		new StringBuffer!(char)(pm.getItemSet().getSize() * 10);

	Iterator!(ItemSet) it = pm.getItemSet().begin();
	for(size_t idx = 0; it.isValid(); idx++, it++) {
		sb.pushBack(conv!(ulong,string)(idx));
		sb.pushBack('\n');
		sb.pushBack(itemsetToString(*it, pm, sm));
	}
	return sb.getString();
}

public string extendedGrammerItemsToString(ProductionManager pm,
		SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(128);
	foreach(size_t idx, Deque!(ExtendedItem) it; pm.getExtGrammerComplex()) {
		ret.pushBack(format("%2d: ", idx));
		ret.pushBack(extendedGrammerItemRuleToString(it, pm, sm));
		ret.pushBack("\n");
	}
	return ret.getString();
}

public string extendedGrammerItemRuleToString(Deque!(ExtendedItem) pro,
		ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(pro.getSize() * 4);
	foreach(idx, it; pro) {
		if(idx == 1) {
			ret.pushBack("-> ");
		}
		ret.pushBack(it.getLeft() != -1 ? conv!(int,string)(it.getLeft())
			: "$");
		ret.pushBack(sm.getSymbolName(it.getItem()));
		ret.pushBack(it.getRight() != - 1 ? 
			conv!(int,string)(it.getRight()) : 
			"$");
		ret.pushBack(" ");
	}
	return ret.getString();
}

public string extendedGrammerToString(ProductionManager pm, SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(128);
	foreach(Deque!(int) it; pm.getExtGrammer()) {
		ret.pushBack(extendedGrammerRuleToString(it, pm, sm));
		ret.pushBack("\n");
	}
	return ret.getString();
}

public string extendedGrammerItemToString(ProductionManager pm,
		SymbolManager sm, ExtendedItem ei) {
	return format("%d%s%d", ei.getLeft(), sm.getSymbolName(ei.getItem),
		ei.getRight());
}

public string extendedGrammerRuleToString(Deque!(int) pro, ProductionManager pm,
		SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(pro.getSize() * 4);
	for(size_t idx = 0; idx < 3; idx++) {
		if(idx % 2 == 0) {
			if(pro[idx] == -1) 
				ret.pushBack('$');
			else
				ret.pushBack(conv!(int,string)(pro[idx]));
		} else {
			ret.pushBack(sm.getSymbolName(pro[idx]));
		}
	}
	ret.pushBack(" -> ");
	for(size_t idx = 3; idx < pro.getSize(); idx++) {
		if(idx % 2 == 1) {
			if(pro[idx] == -1) 
				ret.pushBack('$');
			else
				ret.pushBack(conv!(int,string)(pro[idx]));
		} else {
			ret.pushBack(sm.getSymbolName(pro[idx]));
		}
	}
	return ret.getString();
}
