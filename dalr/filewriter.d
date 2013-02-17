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

class GlrWriter : Writer {
	private string classname;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm, string classname) {
		super(filename, modulename, sm, pm);
		this.classname = classname;
	}

	public override void write() {
		//log();
		this.file.writeString(format("module %s;", this.modulename));
		//log();
		this.file.writeString(glrParserTemplate);
		//log();
		this.file.writeString(format("public class %s;", this.classname));
		//log();
		this.file.writeString(glrParserTemplate2);
		//log();
	}
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
		sb.pushBack("alias Pair!(int,immutable(TableItem[])) TitP;\n\n");
		sb.pushBack("alias TableItem Tit;\n\n");
		sb.pushBack("public static immutable(immutable(TitP[])[]) " ~
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
			foreach(size_t idx, Pair!(int,Deque!(FinalItem)) it; tmp) {
				size_t cnt = it.second.count(delegate(FinalItem it) {
					return it.typ == Type.Error || it.typ == Type.Goto; });

				if(cnt == it.second.getSize()) {
					continue;
				}

				sb.pushBack("TitP(%d,", it.first);
				arrTmp.clear();
				arrTmp.pushBack('[');
				foreach(size_t jdx, FinalItem jt; it.second) {
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
					if(jdx+1 < it.second.getSize()) {
						arrTmp.pushBack(',');
					}
				}
				//log("%s", arrTmp.getString());
				/*while(arrTmp.getSize() > 0 && 
						(arrTmp.peekBack() == '\n' || arrTmp.peekBack() == ','))
						{
					//log("%u %c", arrTmp.getSize(), arrTmp.peekBack());
					arrTmp.popBack();
				}*/
				arrTmp.pushBack(']');
				sb.pushBack(arrTmp.getString());
				sb.pushBack(')');
				if(idx+1 < row.getSize()) {
					sb.pushBack(',');
				}
				if(sb.getSize() % 80 + sb.getSize() > 80) {
					sb.pushBack('\n');
				}
			}
			//log("%s", sb.getString());
			/*while(sb.getSize() > 0 && 
					(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
				log();
				sb.popBack();
			}*/
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
			"public static immutable(immutable(immutable(TitP)[])[%u]) " ~
			"gotoTable = [\n", table.getSize()-1));

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
			foreach(size_t jdx, Pair!(int,Deque!(FinalItem)) it; tmp) {
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
					if(jdx+1 < it.second.getSize()) {
						arrTmp.pushBack(',');
					}
				}
				warn(gotoCnt > 1, "more than one goto in itemset %u", idx-1);
				/*while(arrTmp.getSize() > 0 && 
						(arrTmp.peekBack() == '\n' || 
						arrTmp.peekBack() == ',')) {
					arrTmp.popBack();
				}*/
				arrTmp.pushBack(']');
				sb.pushBack(arrTmp.getString());
				sb.pushBack("),");
				if(sb.getSize() % 80 + sb.getSize() > 80) {
					sb.pushBack('\n');
				}
			}
			/*while(sb.getSize() > 0 && 
					(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
				sb.popBack();
			}*/
			sb.pushBack("] /* itemset %d */ ,\n\n",idx-1);
		}
		/*while(sb.getSize() > 0 && 
				(sb.peekBack() == '\n' || sb.peekBack() == ',')) {
			sb.popBack();
		}*/
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
				" gotoTable = [\n", table.getSize()-1));
		} else {
			this.file.writeString(format(
				"public static immutable(Pair!(int,TableItem)[][%u]) " ~
				" gotoTable = [\n", table.getSize()-1));
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
			case TableType.Search:
				ret.pushBack("Search:");
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
		immutable(Pair!(int,TableItem)) retError = Pair!(int,TableItem)(
			int.min, TableItem(TableType.Error, 0));


		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,TableItem)) toSearch = Pair!(int,TableItem)(
			input.getTyp(), TableItem(false));

		immutable(Pair!(int,TableItem)[]) row = cast(immutable)parseTable[
			this.parseStack.back()];

		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first == b.first; });

		return ret.second;
	}

	private short getGoto(const int input) const {
		immutable(Pair!(int,TableItem)) retError = Pair!(int,TableItem)(
			int.min, TableItem(TableType.Error, 0));

		immutable(Pair!(int,TableItem)) toSearch = Pair!(int,TableItem)(
			input, TableItem(false));
		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,TableItem)) a, 
					immutable(Pair!(int,TableItem)) b) {
				return a.first == b.first; });

		/*auto ret = binarySearch!(Pair!(int,TableItem))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first > b.first;
			}, 
			function(Pair!(int,TableItem) a, Pair!(int,TableItem) b) {
				return a.first == b.first; });
		*/

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

