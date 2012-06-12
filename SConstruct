src = Split('''
dalr/checker.d       
dalr/filewriter.d     
dalr/itemset.d          
dalr/productionmanager.d
dalr/dotfilewriter.d  
dalr/finalitem.d      
dalr/main.d             
dalr/symbolmanager.d
dalr/extendeditem.d   
dalr/grammerparser.d  
dalr/mergedreduction.d  
dalr/tostring.d
dalr/filereader.d     
dalr/item.d           
dalr/prodtree.d         
buildinfo.d
''')

env = Environment()
env.Program("Dalr", src, TARGET_ARCH='x86_64', DFLAGS = Split("-m64 -unittest -gc -g -I../libhurt"), LIBPATH="../libhurt/", LIBS=["m", "hurt", "pthread", "rt", "phobos2"])
