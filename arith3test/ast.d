module ast;

import hurt.container.deque;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.io.stream;
import hurt.util.pair;
import hurt.util.slog;

import token;
import parsetable;

import std.process;

struct ASTNode {
	private Token token;
	private int typ;
	private bool dummyToken;
	private Pair!(size_t,ubyte) childs;

	public this(immutable(int) typ, size_t childPos) {
		this.typ = typ;
		this.dummyToken = true;
		//this.childs = new Deque!(size_t)(16);
		this.initChilds(childPos);
	}

	public this(Token token, int typ, size_t childPos) {
		this(typ, childPos);
		this.dummyToken = false;
		this.token = token;
	}

	public this(Token token, int typ, bool dummyToken, size_t childPos) {
		this(token, typ, childPos);
		this.dummyToken = dummyToken;
	}

	private void initChilds(size_t childPos) {
		this.childs = Pair!(size_t,ubyte)(childPos,0);
	}

	private Token getToken() const {
		return this.token;
	}

	public void insert() {
		this.childs.second++;
	}

	public Pair!(size_t,ubyte) getChilds() const {
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
		ret.pushBack(format("[%s (%s)", idToString(this.typ),
			this.token.toString()));

		ret.pushBack(" ]");
		return ret.getString();
	}

	public int getTyp() const {
		return this.typ;
	}
}

class AST {
	private Deque!(ASTNode) tree;
	private Deque!(size_t) childs;

	public this(AST ast) {
		this.tree = new Deque!(ASTNode)(ast.getTree());
		this.childs = new Deque!(size_t)(ast.getChilds());
	}

	public this() {
		this.tree = new Deque!(ASTNode)(128);
		this.childs = new Deque!(size_t)(128);
	}

	Deque!(size_t) getChilds() {
		return this.childs;
	}

	Deque!(ASTNode) getTree() {
		return this.tree;
	}

	// insert a new token to the tree
	public size_t insert(Token token, int typ, bool dummyToken) { 
		this.tree.pushBack(ASTNode(token, typ, dummyToken, 
			this.childs.getSize()));
		return this.tree.getSize()-1;
	}

	public size_t insert(Token token, int typ) { 
		this.tree.pushBack(ASTNode(token, typ, this.childs.getSize()));
		return this.tree.getSize()-1;
	}

	public size_t insert(immutable(int) typ) {
		this.tree.pushBack(ASTNode(typ, this.childs.getSize()));
		return this.tree.getSize()-1;
	}

	public void append(Token token, int typ) { 
		this.tree.pushBack(ASTNode(token, typ, this.childs.getSize()));
		this.childs.pushBack(this.tree.getSize()-1);
	}

	public void append(size_t idx) { // link nodes to node
		assert(!this.tree.isEmpty());
		this.childs.pushBack(idx);
		this.tree.backRef().insert();
	}

	public override bool opEquals(Object o) @trusted {
		AST ast = cast(AST)o;
		if(ast.tree is this.tree || ast.tree != this.tree) {
			log();
			return false;
		}

		if(ast.childs is this.childs || ast.childs != this.childs) {
			log();
			return false;
		}

		return true;
	}

	public string singleNodeToString(size_t idx) {
		StringBuffer!(char) ret = new StringBuffer!(char)(
			this.tree[idx].toString());
		Pair!(size_t,ubyte) ch = this.tree[idx].getChilds();
		for(ubyte i = 0; i < ch.second; i++) {
			ret.pushBack("%d ", ch.first + i);
		}
		return ret.getString();
	}

	public string toString() const {
		StringBuffer!(char) ret = new StringBuffer!(char)(256);
		foreach(it; this.tree) {
			ret.pushBack(format("%s ", it.toString()));
		}
		ret.pushBack("\n");
		foreach(it; this.childs) {
			ret.pushBack(format("%d ", it));
		}
		return ret.getString();
	}

	public string toStringGraph() const {
		log();
		if(this.tree.isEmpty()) {
			log();
			return "()";
		}
		string ret = this.toStringGraph(this.tree.back());
		log();
		return ret;
	}

	private string toStringGraph(const ASTNode node) const {
		StringBuffer!(char) ret = new StringBuffer!(char)(128);	
		ret.pushBack("( %s %s ", idToString(node.getTyp()),
			node.getToken().toString());

		Pair!(size_t,ubyte) childs = node.getChilds();
		for(ubyte i = 0; i < childs.second; i++) {
			// do some sanity checks
			assert(this.tree.getSize() > childs.first + i);

			log("%s", this.tree[childs.first + i].toString());
			ret.pushBack("( %s )", this.toStringGraph(
				this.tree[childs.first + i]) );
		}

		ret.pushBack(')');
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
			graph.writeString(format("\"state%u\" [style = \"filled\" " ~
				"penwidth = 1 fillcolor = \"white\" " ~
				"shape = \"Mrecord\" label =<%s>];\n", idx,
				this.tree[idx].toAST()));
		}
		graph.writeString("\n");

		for(size_t idx = 0; idx < this.tree.getSize(); idx++) {
			Pair!(size_t,ubyte) child = this.tree[idx].getChilds();
			for(ubyte jdx = 0; jdx < child.second; jdx++) {
				graph.writeString(format("state%u -> state%u;\n", idx, 
					this.childs[child.first + jdx]));
			}
		}
		graph.writeString("\n");
		graph.writeString("}\n");
		graph.close();
		system("dot -T png " ~ filename ~ " > " ~ filename ~ 
			".png");
	}
}
