module dalr.dotfilewriter;

import dalr.item;
import dalr.itemset;
import dalr.symbolmanager;
import dalr.productionmanager;

import hurt.algo.sorting;
import hurt.container.map;
import hurt.container.mapset;
import hurt.container.isr;
import hurt.container.set;
import hurt.conv.conv;
import hurt.container.deque;
import hurt.io.stream;
import hurt.io.stdio;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.util.slog;

import std.process;

private immutable size_t longItem = 6;

private string itemsetToHTML(ItemSet iSet, Deque!(Deque!(int)) prod, 
		SymbolManager sm, bool length = true) {
	StringBuffer!(char) ret = new StringBuffer!(char)(100);	
	ret.pushBack("<table border=\"0\" cellborder=\"0\" cellpadding=\"3\" ");
	ret.pushBack("bgcolor=\"white\">\n");
  	ret.pushBack("<tr>\n");
	ret.pushBack("\t<td bgcolor=\"black\" align=\"center\" colspan=\"2\">");
	ret.pushBack("<font color=\"white\">State #");
	ret.pushBack(conv!(long,string)(iSet.getId()));
	ret.pushBack("</font></td>\n</tr>\n");

	sortDeque!(Item)(iSet.getItems(), 
		function(in Item l, in Item r) { 
			return l.getProd() < r.getProd(); 
		});

	foreach(size_t idx, Item it; iSet.getItems()) {
		if(length && idx > longItem) {
			break;
		}
		ret.pushBack("<tr>\n");
		ret.pushBack("\t<td align=\"left\" port=\"r");
		ret.pushBack(conv!(ulong,string)(it.getProd()));
		ret.pushBack("\">&#40;");
		ret.pushBack(conv!(ulong,string)(it.getProd()));
		ret.pushBack("&#41; ");
		//l -&gt; &bull;'*' r 
		foreach(size_t idx, int pro; prod[it.getProd]) {
			if(idx == 0) {
				ret.pushBack(sm.getSymbolName(pro));
				ret.pushBack(" -&gt; ");
			} else if(idx == it.getDotPosition()) {
				ret.pushBack("&bull;");
				ret.pushBack(sm.getSymbolName(pro));
				ret.pushBack(" ");
			} else {
				ret.pushBack(sm.getSymbolName(pro));
				ret.pushBack(" ");
			}
		}
		ret.popBack();
		if(prod[it.getProd()].getSize() == it.getDotPosition()) {
			ret.pushBack("&bull;");
		}

		ret.pushBack("</td>\n</tr>\n");
	}
  	ret.pushBack("</table>");
	return ret.getString();
}

private string makeTransitions(ItemSet iSet, SymbolManager sm, 
		Set!(ItemSet) exists) {
	StringBuffer!(char) ret = new StringBuffer!(char)(1000);
	ISRIterator!(MapItem!(int,ItemSet)) it = iSet.getFollowSet().begin();
	for(; it.isValid(); it++) {
		if(!exists.contains((*it).getData())) {
			continue;
		}
		ret.pushBack("state");
		ret.pushBack(conv!(long,string)(iSet.getId()));
		ret.pushBack(" -> "); 
		ret.pushBack("state");
		ret.pushBack(conv!(long,string)((*it).getData().getId()));
		ret.pushBack(" [ ");
		if(sm.getKind((*it).getKey())) {
			ret.pushBack("penwidth = 5 fontsize = 28 fontcolor = ");
			ret.pushBack("\"black\" label = \"");
			ret.pushBack(sm.getSymbolName((*it).getKey()));
			ret.pushBack("\"];\n");
		} else {
			ret.pushBack("penwidth = 1 fontsize = 20 fontcolor = \"grey28\"");
			ret.pushBack(" label = \"'");
			ret.pushBack(sm.getSymbolName((*it).getKey()));
			ret.pushBack("'\"];\n");
		}
	}
	return ret.getString();
}

private string makeTransitions(ItemSet iSet, SymbolManager sm) {
	StringBuffer!(char) ret = new StringBuffer!(char)(1000);
	ISRIterator!(MapItem!(int,ItemSet)) it = iSet.getFollowSet().begin();
	for(; it.isValid(); it++) {
		ret.pushBack("state");
		ret.pushBack(conv!(long,string)(iSet.getId()));
		ret.pushBack(" -> "); 
		ret.pushBack("state");
		ret.pushBack(conv!(long,string)((*it).getData().getId()));
		ret.pushBack(" [ ");
		if(sm.getKind((*it).getKey())) {
			ret.pushBack("penwidth = 5 fontsize = 28 fontcolor = ");
			ret.pushBack("\"black\" label = \"");
			ret.pushBack(sm.getSymbolName((*it).getKey()));
			ret.pushBack("\"];\n");
		} else {
			ret.pushBack("penwidth = 1 fontsize = 20 fontcolor = \"grey28\"");
			ret.pushBack(" label = \"'");
			ret.pushBack(sm.getSymbolName((*it).getKey()));
			ret.pushBack("'\"];\n");
		}
	}
	return ret.getString();
}

