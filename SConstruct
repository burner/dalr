src = Split('''
dalr/item.d
dalr/main.d
''')

dalr = Program(target="Dalr", LINKFLAGS=Split("-m64 ../libhurt/libhurt.a"),
source=src, TARGET_ARCH="x86_64", 
DFLAGS=Split("-unittest -gc -g -m64 -I../libhurt/"))
