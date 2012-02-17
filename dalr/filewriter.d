module dalr.filewriter;

import hurt.algo.sorting;
import hurt.io.stream;
import hurt.io.stdio;
import hurt.container.deque;
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
		this.file.write('\n');
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
		this.writeTable();
		this.file.writeString("\n\n");
		this.writeGotoTable();
		//this.writeTable();
		this.file.write('\n');
	}

	protected override void writeIncludes() {
		this.file.writeString("import hurt.util.pair;\n");
	}

	private string finalItemTypToStackTypeString(Type typ) {
		final switch(typ) {
			case Type.Accept:
				return "StackType.Accept";
			case Type.Error:
				assert(false, "Type Error not allowed");
			case Type.Goto:
				return "StackType.Goto";
			case Type.ItemSet:
				assert(false, "Type ItemSet not allowed");
			case Type.NonTerm:
				assert(false, "Type NonTerm not allowed");
			case Type.Reduce:
				return "StackType.Reduce";
			case Type.Shift:
				return "StackType.Shift";
			case Type.Term:
				assert(false, "Type Term not allowed");
		}
	}

	private void writeTable() {
		Deque!(Deque!(Deque!(FinalItem))) table = this.pm.getFinalTable();
		StringBuffer!(char) sb = new StringBuffer!(char)(1024);
		if(this.glr) {
			this.file.writeString(format(
				"public static immutable(Pair!(int,StackItem[])[][%u]) " ~
				"table = [\n", table.getSize()-1));
		} else {
			this.file.writeString(format(
				"public static immutable(Pair!(int,StackItem)[][%u]) " ~
				"table = [\n", table.getSize()-1));
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
				//sb.pushBack(\n"[Pair!(int,StackItem)[]\n");
			} else {
				sb.pushBack('[');
				foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
					if(it.second[0].typ == Type.Error ||
							it.second[0].typ == Type.Goto) {
						continue;
					}
					string tmpS = format("Pair!(int,StackItem)" ~
						"(%d,StackItem(%s, %u)), ", it.first, 
						finalItemTypToStackTypeString(it.second[0].typ),
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
				"public static immutable(Pair!(int,StackItem[])[][%u]) " ~
				"gotoTable = [\n", table.getSize()-1));
		} else {
			this.file.writeString(format(
				"public static immutable(Pair!(int,StackItem)[][%u]) " ~
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
				//sb.pushBack(\n"[Pair!(int,StackItem)[]\n");
			} else {
				sb.pushBack('[');
				foreach(Pair!(int,Deque!(FinalItem)) it; tmp) {
					if(it.second[0].typ != Type.Goto) {
						continue;
					}
					string tmpS = format("Pair!(int,StackItem)" ~
						"(%d,StackItem(%s, %u)), ", it.first, 
						finalItemTypToStackTypeString(it.second[0].typ),
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
