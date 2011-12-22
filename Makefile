all: fine

#CFLAGS=-m64 -offsm -unittest -d-debug -gc
#CFLAGS=-m64 -offsm -unittest -debug -gc -debug=RegExDebug -debug=StateDebug
CFLAGS=-m64 -unittest -debug -gc -I../libhurt/ -wi
#CFLAGS=-m64 -offsm -O -wi -I../libhurt

OBJS=dalr.main.o dalr.productionmanager.o dalr.item.o dalr.itemset.o \
dalr.symbolmanager.o dalr.grammerparser.o dalr.dotfilewriter.o \
dalr.extendeditem.o dalr.finalitem.o dalr.mergedreduction.o dalr.tostring.o

count:
	wc -l `find dalr -name \*.d`

clean:
	rm *.o
	rm Dalr

fine: $(OBJS)
	sh IncreBuildId.sh
	dmd $(OBJS) $(CFLAGS) buildinfo.d ../libhurt/libhurt.a -gc -ofDalr

dalr.main.o: dalr/main.d dalr/productionmanager.d dalr/dotfilewriter.d \
dalr/symbolmanager.d dalr/grammerparser.d dalr/tostring.d Makefile
	dmd $(CFLAGS) -c dalr/main.d -ofdalr.main.o

dalr.productionmanager.o: dalr/productionmanager.d dalr/item.d dalr/itemset.d \
dalr/symbolmanager.d dalr/finalitem.d dalr/extendeditem.d dalr/grammerparser.d \
dalr/mergedreduction.d Makefile
	dmd $(CFLAGS) -c dalr/productionmanager.d -ofdalr.productionmanager.o

dalr.item.o: dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/item.d -ofdalr.item.o

dalr.tostring.o: dalr/tostring.d dalr/productionmanager.d Makefile
	dmd $(CFLAGS) -c dalr/tostring.d -ofdalr.tostring.o

dalr.finalitem.o: dalr/finalitem.d Makefile
	dmd $(CFLAGS) -c dalr/finalitem.d -ofdalr.finalitem.o

dalr.extendeditem.o: dalr/extendeditem.d Makefile
	dmd $(CFLAGS) -c dalr/extendeditem.d -ofdalr.extendeditem.o

dalr.mergedreduction.o: dalr/mergedreduction.d Makefile
	dmd $(CFLAGS) -c dalr/mergedreduction.d -ofdalr.mergedreduction.o

dalr.grammerparser.o: dalr/grammerparser.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/grammerparser.d -ofdalr.grammerparser.o

dalr.itemset.o: dalr/itemset.d dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/itemset.d -ofdalr.itemset.o

dalr.symbolmanager.o: dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/symbolmanager.d -ofdalr.symbolmanager.o

dalr.dotfilewriter.o: dalr/dotfilewriter.d dalr/symbolmanager.d dalr/item.d \
dalr/itemset.d Makefile
	dmd $(CFLAGS) -c dalr/dotfilewriter.d -ofdalr.dotfilewriter.o
