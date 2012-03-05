module ast;

import hurt.container.deque;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.io.stream;

import token;
import parsetable;

import std.stdio;

struct ASTNode {
	private Token token;
	private int typ;
	private bool dummyToken;
	private Deque!(size_t) childs;

	this(immutable(int) typ) {
		this.typ = typ;
		this.dummyToken = false;
		this.childs = new Deque!(size_t)(16);
	}

	this(Token token, int typ) {
		this(typ);
		this.token = token;
	}

	this(Token token, int typ, bool dummyToken) {
		this(token, typ);
		this.dummyToken = dummyToken;
	}

	public void insert(size_t idx) {
		this.childs.pushBack(idx);
	}

	const(Deque!(size_t)) getChilds() const {
		return this.childs;
	}

	public string toAST() const {
		auto ret = new StringBuffer!(char)(128);
		ret.pushBack("<table border=\"0\" cellborder=\"0\" cellpadding=\"3\" ");
		ret.pushBack("bgcolor=\"white\">\n");
		ret.pushBack("<tr>\n");
		ret.pushBack("\t<td bgcolor=\"black\" align=\"center\" colspan=\"2\">");
		ret.pushBack("<font color=\"white\">");
		ret.pushBack(idToString(this.typ));
		ret.pushBack("</font></td>\n</tr>\n");
		if(!this.dummyToken) {
			ret.pushBack(format("<tr><td align=\"left\">Token</td><td " ~
				"align=\"right\">%s</td></tr>\n",
				idToString(this.token.getTyp())));
			if(!this.token.getLoc().isDummyLoc()) {
				ret.pushBack(format("<tr><td align=\"left\">Loc</td><td " ~
				"align=\"right\">%s</td></tr>\n",
					this.token.getLoc().toString()));
			}
			if(this.token.getValue() !is null && this.token.getValue() != "") {
				ret.pushBack(format("<tr><td align=\"left\">Value</td><td " ~
				"align=\"right\">%s</td></tr>\n", this.token.getValue()));
			}
		}
		ret.pushBack("</table>");
		return ret.getString();
	}

	public string toString() const {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);
		ret.pushBack(format("[%s (%s) {", idToString(this.typ),
			this.token.toString()));

		foreach(it; this.childs) {
			ret.pushBack(format("%u,", it));
		}
		ret.popBack();
		if(this.childs.getSize() == 0) {
			ret.popBack();
		} else {
			ret.pushBack("}");
		}
		ret.pushBack(" ]");
		return ret.getString();
	}

	public int getTyp() const {
		return this.typ;
	}
}

class AST {
	private Deque!(ASTNode) tree;

	this() {
		this.tree = new Deque!(ASTNode)(128);
	}

	// insert a new token to the tree
	public size_t insert(Token token, int typ, bool dummyToken) { 
		this.tree.pushBack(ASTNode(token, typ, dummyToken));
		return this.tree.getSize()-1;
	}

	public size_t insert(Token token, int typ) { 
		this.tree.pushBack(ASTNode(token, typ));
		return this.tree.getSize()-1;
	}

	public size_t insert(immutable(int) typ) {
		this.tree.pushBack(ASTNode(typ));
		return this.tree.getSize()-1;
	}

	public void append(size_t idx) { // link nodes to node
		assert(!this.tree.isEmpty());
		this.tree.backRef().insert(idx);
	}

	public string toString() const {
		StringBuffer!(char) ret = new StringBuffer!(char)(256);
		foreach(it; this.tree) {
			ret.pushBack(format("%s ", it.toString()));
		}
		return ret.getString();
	}

	public void toGraph(string filename) const {
		hurt.io.stream.File graph = 
			new hurt.io.stream.File(filename, FileMode.OutNew);
		graph.writeString("digraph g {\n");
		graph.writeString("graph [fontsize=30 labelloc=\"t\" label=\"\" ");
		graph.writeString("splines=true overlap=false];\n");
		graph.writeString("ratio = auto;\n");
		for(size_t idx = 0; idx < this.tree.getSize(); idx++) {
			writeln(this.tree[idx].toString());
			graph.writeString(format("\"state%u\" [style = \"filled\" " ~
				"penwidth = 1 fillcolor = \"white\" fontname = " ~
				"\"Courier\" shape = \"Mrecord\" label =<%s>];\n", idx,
				this.tree[idx].toAST()));
		}
		graph.writeString("\n");

		for(size_t idx = 0; idx < this.tree.getSize(); idx++) {
			const(Deque!(size_t)) childs = this.tree[idx].getChilds();
			for(size_t jdx = 0; jdx < childs.getSize(); jdx++) {
				graph.writeString(format("state%u -> state%u;\n", idx, 
					childs[jdx]));
			}
		}
		graph.writeString("\n");
		graph.writeString("}\n");
		graph.close();
	}
}