private Deque!(ItemSet) copyDeque(Deque!(ItemSet) de) {
	Deque!(ItemSet) ret = new Deque!(ItemSet)();
	foreach(size_t idx, ItemSet it; de) {
		log("%d",idx);
		ret.pushBack(it.copy());
	}
	assert(ret == de);
	return ret;
}

private bool isContainedComplete(ItemSet a, ItemSet b) {
	// a must be small or equal in size
	if(b.getItemCount() < a.getItemCount()) {
		//log();
		return false;
	}
	foreach(Item it; a.getItems()) {
		if(!b.getItems().contains(it)) {
			return false;
		}
	}
	Map!(int,ItemSet) mapA = a.getFollowSet();
	Map!(int,ItemSet) mapB = b.getFollowSet();
	ISRIterator!(MapItem!(int,ItemSet)) it = mapA.begin();
	for(; it.isValid(); it++) {
		if(!mapB.contains((*it).getKey())) {
			log("%d", (*it).getKey());

			ISRIterator!(MapItem!(int,ItemSet)) jt = mapB.begin();
			for(; jt.isValid(); jt++) {
				printf("%d:%d, ", (*jt).getKey(), (*jt).getData().getId());
			}
			println();
			assert(false);
		}
	}
	
	return true;
}

private MapSet!(ItemSet,ItemSet) minItemSets(Deque!(ItemSet) de, 
		ProductionManager pm) {
	MapSet!(ItemSet,ItemSet) ret = new MapSet!(ItemSet,ItemSet)();

	// sort it so you can process the list from big to small
	sortDeque!(ItemSet)(de, function(in ItemSet a, in ItemSet b) {
		return a.getItemCount() > b.getItemCount(); });

	debug { // sanity check that the sorting is right
		foreach(size_t idx, ItemSet it; de) {
			if(idx > 0) {
				assert(it.getItemCount() <= de[idx-1].getItemCount(),
					format("idx-1 size %d idx size %d", 
					de[idx-1].getItemCount(), de[idx].getItemCount()));
			}
		}
	}
	foreach(size_t idx, ItemSet it; de) {
		//log("%d", it.getItemCount());
		Set!(Item) removed = new Set!(Item)();
		ret.insert(it,it);
		foreach(size_t jdx, ItemSet jt; de) {
			//log("%d %d", it.getItemCount(), jt.getItemCount());
			if(jdx <= idx) {
				continue;
			}
			if(it.getItemCount() == 1) {
				break;
			}
			// are all items of jt contained in it
			if(isContainedComplete(jt, it)) {
				log("%d is contained in %d sizes are %u %u", jt.getId(), 
					it.getId(), jt.getItemCount(), it.getItemCount());


				size_t oldSize = it.getItemCount();
				size_t removeCnt = 0;
				foreach(size_t toRemoveIdx, Item toRemove; jt.getItems()) {
					int followSymbol;
					if(pm.isDotAtEndOfProduction(toRemove)) {
						followSymbol = int.max;
					} else {
 						followSymbol = pm.getSymbolFromProduction(toRemove);
					}

					//log("%d toRemoveIdx %d followSymbol", toRemoveIdx, 
					//followSymbol);
					// remove the item TODO ignore the assert failure for now
					if(!it.removeItem(toRemove, followSymbol) && 
							!removed.contains(toRemove)) {
						foreach(Item kt; it.getItems()) {
							printf("%d, ", kt.toHash());
						}
						printfln("\nsearched %d", toRemove.toHash());
						//assert(false);
					}
					removed.insert(toRemove);
				}
				ret.insert(it,jt);
				/*assert(it.getItemCount() == (oldSize - jt.getItemCount()), 
					format("newsize %u, expected %u", it.getItemCount(), 
					(oldSize - jt.getItemCount())));
				TODO ignore this assert failure as well*/
			}
		}
	}

	return ret;
}

