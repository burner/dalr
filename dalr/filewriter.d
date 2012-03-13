module dalr.filewriter;

import hurt.algo.sorting;
import hurt.io.stream;
import hurt.io.stdio;
import hurt.container.deque;
import hurt.container.map;
import hurt.conv.conv;
import hurt.string.stringbuffer;
import hurt.string.formatter;
import hurt.util.slog;
import hurt.util.pair;
import hurt.algo.sorting;

import dalr.finalitem;
import dalr.filereader;
import dalr.productionmanager;
import dalr.symbolmanager;

abstract class Writer {
	private string filename;
	private string modulename;
	private File file;
	private SymbolManager sm;
	private ProductionManager pm;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm) {
		// save the parameter
		this.filename = filename;
		this.modulename = modulename;
		this.sm = sm;
		this.pm = pm;

		// create the output file
		this.file = new File(this.filename, FileMode.OutNew);
	}

	private void writeHeader() {
		this.file.writeString(format("module %s;\n\n", this.modulename));
	}

	public void close() {
		this.file.close();
	}

	public void write();
}

class LalrWriter : Writer {
	private string classname;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm, string classname) {
		super(filename, modulename, sm, pm);
		this.classname = classname;
	}

	public override void write() {
		this.file.writeString(format(parserTemplate, this.modulename, 
			this.classname) ~ parserBody);
	}
}

