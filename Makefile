all: fine

#CFLAGS=-m64 -offsm -unittest -d-debug -gc
#CFLAGS=-m64 -offsm -unittest -debug -gc -debug=RegExDebug -debug=StateDebug
CFLAGS=-m64 -unittest -debug -g -I../libhurt/ -wi
#CFLAGS=-m64 -offsm -O -wi -I../libhurt

OBJS=dalr.productionmanager.o dalr.item.o dalr.itemset.o \
dalr.symbolmanager.o dalr.grammerparser.o dalr.dotfilewriter.o \
dalr.extendeditem.o dalr.finalitem.o dalr.mergedreduction.o dalr.tostring.o \
dalr.filereader.o

DALROBJS=dalr.main.o

TESTEROBJS=tester.tester.o

count:
	wc -l `find dalr -name \*.d && find tester -name \*.d`

clean:
	rm *.o
	rm Dalr

tester: $(TESTEROBJS) $(OBJS)
	sh IncreBuildIdTester.sh
	dmd $(TESTEROBJS) $(OBJS) $(CFLAGS)  buildinfotester.d \
	../libhurt/libhurt.a -gc -ofTester

fine: $(OBJS) $(DALROBJS)
	sh IncreBuildId.sh
	dmd $(OBJS) $(CFLAGS) -version=DALR dalr.main.o buildinfo.d \
	../libhurt/libhurt.a -gc -ofDalr

dalr.main.o: dalr/main.d dalr/productionmanager.d dalr/dotfilewriter.d \
dalr/symbolmanager.d dalr/grammerparser.d dalr/filereader.d \
dalr/tostring.d Makefile
	dmd $(CFLAGS) -c dalr/main.d -ofdalr.main.o

dalr.productionmanager.o: dalr/productionmanager.d dalr/item.d dalr/itemset.d \
dalr/symbolmanager.d dalr/finalitem.d dalr/extendeditem.d dalr/grammerparser.d \
dalr/mergedreduction.d dalr/filereader.d Makefile
	dmd $(CFLAGS) -c dalr/productionmanager.d -ofdalr.productionmanager.o

dalr.item.o: dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/item.d -ofdalr.item.o

dalr.tostring.o: dalr/tostring.d dalr/productionmanager.d Makefile
	dmd $(CFLAGS) -c dalr/tostring.d -ofdalr.tostring.o

dalr.finalitem.o: dalr/finalitem.d Makefile
	dmd $(CFLAGS) -c dalr/finalitem.d -ofdalr.finalitem.o

dalr.filereader.o: dalr/filereader.d dalr/grammerparser.d \
dalr/productionmanager.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/filereader.d -ofdalr.filereader.o

dalr.extendeditem.o: dalr/extendeditem.d Makefile
	dmd $(CFLAGS) -c dalr/extendeditem.d -ofdalr.extendeditem.o

dalr.mergedreduction.o: dalr/mergedreduction.d Makefile
	dmd $(CFLAGS) -c dalr/mergedreduction.d -ofdalr.mergedreduction.o

dalr.grammerparser.o: dalr/grammerparser.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/grammerparser.d -ofdalr.grammerparser.o

dalr.itemset.o: dalr/itemset.d dalr/item.d dalr/productionmanager.d Makefile
	dmd $(CFLAGS) -c dalr/itemset.d -ofdalr.itemset.o

dalr.symbolmanager.o: dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/symbolmanager.d -ofdalr.symbolmanager.o

dalr.dotfilewriter.o: dalr/dotfilewriter.d dalr/symbolmanager.d dalr/item.d \
dalr/itemset.d Makefile
	dmd $(CFLAGS) -c dalr/dotfilewriter.d -ofdalr.dotfilewriter.o

tester.tester.o: tester/tester.d Makefile
	dmd $(CFLAGS) -c tester/tester.d -oftester.tester.o