public void writeLR0GraphAround(Deque!(ItemSet) de, SymbolManager sm, 
		Deque!(Deque!(int)) prod, string filename, ProductionManager pm, 
		int around) {
	hurt.io.stream.File file = new hurt.io.stream.File(filename ~ ".dot", 
		FileMode.OutNew);

	ItemSet a = null;
	foreach(it; de) {
		if(it.getId() == around) {
			a = it;
			break;
		}
	}
	assert(a !is null);

	Deque!(ItemSet) conn = new Deque!(ItemSet)(de.getSize());
	conn.pushBack(a);

	for(auto it = a.getFollowSet().begin(); it.isValid(); it++) {
		conn.pushBack((*it).getData());	
	}
	foreach(it; de) {
		if(it.goesToId(around)) {
			conn.pushBack(it);
		}
	}

	Set!(ItemSet) processed = new Set!(ItemSet)(ISRType.HashTable);
	StringBuffer!(char) sb = new StringBuffer!(char)(1000);
	file.writeString("digraph g {\n");
	file.writeString("graph [fontsize=30 labelloc=\"t\" label=\"\" ");
	file.writeString("splines=true overlap=false rankdir = \"LR\"];\n");
	file.writeString("ratio = auto;\n");
	foreach(size_t idx, ItemSet iSet; conn) {
		file.writeString("\"state");
		file.writeString(conv!(long,string)(iSet.getId()));
		file.writeString("\" ");
		file.writeString("[ style = \"filled\" penwidth = 1 fillcolor = ");
		file.writeString("\"white\"");
		file.writeString(" fontname = \"Courier New\" shape = \"Mrecord\" ");
		file.writeString("label =<");
		file.writeString(itemsetToHTML(iSet, prod, sm));
		file.writeString("> ];\n");
		processed.insert(iSet);
	}
	ISRIterator!(ItemSet) iSet = processed.begin();
	for(; iSet.isValid(); iSet++) {
		file.writeString(makeTransitions(*iSet, sm, processed));
	}

	file.writeString("}\n");
	file.close();
	system("dot -T png " ~ filename ~ ".dot > " ~ filename ~ ".png &disown");
}

public void writeLR0Graph(Deque!(ItemSet) de, SymbolManager sm, 
		Deque!(Deque!(int)) prod, string filename, ProductionManager pm) {
	size_t numItems = 0;
	foreach(ItemSet it; de) {
		numItems += it.getItemCount();
	}
	size_t average = numItems / de.getSize();
	log("%u %u",numItems, average);

	hurt.io.stream.File file = new hurt.io.stream.File(filename ~ ".dot", 
		FileMode.OutNew);

	Set!(ItemSet) rank = new Set!(ItemSet)(ISRType.HashTable);
	Set!(ItemSet) processed = new Set!(ItemSet)(ISRType.HashTable);
	numItems = 0;
	size_t level = 0;
	StringBuffer!(char) sb = new StringBuffer!(char)(1000);
	file.writeString("digraph g {\n");
	file.writeString("graph [fontsize=30 labelloc=\"t\" label=\"\" ");
	file.writeString("splines=true overlap=false rankdir = \"LR\"];\n");
	file.writeString("ratio = auto;\n");
	foreach(size_t idx, ItemSet iSet; de) {
		file.writeString("\"state");
		file.writeString(conv!(long,string)(iSet.getId()));
		file.writeString("\" ");
		file.writeString("[ style = \"filled\" penwidth = 1 fillcolor = ");
		file.writeString("\"white\"");
		file.writeString(" fontname = \"Courier New\" shape = \"Mrecord\" ");
		file.writeString("label =<");
		file.writeString(itemsetToHTML(iSet, prod, sm));
		file.writeString("> ];\n");
		rank.insert(iSet);
		/*numItems += iSet.getItemCount();
		if(numItems >= average) {
			// the pseudolevel
			file.writeString("\"level");
			file.writeString(conv!(long,string)(level));
			file.writeString("\" [style=invis]\n");

			if(level > 0) { // the pseudo transistion
				file.writeString(format("level%u -> level%u [style=invis]\n", level-1, level));
			}
			file.writeString(format("{ rank=same; \"level%u\"; ", level));
			ISRIterator!(ItemSet) it = rank.begin();
			for(; it.isValid(); it++) {
				file.writeString(format("\"state%u\"; ",(*it).getId()));
			}
			file.writeString("}\n");
			level++;
			rank.clear();
			numItems = 0;*/
			if(idx > 100) {
				break;
			}
		//}
		processed.insert(iSet);
	}
	ISRIterator!(ItemSet) iSet = processed.begin();
	for(; iSet.isValid(); iSet++) {
		file.writeString(makeTransitions(*iSet, sm));
	}

	/*foreach(size_t idx, ItemSet iSet; de) {
		file.writeString(makeTransitions(iSet, sm));
	}*/
	file.writeString("}\n");
	file.close();
	system("dot -T png " ~ filename ~ ".dot > " ~ filename ~ ".png &disown");
}