final class RuleWriter : Writer {
	private bool glr;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm,
			bool glr) {
		super(filename, modulename, sm, pm);
		this.glr = glr;
	}

	public override void write() {
		this.writeHeader();	
		this.writeIncludes();	
		this.file.writeString(tableType);
		this.file.write('\n');
		this.writeTermIds();
		this.file.write('\n');
		if(!this.glr) {
			this.writeTable();
			this.file.writeString("\n");
			this.writeGotoTable();
		} else {
			this.writeGlrTable();
			this.file.writeString("\n");
			this.writeGotoGlrTable();
		}
		this.file.writeString("\n\n");
		this.writeRules();
		this.writeActions();
	}

	private void writeActions() {
		this.file.writeString("public static immutable(string) " ~
			"actionString = `");
		foreach(size_t key, Production pr; pm.getProdMapping()) {
			this.file.writeString(format("\tcase %u:\n" ~
				"\t\t%s\n\t\tbreak;\n", key, pr.getAction() is null || 
				//pr.getAction() == "" ?  "ret = Token(rules[actionNum][0]);" :
				pr.getAction() == "" ?  
				"ret = this.tokenStack[-(rules[actionNum].length-1)];" :
				pr.getAction()));
		}
		this.file.writeString("`;\n");
	}

	private static string keyWorker(string str) {
		return str == "$" ? "dollar" : str;
	}

	private void writeTermIds() {
		Map!(string,Symbol) stringSymbols = this.sm.getStringSymbols();

		foreach(string key, Symbol value; stringSymbols) {
			this.file.writeString("public static immutable int term");
			this.file.writeString(keyWorker(key));
			this.file.writeString(" = ");
			this.file.writeString(conv!(int,string)(value.getId()));
			this.file.writeString(";\n");
		}
		this.file.write('\n');
		this.writeTermIdToStringFunction(stringSymbols);
	}

	private void writeTermIdToStringFunction(Map!(string,Symbol) sym) {
		this.file.writeString("string idToString(int sym) {\n");
		this.file.writeString("\tswitch(sym) {\n");
		foreach(string key, Symbol value; sym) {
			this.file.writeString(format("\t\tcase %d:\n", value.getId()));
			this.file.writeString(format("\t\t\treturn \"%s\";\n", 
				keyWorker(key)));
		}
		this.file.writeString("\t\tcase -99:\n");
		this.file.writeString("\t\t\treturn \"whitespace\";\n");
		this.file.writeString("\t\tdefault:\n");
		this.file.writeString("\t\t\tassert(false, " ~
			"format(\"no symbol for %d present\", sym));\n");
		this.file.writeString("\t}\n}\n");
	}

	private void writeIncludes() {
		string[] imports = ["hurt.util.pair",
			"hurt.string.stringbuffer", "hurt.string.formatter",
			"hurt.conv.conv"];
		sort!(string)(imports, function(in string a, in string b) {
			return a < b;});

		foreach(string it; imports) {
			this.file.writeString("import ");
			this.file.writeString(it);
			this.file.write(';');
			this.file.write('\n');
		}
		this.file.write('\n');
		this.file.write('\n');
	}

	private string finalItemTypToTableTypeString(Type typ) {
		final switch(typ) {
			case Type.Accept:
				return "TableType.Accept";
			case Type.Error:
				assert(false, "Type Error not allowed");
			case Type.Goto:
				return "TableType.Goto";
			case Type.ItemSet:
				assert(false, "Type ItemSet not allowed");
			case Type.NonTerm:
				assert(false, "Type NonTerm not allowed");
			case Type.Reduce:
				return "TableType.Reduce";
			case Type.Shift:
				return "TableType.Shift";
			case Type.Term:
				assert(false, "Type Term not allowed");
		}
	}

	private void writeGlrTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		StringBuffer!(char) arrTmp = new StringBuffer!(char)(1024);
		sb.pushBack("alias Pair!(int,TableItem[]) TitP;\n\n");
		sb.pushBack("alias TableItem Tit;\n\n");
		sb.pushBack("public static " ~
			" immutable(immutable(immutable(TitP)[])[]) " ~
			"parseTable = \n");
		sb.pushBack("[\n");
		foreach(size_t jdx, Deque!(Deque!(FinalItem)) row; table) {
			if(jdx == 0) {
				continue;
			}

			// to sort it for the binary search
			Deque!(Pair!(int,Deque!(FinalItem))) tmp = 
				new Deque!(Pair!(int,Deque!(FinalItem)))(row.getSize()); 

			foreach(size_t jdx, Deque!(FinalItem) jt; row) {
				if(jdx == 0) { // don't need the itemset number
					continue;
				}
				tmp.pushBack(Pair!(int,Deque!(FinalItem))
					(table[0][jdx][0].number, jt));
			}

			sortDeque(tmp, function(in Pair!(int,Deque!(FinalItem)) a,
				in Pair!(int,Deque!(FinalItem)) b) {
					return a.first < b.first;
				});

			sb.pushBack('[');
			foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
				size_t cnt = it.second.count(delegate(FinalItem it) {
					return it.typ == Type.Error || it.typ == Type.Goto; });

				if(cnt == it.second.getSize()) {
					continue;
				}

				sb.pushBack("TitP(%d,", it.first);
				arrTmp.clear();
				arrTmp.pushBack('[');
				foreach(FinalItem jt; it.second) {
					if(jt.typ == Type.Error || jt.typ == Type.Goto) {
						continue;
					}
					string tmpS;
					if(jt.typ == Type.Accept) {
						tmpS = format("Tit(%s, %u)",
							finalItemTypToTableTypeString(jt.typ), 0);
					} else {
						tmpS = format("Tit(%s, %u)",
							finalItemTypToTableTypeString(jt.typ), jt.number);
					}
					if(arrTmp.getSize() % 80 + tmpS.length > 80) {
						arrTmp.pushBack('\n');
					}
					arrTmp.pushBack(tmpS);
					arrTmp.pushBack(',');
				}
				while(arrTmp.getSize() > 0 && 
						(arrTmp.peekBack() == '\n' || 
						arrTmp.peekBack() == ',')) {
					arrTmp.popBack();
				}
				arrTmp.pushBack(']');
				sb.pushBack(arrTmp.getString());
				sb.pushBack("),");
				if(sb.getSize() % 80 + sb.getSize() > 80) {
					sb.pushBack('\n');
				}
			}
			while(sb.getSize() > 0 && 
					(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
				sb.popBack();
			}
			sb.pushBack("] /* itemset %d */ ,\n\n", jdx-1);
		}
		while(sb.getSize() > 0 && 
				(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
			sb.popBack();
		}
		sb.pushBack("];\n");
		this.file.writeString(sb.getString());
	}

	private void writeGotoGlrTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		StringBuffer!(char) arrTmp = new StringBuffer!(char)(1024);
		this.file.writeString(format(
			"public static immutable(immutable(Pair!(int,TableItem[]))[])[%u])"
			~ "gotoTable = [\n", table.getSize()-1));

		foreach(size_t idx, Deque!(Deque!(FinalItem)) row; table) {
			if(idx == 0) { // don't need the items
				continue;
			}
			
			// to sort it for the binary search
			Deque!(Pair!(int,Deque!(FinalItem))) tmp = 
				new Deque!(Pair!(int,Deque!(FinalItem)))(row.getSize()); 

			foreach(size_t jdx, Deque!(FinalItem) jt; row) {
				if(jdx == 0) { // don't need the itemset number
					continue;
				}
				tmp.pushBack(Pair!(int,Deque!(FinalItem))
					(table[0][jdx][0].number, jt));
			}

			// sort it
			sortDeque(tmp, function(in Pair!(int,Deque!(FinalItem)) a,
				in Pair!(int,Deque!(FinalItem)) b) {
					return a.first < b.first;
				});

			sb.pushBack('[');
			foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
				size_t cnt = it.second.count(delegate(FinalItem it) {
					return it.typ != Type.Goto; });

				if(cnt == it.second.getSize()) {
					continue;
				}

				sb.pushBack("TitP(%d,", it.first);
				arrTmp.clear();
				arrTmp.pushBack('[');
				size_t gotoCnt = 0;
				foreach(FinalItem jt; it.second) {
					if(jt.typ != Type.Goto) {
						continue;
					}
					gotoCnt++;
					string tmpS;
					if(jt.typ == Type.Goto) {
						tmpS = format("Tit(%s, %u)",
							finalItemTypToTableTypeString(jt.typ), jt.number);
					} 

					if(arrTmp.getSize() % 80 + tmpS.length > 80) {
						arrTmp.pushBack('\n');
					}
					arrTmp.pushBack(tmpS);
					arrTmp.pushBack(',');
				}
				warn(gotoCnt > 1, "more than one goto in itemset %u", idx-1);
				while(arrTmp.getSize() > 0 && 
						(arrTmp.peekBack() == '\n' || 
						arrTmp.peekBack() == ',')) {
					arrTmp.popBack();
				}
				arrTmp.pushBack(']');
				sb.pushBack(arrTmp.getString());
				sb.pushBack("),");
				if(sb.getSize() % 80 + sb.getSize() > 80) {
					sb.pushBack('\n');
				}
			}
			while(sb.getSize() > 0 && 
					(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
				sb.popBack();
			}
			sb.pushBack("] /* itemset %d */ ,\n\n",idx-1);
		}
		while(sb.getSize() > 0 && 
				(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
			sb.popBack();
		}
		sb.pushBack("];\n");
			
		this.file.writeString(sb.getString());
		sb.clear();
	}

	private void writeTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		this.file.writeString(format(
			"public static immutable(Pair!(int,TableItem)[][%u]) " ~
			"parseTable = [\n", table.getSize()-1));
		

		size_t reduceCnt = 0;
		foreach(size_t idx, Deque!(Deque!(FinalItem)) row; table) {
			if(idx == 0) { // don't need the items
				continue;
			}
			
			// to sort it for the binary search
			Deque!(Pair!(int,Deque!(FinalItem))) tmp = 
				new Deque!(Pair!(int,Deque!(FinalItem)))(row.getSize()); 

			foreach(size_t jdx, Deque!(FinalItem) jt; row) {
				if(jdx == 0) { // don't need the itemset number
					continue;
				}
				tmp.pushBack(Pair!(int,Deque!(FinalItem))
					(table[0][jdx][0].number, jt));
			}

			// sort it
			sortDeque(tmp, function(in Pair!(int,Deque!(FinalItem)) a,
				in Pair!(int,Deque!(FinalItem)) b) {
					return a.first < b.first;
				});

			sb.pushBack('[');
			foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
				if(it.second[0].typ == Type.Error ||
						it.second[0].typ == Type.Goto) {
					continue;
				}
				reduceCnt++;
				string tmpS;
				if(it.second[0].typ == Type.Accept) { // Accept means rule 0
					tmpS = format("Pair!(int,TableItem)" ~
						"(%d,TableItem(%s, %u)), ", it.first, 
						finalItemTypToTableTypeString(it.second[0].typ), 0);
				} else {
					tmpS = format("Pair!(int,TableItem)" ~
						"(%d,TableItem(%s, %u)), ", it.first, 
						finalItemTypToTableTypeString(it.second[0].typ),
						it.second[0].number);
				}

				if(sb.getSize() + tmpS.length > 80) {
					this.file.writeString(sb.getString());
					this.file.writeString("\n");
					sb.clear();
					sb.pushBack(tmpS);
				} else {
					sb.pushBack(tmpS);
				}
			}
			if(sb.getSize() > 1) {
				sb.popBack();
				sb.popBack();
			}
			sb.pushBack(format("] /* itemset %u */,\n\n", idx-1));
			this.file.writeString(sb.getString());
			sb.clear();
			

		}
		this.file.seek(-3, SeekPos.Current);
		sb.pushBack("];\n");
			
		this.file.writeString(sb.getString());
		sb.clear();

		log("table size %d, reduceCnt %d, min %f", 
			table.getSize() * table[0].getSize(),
			reduceCnt, (cast(double)reduceCnt) / 
				(cast(double)(table.getSize() * table[0].getSize())));
	}

	private void writeGotoTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		if(this.glr) {
			this.file.writeString(format(
				"public static immutable(Pair!(int,TableItem[])[][%u]) " ~
				"gotoTable = [\n", table.getSize()-1));
		} else {
			this.file.writeString(format(
				"public static immutable(Pair!(int,TableItem)[][%u]) " ~
				"gotoTable = [\n", table.getSize()-1));
		}

		foreach(size_t idx, Deque!(Deque!(FinalItem)) row; table) {
			if(idx == 0) { // don't need the items
				continue;
			}
			
			// to sort it for the binary search
			Deque!(Pair!(int,Deque!(FinalItem))) tmp = 
				new Deque!(Pair!(int,Deque!(FinalItem)))(row.getSize()); 

			foreach(size_t jdx, Deque!(FinalItem) jt; row) {
				if(jdx == 0) { // don't need the itemset number
					continue;
				}
				tmp.pushBack(Pair!(int,Deque!(FinalItem))
					(table[0][jdx][0].number, jt));
			}

			// sort it
			sortDeque(tmp, function(in Pair!(int,Deque!(FinalItem)) a,
				in Pair!(int,Deque!(FinalItem)) b) {
					return a.first < b.first;
				});

			sb.pushBack('[');
			foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
				if(it.second[0].typ != Type.Goto) {
					continue;
				}
				string tmpS = format("Pair!(int,TableItem)" ~
					"(%d,TableItem(%s, %u)), ", it.first, 
					finalItemTypToTableTypeString(it.second[0].typ),
					it.second[0].number);

				if(sb.getSize() + tmpS.length > 80) {
					this.file.writeString(sb.getString());
					this.file.writeString("\n");
					sb.clear();
					sb.pushBack(tmpS);
				} else {
					sb.pushBack(tmpS);
				}
			}
			if(sb.getSize() > 1) {
				sb.popBack();
				sb.popBack();
			}
			sb.pushBack("],\n\n");
			this.file.writeString(sb.getString());
			sb.clear();
		}
		this.file.seek(-3, SeekPos.Current);
		sb.pushBack("];\n");
			
		this.file.writeString(sb.getString());
		sb.clear();
	}

	private void writeRules() {
		this.file.writeString(format("public static immutable(immutable(" ~
			"immutable(int)[])[%d]) rules = [\n", 
			this.pm.getProductions().getSize()));

		StringBuffer!(char) tmp = new StringBuffer!(char)(128);
		foreach(size_t idx, Deque!(int) it; this.pm.getProductions) {
			tmp.clear();
			tmp.pushBack(format("/* rule #%u */ [", idx));
			foreach(int jt; it) {
				tmp.pushBack(format("%d,", jt));
			}
			if(it.getSize() > 0) {
				tmp.popBack();
			}
			this.file.writeString(tmp.getString());
			this.file.writeString("],\n");
		}
		this.file.seek(-2, SeekPos.Current);
		this.file.writeString("];\n\n");
	}

}