immutable string glrParserTemplate = `
import hurt.algo.binaryrangesearch;
import hurt.container.deque;
import hurt.io.stdio;
import hurt.util.pair;
import hurt.util.slog;
import hurt.util.util;
import hurt.string.formatter;
import hurt.string.stringbuffer;

import ast;
import lexer;
import lextable;
import parsetable;
import token;

class Parse {
	private int id;
	private long tokenBufIdx;
	private Parser parser;
	private Deque!(int) parseStack;
	private Deque!(Token) tokenStack;
	private AST ast;
	private Token input;

	this(Parser parser, int id) {
		this.parser = parser;
		this.id = id;
		this.parseStack = new Deque!(int)(128);
		this.tokenStack = new Deque!(Token)(128);
		// we start at state (zero null none 0)
		this.parseStack.pushBack(0);

		this.ast = new AST();
		this.tokenBufIdx = 0;
		this.input = this.getToken();
	}

	this(Parser parser, Parse toCopy, int id) {
		this.parser = parser;
		this.parseStack = new Deque!(int)(toCopy.parseStack);
		this.tokenStack = new Deque!(Token)(toCopy.tokenStack);
		this.tokenBufIdx = toCopy.tokenBufIdx;
		this.ast = new AST(toCopy.ast);
		assert(this.ast == toCopy.ast);

		this.tokenBufIdx = toCopy.tokenBufIdx;
		this.input = toCopy.input;
		this.id = id;
	}

	package int getId() const {
		return this.id;
	}

	public bool copyEqualButDistinged(Parse p) @trusted {
		if(p is this) {
			log();
			return false;
		}
		
		if(this.ast != p.ast) {
			log();
			return false;
		}

		if(this.parseStack is p.parseStack || this.parseStack != p.parseStack) {
			log();
			return false;
		}

		if(this.tokenStack is p.tokenStack || this.tokenStack != p.tokenStack) {
			log();
			return false;
		}

		return this.input == p.input;
	}

	public override bool opEquals(Object o) @trusted {
		Parse p = cast(Parse)o;

		if(this.tokenBufIdx != p.tokenBufIdx) {
			return false;
		}

		// no need to compare every element if the size is not equal
		if(this.parseStack.getSize() != p.parseStack.getSize()) {
			return false;
		}

		// compare the parseStack from the back to the front
		// because the difference should be at the back
		for(auto it = this.parseStack.cEnd(), jt = p.parseStack.cEnd(); 
				it.isValid() && jt.isValid(); it--, jt--) {
			if(*it != *jt) {
				return false;
			}
		}

		return true;
	}

	package const(Token) getCurrentInput() const {
		return this.input;
	}

	package int getTos() const {
		return this.parseStack[this.parseStack.getSize()-1];
	}

	package AST getAst() {
		return this.ast;
	}

	private Token getToken() {
		return this.parser.increToNextToken(this.tokenBufIdx++);
	}

	public immutable(TableItem[]) getAction() const {
		immutable(Pair!(int,immutable(immutable(TableItem)[]))) retError = 
			Pair!(int,immutable(immutable(TableItem)[]))(int.min, 
			[TableItem(TableType.Error, 0)]);

		//log("%d %d", this.parseStack.back(), input.getTyp());

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			this.input.getTyp(), [TableItem(false)]);

		immutable(immutable(Pair!(int,immutable(TableItem[])))[]) row
			= parseTable[this.parseStack.back()];

		bool found;
		size_t foundIdx;

		auto ret = binarySearch!(TitP)
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first == b.first; });

		return ret.second;
	}

	private short getGoto(const int input) const {
		immutable(Pair!(int,immutable(immutable(TableItem)[]))) retError = 
			Pair!(int,immutable(immutable(TableItem)[]))(int.min, 
			[TableItem(TableType.Error, 0)]);

		immutable(Pair!(int,immutable(immutable(TableItem)[]))) toSearch = 
			Pair!(int,immutable(immutable(TableItem)[]))(
			input, [TableItem(false)]);

		auto row = gotoTable[this.parseStack.back()];
		bool found;
		size_t foundIdx;

		auto ret = binarySearch!((TitP))
			(row, toSearch, retError, row.length, found, foundIdx,
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first > b.first;
			}, 
			function(immutable(Pair!(int,immutable(TableItem[]))) a, 
					immutable(Pair!(int,immutable(TableItem[]))) b) {
				return a.first == b.first; });


		assert(ret.second.length == 1);
		return ret.second[0].getNumber();
	}

	private void runAction(short actionNum) {
		Token ret;
		log("actionNum %d", actionNum);
		switch(actionNum) {
			mixin(actionString);
			default:
				assert(false, format("no action for %d defined", actionNum));
		}
		log("%d", this.id);
		log("%s", ret.toString());
		this.tokenStack.popBack(rules[actionNum].length-1);
		this.tokenStack.pushBack(ret);
		this.printTokenStack();
		log("%s", this.ast.toString());

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
			printf("%s:%d ", it.toStringShort(), it.getTreeIdx());
		}
		println();
	}

	private string reportError(const Token input) const {
		StringBuffer!(char) ret = new StringBuffer!(char)(1023);
		ret.pushBack("%?1!1s in state %?1!1d on input %?1!1s this is parse %d", 
			"ERROR", this.parseStack.back(), input.toString(), this.id);
		return ret.getString();
	}

	public Pair!(int,string) step(immutable(TableItem[]) actionTable, 
			size_t actIdx) {
		TableItem action = actionTable[actIdx];
		//Token input = this.getToken();
		//this.tokenStack.pushBack(input);
		//log("%s", input.toString());
		
		//action = this.getAction(input)[actIdx]; 
		//log("%s", action.toString());
		if(action.getTyp() == TableType.Accept) {
			//log("%s %s", action.toString(), input.toString());
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.runAction(action.getNumber());
			return Pair!(int,string)(1,"");
		} else if(action.getTyp() == TableType.Error) {
			//log();
			return Pair!(int,string)(-1,this.reportError(input));
		} else if(action.getTyp() == TableType.Shift) {
			//log("%s", input.toString());
			//log();
			this.parseStack.pushBack(action.getNumber());
			this.tokenStack.pushBack(input);
			input = this.getToken();
		} else if(action.getTyp() == TableType.Reduce) {
			/*log("%d %d %d", this.id, rules[action.getNumber()].length-1, 
				this.parseStack.getSize());*/
			// do action
			// pop RHS of Production
			this.parseStack.popBack(rules[action.getNumber()].length-1);
			this.parseStack.pushBack(
				this.getGoto(rules[action.getNumber()][0]));

			// tmp token stack stuff
			this.runAction(action.getNumber());
		}
		//printfln("id %d ast %s", this.id, this.ast.toStringGraph());
		return Pair!(int,string)(0,"");
	}
}

`;

