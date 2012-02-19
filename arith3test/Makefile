OBJS=main.o token.o lexer.o lextable.o parsetable.o

DFLAGS=-c -unittest -I../../libhurt -m64 -gc -debug

all: $(OBJS) Makefile
	dmd $(OBJS) -ofarith3 ../../libhurt/libhurt.a -m64 -unittest -gc -debug

lextable.o: lextable.d Makefile
	dmd $(DFLAGS) lextable.d

lexer.o: lexer.d lextable.d token.d Makefile
	dmd $(DFLAGS) lexer.d

main.o: main.d lexer.d lextable.d token.d Makefile
	dmd $(DFLAGS) main.d

token.o: token.d lextable.d Makefile
	dmd $(DFLAGS) token.d

parsetable.o: parsetable.d Makefile
	dmd $(DFLAGS) parsetable.d

clean:
	rm *.o
	rm arith3
