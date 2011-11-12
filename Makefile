all: fine

#CFLAGS=-m64 -offsm -unittest -d-debug -gc
#CFLAGS=-m64 -offsm -unittest -debug -gc -debug=RegExDebug -debug=StateDebug
CFLAGS=-m64 -unittest -debug -gc -I../libhurt/ -wi
#CFLAGS=-m64 -offsm -O -wi -I../libhurt

OBJS=dalr.main.o dalr.productionmanager.o dalr.item.o dalr.itemset.o \
dalr.symbolmanager.o

count:
	wc -l `find dalr -name \*.d`

clean:
	rm *.o
	rm Dalr

fine: $(OBJS)
	dmd $(OBJS) $(CFLAGS) ../libhurt/libhurt.a -I../libhurt/ -gc -ofDalr

dalr.main.o: dalr/main.d dalr/productionmanager.d Makefile
	dmd $(CFLAGS) -c dalr/main.d -ofdalr.main.o

dalr.productionmanager.o: dalr/productionmanager.d Makefile
	dmd $(CFLAGS) -c dalr/productionmanager.d -ofdalr.productionmanager.o

dalr.item.o: dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/item.d -ofdalr.item.o

dalr.itemset.o: dalr/itemset.d dalr/item.d Makefile
	dmd $(CFLAGS) -c dalr/itemset.d -ofdalr.itemset.o

dalr.symbolmanager.o: dalr/symbolmanager.d Makefile
	dmd $(CFLAGS) -c dalr/symbolmanager.d -ofdalr.symbolmanager.o
