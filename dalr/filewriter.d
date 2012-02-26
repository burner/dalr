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
	protected void writeIncludes();
}

class LalrWriter : Writer {
	private string classname;

	this(string filename, string modulename, 
			SymbolManager sm, ProductionManager pm, string classname) {
		super(filename, modulename, sm, pm);
		this.classname = classname;
	}

	private void writeLexerInterface() {
		// write the lexer interface
		this.file.writeString("public interface LexInterface {\n" ~
			"\tpublic int getNextToken();\n" ~
			"\tpublic int getCurrentLine();\n" ~
			"\tpublic int getColumnIndex();\n" ~
			"\tpublic bool isEOF();\n" ~
			"}\n\n");
	}

	private void writeClassdefAndDecal() {
		this.file.writeString(format("final class %s {\n", this.classname));
	}

	protected override void writeIncludes() {
		this.file.writeString("import hurt.util.pair;\n");
	}

	public override void write() {
		this.writeHeader();
		this.writeLexerInterface();
		this.writeClassdefAndDecal();
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
		this.writeTable();
		this.file.writeString("\n\n");
		this.writeGotoTable();
		this.file.write('\n');
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
		this.file.writeString("\t\tdefault:\n");
		this.file.writeString("\t\t\tassert(false, " ~
			"format(\"no symbol for %d present\", sym));\n");
		this.file.writeString("\t}\n}\n");
	}

	protected override void writeIncludes() {
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

	private void writeTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		if(this.glr) {
			this.file.writeString(format(
				"public static immutable(Pair!(int,TableItem[])[][%u]) " ~
				"parseTable = [\n", table.getSize()-1));
		} else {
			this.file.writeString(format(
				"public static immutable(Pair!(int,TableItem)[][%u]) " ~
				"parseTable = [\n", table.getSize()-1));
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

			if(this.glr) {
				//sb.pushBack(\n"[Pair!(int,TableItem)[]\n");
			} else {
				sb.pushBack('[');
				foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
					if(it.second[0].typ == Type.Error ||
							it.second[0].typ == Type.Goto) {
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

		}
		this.file.seek(-3, SeekPos.Current);
		sb.pushBack("];\n");
			
		this.file.writeString(sb.getString());
		sb.clear();
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

			if(this.glr) {
				//sb.pushBack(\n"[Pair!(int,TableItem)[]\n");
			} else {
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

		}
		this.file.seek(-3, SeekPos.Current);
		sb.pushBack("];\n");
			
		this.file.writeString(sb.getString());
		sb.clear();
	}
}

private static immutable(string) tableType =
`public enum TableType : byte {
	Accept,
	Error,
	Reduce,
	Goto,
	Shift
}

public struct TableItem {
	public TableType typ;
	public short number;
	private byte padding; // align to 32 bit

	this(TableType st, short number) {
		this.typ = st;
		this.number = number;
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
