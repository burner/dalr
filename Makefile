all: fine

#CFLAGS=-m64 -offsm -unittest -d-debug -gc
#CFLAGS=-m64 -offsm -unittest -debug -gc -debug=RegExDebug -debug=StateDebug
CFLAGS=-m64 -unittest -debug -gc -I../libhurt/ -wi
#CFLAGS=-m64 -offsm -O -wi -I../libhurt

OBJS=dalr.main.o dalr.productionmanager.o dalr.item.o dalr.itemset.o \
dalr.symbolmanager.o dalr.grammerparser.o dalr.dotfilewriter.o

count:
	wc -l `find dalr -name \*.d`

clean:
	rm *.o
	rm Dalr

fine: $(OBJS)
	sh IncreBuildId.sh
	dmd $(OBJS) $(CFLAGS) buildinfo.d ../libhurt/libhurt.a -gc -ofDalr

dalr.main.o: dalr/main.d dalr/productionmanager.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/main.d -ofdalr.main.o

dalr.productionmanager.o: dalr/productionmanager.d dalr/item.d dalr/itemset.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/productionmanager.d -ofdalr.productionmanager.o

dalr.item.o: dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/item.d -ofdalr.item.o

dalr.grammerparser.o: dalr/grammerparser.d dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/grammerparser.d -ofdalr.grammerparser.o

dalr.itemset.o: dalr/itemset.d dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/itemset.d -ofdalr.itemset.o

dalr.symbolmanager.o: dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/symbolmanager.d -ofdalr.symbolmanager.o

dalr.dotfilewriter.o: dalr/dotfilewriter.d dalr/item.d dalr/itemset.d Makefile
	dmd $(CFLAGS) -c dalr/dotfilewriter.d -ofdalr.dotfilewriter.o
