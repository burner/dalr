module dalr.filewriter;

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
		log();
		this.file = new File(this.filename, FileMode.OutNew);
		log();
		this.writeHeader();
		log();
		this.file.write('\n');
		log();
	}

	private void writeHeader() {
		this.file.writeString(format("module %s;\n\n", this.modulename));
		this.file.writeString("import hurt.util.pair;\n");
	}

	public void close() {
		this.file.close();
	}

	public void write();
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
		log();
		this.writeStackItemAndStackItemEnum();
		log();
		this.writeTable();
		this.file.writeString("\n\n");
		this.writeGotoTable();
		log();
		//this.writeTable();
		this.file.write('\n');
	}

	private void writeStackItemAndStackItemEnum() {
		// the StackType Enum
		this.file.writeString(
			"public enum StackType : byte {\n" ~
				"\tAccept,\n" ~
				"\tError,\n" ~
				"\tReduce,\n" ~
				"\tGoto,\n" ~
				"\tShift\n" ~
			"}\n");

		this.file.write('\n');

		// this is the kind of item that is placed on the stack
		this.file.writeString(
			"public struct StackItem {\n" ~
				"\tpublic StackType typ;\n" ~
				"\tpublic short number;\n" ~
				"\tprivate byte padding; // align to 32 bit\n" ~
				"\n\tthis(StackType st, short number) {\n" ~
				"\t\tthis.typ = st;\n" ~
				"\t\tthis.number = number;\n" ~
				"\t}\n" ~
			"}\n\n");
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
					return a.first > b.first;
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
					return a.first > b.first;
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