immutable string glrParserTemplate2 = `
	private Lexer lexer;
	private Deque!(Token) tokenBuffer;
	private Deque!(Token) tokenStore;
	private Deque!(Parse) parses;
	private Deque!(Parse) newParses;
	private Deque!(Parse) acceptingParses;
	private Deque!(int) toRemove;
	private int nextId;
	private bool lastTokenFound;

	public this(Lexer lexer) {
		this.lexer = lexer;	
		this.tokenBuffer = new Deque!(Token)(64);
		this.tokenStore = new Deque!(Token);
		assert(this.tokenStore.isEmpty());
		assert(this.tokenStore.getSize() == 0, 
			format("%d", this.tokenStore.getSize()));
		this.parses = new Deque!(Parse)(16);
		this.nextId = 0;
		this.parses.pushBack(new Parse(this,this.nextId++));
		this.newParses = new Deque!(Parse)(16);
		this.acceptingParses = new Deque!(Parse)(16);
		this.toRemove = new Deque!(int)(16);
		this.lastTokenFound = false;
	} 

	public AST getAst() {
		assert(!this.acceptingParses.isEmpty());
		return this.acceptingParses.front().getAst();
	}

	/** do not call this direct unless you want whitespace token
	 */
	private Token getNextToken() { 
		if(this.tokenBuffer.isEmpty()) {
			this.lexer.getToken(this.tokenBuffer);
		} 
		if(this.tokenBuffer.isEmpty()) {
			return Token(termdollar);
		} else {
			return this.tokenBuffer.popFront();
		}
	}

	private Token getToken() {
		Token t = this.getNextToken();
		if(t.getTyp() == termdollar) {
			this.lastTokenFound = true;
		}
		while(t.getTyp() == -99) {
			if(t.getTyp() == termdollar) {
				this.lastTokenFound = true;
			}
			t = this.getNextToken();
		}
		return t;
	}

	package Token increToNextToken(long idx) {
		//log("%d %d", idx, this.tokenStore.getSize());
		if(idx + 1 >= this.tokenStore.getSize()) {
			log("lastTokenFound %b", this.lastTokenFound);
			if(this.lastTokenFound) {
				return Token(termdollar);
			}
			this.tokenStore.pushBack(this.getToken());
		}
		//log("%u", this.tokenStore.getSize());

		return this.tokenStore[idx++];
	}

	private int merge(Parse a, Parse b) {
		log();
		return b.getId();
	}

	private void mergeRun(Deque!(Parse) parse) {
		// early exit if only one parse is left
		if(parse.getSize() <= 1) {
			return;
		}
		// remove all accepting parses or merged away parses
		// call merge function for all parse that are equal
		for(size_t i = 0; i < parse.getSize() - 1; i++) {
			if(this.toRemove.contains(parse[i].getId())) {
				continue;
			}
			for(size_t j = i+1; j < parse.getSize(); j++) {
				if(this.toRemove.contains(parse[j].getId())) {
					continue;
				}

				// for every tow parse that are equal call the merge 
				// function
				if(parse[i] == parse[j]) {
					this.toRemove.pushBack(
						this.merge(parse[i], parse[j]) 
					);
				}
			}
		}
	}

	public bool parse() {
		while(!this.parses.isEmpty()) {
			log();
			// for every parse
			for(size_t i = 0; i < this.parses.getSize(); i++) {
				// get all actions
				immutable(TableItem[]) actions = this.parses[i].getAction();
				// if there are more than one action we found a conflict
				if(actions.length > 1) {
					log("fork at id %d, tos %d, input %s, number of actions %d",
						this.parses[i].getId(), this.parses[i].getTos(),
						this.parses[i].getCurrentInput().toString(), 
						actions.length);
					for(size_t j = 1; j < actions.length; j++) {
						Parse tmp = new Parse(this, this.parses[i], 
							this.nextId++);
						assert(tmp.copyEqualButDistinged(this.parses[i]));
						auto rslt = tmp.step(actions, j);
						if(rslt.first == 1) {
							this.acceptingParses.pushBack(this.parses[i]);
							this.toRemove.pushBack(this.parses[i].getId);
						} else if(rslt.first == -1) {
							this.toRemove.pushBack(this.parses[i].getId);
						} else {
							this.newParses.pushBack(tmp);
						}
					}
				}

				// after all one action is left
				auto rslt = this.parses[i].step(actions, 0);
				if(rslt.first == 1) {
					this.acceptingParses.pushBack(this.parses[i]);
					this.toRemove.pushBack(this.parses[i].getId);
				} else if(rslt.first == -1) {
					this.toRemove.pushBack(this.parses[i].getId);
					if(this.newParses.isEmpty() && this.acceptingParses.isEmpty()) {
						printfln("%s", rslt.second);
					}
				} 
			}
			// copy all new parses
			while(!this.newParses.isEmpty()) {
				this.parses.pushBack(this.newParses.popBack());
			}

			this.mergeRun(this.parses);

			this.parses.removeFalse(delegate(Parse a) {
				return this.toRemove.containsNot(a.getId()); });

			log("%d", this.toRemove.getSize());
			this.toRemove.clean();
			log("%d", this.toRemove.getSize());
		}

		// this is necessary because their might be more than one accepting 
		// parse
		this.mergeRun(this.acceptingParses);
		return !this.acceptingParses.isEmpty();
	}
}`;
