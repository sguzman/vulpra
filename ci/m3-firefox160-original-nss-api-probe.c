/* Real original Firefox160 packaged NSS, not a synthetic exported-function
 * shim. Each invocation is a separate ephemeral Linux process with its own
 * NSS initialization state and *optional* exact-named C dlopen interposer.
 * Operates only on a pinned extracted native archive in disposable CI.
 *
 * Does NOT attempt TLS to a real service, access user secrets, or certify all
 * NSS cryptographic or FIPS behavior. No NSS headers needed.
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

typedef int (*NSSNoDBInit)(const char*);
typedef int (*NSSShutdown)(void);
typedef int (*PK11GenerateRandom)(unsigned char*,int);

static bool exact_original_library(const void *sym, const char *expected) {
    Dl_info info = {0};
    char actual[PATH_MAX], pinned[PATH_MAX];
    if (!sym || !expected || !dladdr(sym, &info) ||
        !realpath(info.dli_fname, actual) || !realpath(expected, pinned)) {
        return false;
    }
    return strcmp(actual, pinned) == 0;
}
/* Inspect only the native ELF mappings during actual original NSS API calls.
 * Never export full paths or loaded module names; report two booleans.
 * This proves original packaged library ownership, not full callstacks.
 */
struct expected_modules {
    const char* dir;
    bool softoken;
    bool freebl;
};
static int find_original_modules(struct dl_phdr_info *info, size_t size, void *context) {
    (void)size;
    struct expected_modules *m=(struct expected_modules*)context;
    const char* name=info->dlpi_name;
    if(!name||!*name)return 0;
    const char* slash=strrchr(name,'/');
    const char* base=slash?slash+1:name;
    const bool softoken=strcmp(base,"libsoftokn3.so")==0;
    const bool freebl=strcmp(base,"libfreeblpriv3.so")==0;
    if(!softoken&&!freebl)return 0;
    char resolved[PATH_MAX], parent[PATH_MAX], expected[PATH_MAX];
    if(!realpath(name,resolved))return 0;
    const char* last=strrchr(resolved,'/');
    if(!last)return 0;
    size_t n=(size_t)(last-resolved);
    if(n>=sizeof(parent))return 0;
    memcpy(parent,resolved,n);parent[n]='\0';
    if(!realpath(m->dir,expected)||strcmp(parent,expected))return 0;
    if(softoken)m->softoken=true;
    if(freebl)m->freebl=true;
    return 0;
}
static bool any_nonzero(const unsigned char* buf, size_t len) {
    unsigned char accum=0;
    for(size_t i=0;i<len;i++) accum|=buf[i];
    return accum!=0;
}
int main(int argc,char**argv){
    if(argc!=2 || argv[1][0]!='/' || strlen(argv[1])>=PATH_MAX){
        fputs("FAIL: original absolute libnss3.so pathname required\n",stderr);
        return 2;
    }
    const char* base=strrchr(argv[1],'/');
    if(!base||strcmp(base+1,"libnss3.so")){
        fputs("FAIL: only original libnss3.so basename allowed\n",stderr);
        return 2;
    }
    void* h=dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if(!h){
        puts("NSS_PROBE_V1 native_nss_open=0 original_nss_symbols=0 init=-2 random=-2 nonzero=0 shutdown=-2 original_softoken_mapped=0 original_freebl_mapped=0");
        return 0;
    }
    NSSNoDBInit init=(NSSNoDBInit)dlsym(h,"NSS_NoDB_Init");
    PK11GenerateRandom generate=(PK11GenerateRandom)dlsym(h,"PK11_GenerateRandom");
    NSSShutdown shutdown=(NSSShutdown)dlsym(h,"NSS_Shutdown");
    bool src=exact_original_library((const void*)init,argv[1]) &&
             exact_original_library((const void*)generate,argv[1]) &&
             exact_original_library((const void*)shutdown,argv[1]);
    if(!src){
        puts("NSS_PROBE_V1 native_nss_open=1 original_nss_symbols=0 init=-2 random=-2 nonzero=0 shutdown=-2 original_softoken_mapped=0 original_freebl_mapped=0");
        dlclose(h);
        return 0;
    }
    int init_rc=init(NULL);
    int rnd_rc=-2, shut_rc=-2;
    bool nonzero=false;
    char parent[PATH_MAX];
    size_t n=(size_t)(base-argv[1]);
    if(n>=sizeof(parent)){dlclose(h);return 2;}
    memcpy(parent,argv[1],n);parent[n]='\0';
    struct expected_modules mapped={.dir=parent,.softoken=false,.freebl=false};
    if(init_rc==0){
        unsigned char b[32]={0};
        rnd_rc=generate(b,(int)sizeof(b));
        if(rnd_rc==0)nonzero=any_nonzero(b,sizeof(b));
        memset(b,0,sizeof(b));
    }
    // Snapshot NSS provider ELF mappings before NSS_Shutdown() releases them.
    dl_iterate_phdr(find_original_modules,&mapped);
    if(init_rc==0)shut_rc=shutdown();
    printf("NSS_PROBE_V1 native_nss_open=1 original_nss_symbols=1 init=%d random=%d nonzero=%d shutdown=%d original_softoken_mapped=%d original_freebl_mapped=%d\n",
        init_rc,rnd_rc,(int)nonzero,shut_rc,(int)mapped.softoken,(int)mapped.freebl);
    dlclose(h);
    return 0;
}