private static immutable(string) tableType =
`public enum TableType : byte {
	Accept,
	Error,
	Reduce,
	Goto,
	Search,
	Shift
}

public struct TableItem {
	public TableType typ;
	public short number;
	private byte padding; // align to 32 bit

	this(bool b) {
		this.typ = TableType.Search;
		this.number = -1;
	}

	this(TableType st, short number) {
		this.typ = st;
		this.number = number;
	}

	TableType getTyp() const {
		return this.typ;
	}

	short getNumber() const {
		return this.number;
	}


	public string toString() const {
		scope StringBuffer!(char) ret = new StringBuffer!(char)(16);
		
		final switch(this.typ) {
			case TableType.Accept:
				ret.pushBack("Accept:");
				break;
			case TableType.Error:
				ret.pushBack("Error:");
				break;
			case TableType.Reduce:
				ret.pushBack("Reduce:");
				break;
			case TableType.Goto:
				ret.pushBack("Goto:");
				break;
			case TableType.Shift:
				ret.pushBack("Shift:");
				break;
		}

		ret.pushBack(conv!(short,string)(this.number));

		return ret.getString();
	}
}
`;

private immutable string parserTemplate = `
module %s;

import hurt.algo.binaryrangesearch;
import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.pair;
import hurt.util.slog;
import hurt.string.formatter;

//import ast;
//import LEXER;
import parsetable;
//import TOKEN;

class %s {
`;

