OBJS=main.o token.o lexer.o parsetable.o lextable.o parser.o ast.o
GEN=parsetable.d lextable.d

DFLAGS=-unittest -I../../libhurt -m64 -gc -gs -debug

all: build

run: build
	./dmcd

build: $(GEN) $(OBJS) Makefile
	sh IncreBuildId.sh
	dmd $(OBJS) buildinfo.d -ofdmcd -L../../libhurt/libhurt.a $(DFLAGS)

parsetable: d.dlr
	../Dalr -g ambiGraph -i d.dlr -glr true -t prodtree.dot

parsetable.d: d.dlr Makefile
	../Dalr -i d.dlr -r parsetable.d -rm parsetable -z prodgraph.dot -g dgraph

lextable.d: d.dlr d.dex Makefile
	../../dex/fsm -i d.dex -n lextable.d -nm lextable

parser.o: parser.d parsetable.d lextable.d lexer.d ast.d token.d Makefile
	dmd -c $(DFLAGS) parser.d

lextable.o: lextable.d Makefile
	dmd -c $(DFLAGS) lextable.d

ast.o: ast.d token.d Makefile
	dmd -c $(DFLAGS) ast.d

lexer.o: lexer.d lextable.d token.d Makefile
	dmd -c $(DFLAGS) lexer.d

main.o: main.d lexer.d lextable.d token.d ast.d parser.d parsetable.d Makefile
	dmd -c $(DFLAGS) main.d

token.o: token.d lextable.d Makefile
	dmd -c $(DFLAGS) token.d

parsetable.o: parsetable.d Makefile
	dmd -c $(DFLAGS) parsetable.d

clean:
	rm parsetable.d
	rm lextable.d
	rm *.o
	rm dmcd
