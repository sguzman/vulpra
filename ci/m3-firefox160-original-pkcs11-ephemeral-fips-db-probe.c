/* Actual original Firefox160 packaged NSS with a disposable SQL DB, prepared
 * for FIPS-mode observation separately by a temporary modutil invocation.
 * No original NSS setup, user keys/passwords, global system FIPS setting,
 * workstation data, or original source/library mutation. One NSS_Init per
 * new process and source-bound original libnss3.so symbol validation.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <link.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int (*NSSInit)(const char*);
typedef int (*Shutdown)(void);
typedef int (*IsFIPS)(void);
typedef void *(*GetSlot)(void);
typedef void (*FreeSlot)(void*);
typedef int (*IsPresent)(void*);
typedef int (*DoesMechanism)(void*,unsigned long);
typedef int (*GenerateRandom)(unsigned char*,int);
typedef int (*SystemFIPS)(void);
enum { SHA256_PKCS11_MECHANISM = 0x00000250UL };

struct matched {
    const char* root;
    bool softoken;
    bool freebl;
};
static int original_mappings(struct dl_phdr_info* p,size_t unused,void* opaque){
    (void)unused;
    struct matched* m=(struct matched*)opaque;
    if(!p->dlpi_name||!p->dlpi_name[0])return 0;
    const char* last=strrchr(p->dlpi_name,'/');
    if(!last)return 0;
    const char* name=last+1;
    bool so=strcmp(name,"libsoftokn3.so")==0;
    bool fb=strcmp(name,"libfreeblpriv3.so")==0;
    if(!so&&!fb)return 0;
    char got[PATH_MAX],dir[PATH_MAX];
    if(!realpath(p->dlpi_name,got)||!realpath(m->root,dir))return 0;
    char* slash=strrchr(got,'/');
    if(!slash)return 0;
    *slash='\0';
    if(strcmp(got,dir)!=0)return 0;
    if(so)m->softoken=true;
    if(fb)m->freebl=true;
    return 0;
}
static bool original_symbol(void* addr,const char* expected){
    Dl_info info={0};
    char actual[PATH_MAX],want[PATH_MAX];
    return addr&&dladdr(addr,&info)&&info.dli_fname&&
           realpath(info.dli_fname,actual)&&realpath(expected,want)&&
           strcmp(actual,want)==0;
}
static void zero(unsigned char* bytes,size_t n){
    volatile unsigned char *p=bytes;
    while(n--)*p++=0;
}
int main(int argc,char**argv){
    if(argc!=3||argv[1][0]!='/'||strlen(argv[1])>=PATH_MAX||
       !strrchr(argv[1],'/')||
       strcmp(strrchr(argv[1],'/')+1,"libnss3.so")!=0||
       strncmp(argv[2],"sql:/",5)!=0||strlen(argv[2])>=PATH_MAX){

        fputs("Expected exact absolute original libnss3.so\n",stderr);
        return 2;
    }
    const char* orig=argv[1];
    // The DB path belongs to this process alone and is never serialized.
    const char* db=argv[2];
    void* lib=dlopen(orig,RTLD_NOW|RTLD_LOCAL);
    if(!lib){
        puts("PKCS11_TEMP_FIPS_V1 original_nss_open=0 exact_symbols=0 init=-2 fips=-2 system_fips=-2 internal_slot=-2 internal_key_slot=-2 slot_present=-2 key_slot_present=-2 sha256_mechanism=-2 rng=-2 rng_nonzero=0 shutdown=-2 softoken_mapped=0 freebl_mapped=0 same_slot=-2");
        return 0;
    }
    NSSInit init=(NSSInit)dlsym(lib,"NSS_Init");
    Shutdown shutdown=(Shutdown)dlsym(lib,"NSS_Shutdown");
    IsFIPS isfips=(IsFIPS)dlsym(lib,"PK11_IsFIPS");
    SystemFIPS sysfips=(SystemFIPS)dlsym(lib,"SECMOD_GetSystemFIPSEnabled");
    GetSlot slot=(GetSlot)dlsym(lib,"PK11_GetInternalSlot");
    GetSlot keyslot=(GetSlot)dlsym(lib,"PK11_GetInternalKeySlot");
    FreeSlot freeslot=(FreeSlot)dlsym(lib,"PK11_FreeSlot");
    IsPresent present=(IsPresent)dlsym(lib,"PK11_IsPresent");
    DoesMechanism mechanism=(DoesMechanism)dlsym(lib,"PK11_DoesMechanism");
    GenerateRandom random=(GenerateRandom)dlsym(lib,"PK11_GenerateRandom");
    void* ptrs[]={(void*)init,(void*)shutdown,(void*)isfips,(void*)sysfips,
        (void*)slot,(void*)keyslot,(void*)freeslot,(void*)present,
        (void*)mechanism,(void*)random};
    bool exact=true;
    for(unsigned int i=0;i<sizeof(ptrs)/sizeof(ptrs[0]);++i){
        if(!original_symbol(ptrs[i],orig)){exact=false;break;}
    }
    if(!exact){
        puts("PKCS11_TEMP_FIPS_V1 original_nss_open=1 exact_symbols=0 init=-2 fips=-2 system_fips=-2 internal_slot=-2 internal_key_slot=-2 slot_present=-2 key_slot_present=-2 sha256_mechanism=-2 rng=-2 rng_nonzero=0 shutdown=-2 softoken_mapped=0 freebl_mapped=0 same_slot=-2");
        dlclose(lib);return 0;
    }
    int initrc=init(db);
    int fips=-2,system=-2,intern=-2,key=-2,there=-2,keythere=-2,sha=-2,rng=-2,shut=-2,same=-2;
    bool nonzero=false;
    char path[PATH_MAX];
    const char* last=strrchr(orig,'/');
    size_t n=(size_t)(last-orig);
    if(n>=sizeof(path)){dlclose(lib);return 2;}
    memcpy(path,orig,n);path[n]='\0';
    struct matched mapped={.root=path,.softoken=false,.freebl=false};
    if(initrc==0){
        // PK11_IsFIPS reads module state; do not enable or change FIPS mode.
        fips=isfips()!=0;
        system=sysfips()!=0;
        void* s=slot();
        void* k=keyslot();
        intern=s!=NULL;key=k!=NULL;
        if(s&&k)same=(s==k);
        if(s){
            there=present(s)!=0;
            sha=mechanism(s,SHA256_PKCS11_MECHANISM)!=0;
        }
        if(k)keythere=present(k)!=0;
        if(s)freeslot(s);
        if(k)freeslot(k);
        unsigned char buf[32]={0};
        rng=random(buf,32);
        if(rng==0){
            unsigned char sum=0;
            for(size_t i=0;i<32;i++)sum|=buf[i];
            nonzero=sum!=0;
        }
        zero(buf,sizeof(buf));
    }
    // Snapshot before shutdown unloads providers; do not export paths.
    dl_iterate_phdr(original_mappings,&mapped);
    if(initrc==0)shut=shutdown();
    printf("PKCS11_TEMP_FIPS_V1 original_nss_open=1 exact_symbols=1 init=%d fips=%d system_fips=%d internal_slot=%d internal_key_slot=%d slot_present=%d key_slot_present=%d sha256_mechanism=%d rng=%d rng_nonzero=%d shutdown=%d softoken_mapped=%d freebl_mapped=%d same_slot=%d\n",
        initrc,fips,system,intern,key,there,keythere,sha,rng,(int)nonzero,shut,
        (int)mapped.softoken,(int)mapped.freebl,same);
    dlclose(lib);
    return 0;
}