private immutable string parserBody = `
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
	} 

	/** do not call this direct unless you want whitespace token
	 *  call getToken instead
	 */
	private Token getNextToken() { 
		if(this.tokenBuffer.isEmpty()) {
			this.lexer.getToken(this.tokenBuffer);
		} 
		assert(!this.tokenBuffer.isEmpty());

		return this.tokenBuffer.popFront();
	}

	private Token getToken() {
		Token t = this.getNextToken();
		while(t.getTyp() == -99) {
			t = this.getNextToken();
		}
		return t;
	}

	private TableItem getAction(const Token input) const {
		auto retError = Pair!(int,TableItem)(int.min, 
			TableItem(TableType.Error, 0));

		//log("%d %d", this.parseStack.back(), input.getTyp());

		auto toSearch = Pair!(int,TableItem)(input.getTyp(), TableItem(false));
		auto row = parseTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });

		return ret.second;
	}

	private short getGoto(const int input) const {
		auto retError = Pair!(int,TableItem)(int.min, 
			TableItem(TableType.Error, 0));

		auto toSearch = Pair!(int,TableItem)(input, TableItem(false));
		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });

		return ret.second.getNumber();
	}

	private void runAction(short actionNum) {
		Token ret;
		switch(actionNum) {
			mixin(actionString);
			default:
				assert(false, format("no action for %d defined", actionNum));
		}
		//log("%s", ret.toString());
		this.tokenStack.popBack(rules[actionNum].length-1);
		this.tokenStack.pushBack(ret);
	}

	private void printStack() const {
		printf("parse stack: ");
		foreach(it; this.parseStack) {
			printf("%d ", it);
		}
		println();
	}

	private void printTokenStack() const {
		printf("token stack: ");
		foreach(it; this.tokenStack) {
			printf("%s ", it.toStringShort());
		}
		println();
	}

	private void reportError(const Token input) const {
		printfln("%?1!1s in state %?1!1d on input %?1!1s", "ERROR", 
			this.parseStack.back(), input.toString());
		this.printStack();
	}

	public void parse() {
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		TableItem action;
		Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		while(true) { 
			//this.printStack();
			//this.printTokenStack();
			//println(this.ast.toString());
			action = this.getAction(input); 
			//log("%s", action.toString());
			if(action.getTyp() == TableType.Accept) {
				//log("%s %s", action.toString(), input.toString());
				this.parseStack.popBack(rules[action.getNumber()].length-1);
				this.runAction(action.getNumber());
				break;
			} else if(action.getTyp() == TableType.Error) {
				//log();
				this.reportError(input);
				assert(false, "ERROR");
			} else if(action.getTyp() == TableType.Shift) {
				log("%s", input.toString());
				//log();
				this.parseStack.pushBack(action.getNumber());
				this.tokenStack.pushBack(input);
				input = this.getToken();
			} else if(action.getTyp() == TableType.Reduce) {
				log();
				// do action
				// pop RHS of Production
				this.parseStack.popBack(rules[action.getNumber()].length-1);
				this.parseStack.pushBack(
					this.getGoto(rules[action.getNumber()][0]));

				// tmp token stack stuff
				this.runAction(action.getNumber());
			}
		}
		log();
		//this.printStack();
		//this.printTokenStack();
		//log("%s", this.ast.toString());
	}
}`;
