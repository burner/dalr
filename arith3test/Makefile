OBJS=main.o token.o lexer.o parsetable.o lextable.o
GEN=parsetable.d lextable.d

DFLAGS=-unittest -I../../libhurt -m64 -gc -debug

all: $(GEN) $(OBJS) Makefile
	dmd $(OBJS) -ofarith3 -L../../libhurt/libhurt.a $(DFLAGS)

parsetable.d: arith3.dlr Makefile
	../Dalr -i arith3.dlr -r parsetable.d -rm parsetable

lextable.d: arith3.dlr arith.dex Makefile
	../../dex/fsm -i arith.dex -n lextable.d -nm lextable

lextable.o: lextable.d Makefile
	dmd -c $(DFLAGS) lextable.d

lexer.o: lexer.d lextable.d token.d Makefile
	dmd -c $(DFLAGS) lexer.d

main.o: main.d lexer.d lextable.d token.d Makefile
	dmd -c $(DFLAGS) main.d

token.o: token.d lextable.d Makefile
	dmd -c $(DFLAGS) token.d

parsetable.o: parsetable.d Makefile
	dmd -c $(DFLAGS) parsetable.d

clean:
	rm *.o
	rm arith3
