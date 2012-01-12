module dalr.dotfilewriter;

import dalr.item;
import dalr.itemset;
import dalr.symbolmanager;

import hurt.algo.sorting;
import hurt.container.map;
import hurt.container.isr;
import hurt.conv.conv;
import hurt.container.deque;
import hurt.io.stream;
import hurt.io.stdio;
import hurt.string.stringbuffer;

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
			ret.pushBack(".");
		}

		ret.pushBack("</td>\n</tr>\n");
	}
  	ret.pushBack("</table>");
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

public void writeLR0Graph(Deque!(ItemSet) de, SymbolManager sm, 
		Deque!(Deque!(int)) prod, string filename) {

	hurt.io.stream.File file = new hurt.io.stream.File(filename ~ ".dot", 
		FileMode.OutNew);

	Deque!(ItemSet) toLong = new Deque!(ItemSet)();

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
		// everything long than longItem will be printed completly later
		if(iSet.getItems().getSize() > longItem) {
			toLong.pushBack(iSet);
		}
	}

	foreach(size_t idx, ItemSet iSet; toLong) {
		file.writeString("\"longState");
		file.writeString(conv!(long,string)(iSet.getId()));
		file.writeString("\" ");
		file.writeString("[ style = \"filled\" penwidth = 1 fillcolor = ");
		file.writeString("\"white\"");
		file.writeString(" fontname = \"Courier New\" shape = \"Mrecord\" ");
		file.writeString("label =<");
		file.writeString(itemsetToHTML(iSet, prod, sm, false));
		file.writeString("> ];\n");
		// everything long than longItem will be printed completly later
		if(iSet.getItems().getSize() > longItem) {
			toLong.pushBack(iSet);
		}
	}
	foreach(size_t idx, ItemSet iSet; de) {
		file.writeString(makeTransitions(iSet, sm));
	}
	file.writeString("}\n");
	file.close();
	system("dot -T png " ~ filename ~ ".dot > " ~ filename ~ ".png &disown");
}
