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
        puts("NSS_PROBE_V1 native_nss_open=0 original_nss_symbols=0 init=-2 random=-2 nonzero=0 shutdown=-2");
        return 0;
    }
    NSSNoDBInit init=(NSSNoDBInit)dlsym(h,"NSS_NoDB_Init");
    PK11GenerateRandom generate=(PK11GenerateRandom)dlsym(h,"PK11_GenerateRandom");
    NSSShutdown shutdown=(NSSShutdown)dlsym(h,"NSS_Shutdown");
    bool src=exact_original_library((const void*)init,argv[1]) &&
             exact_original_library((const void*)generate,argv[1]) &&
             exact_original_library((const void*)shutdown,argv[1]);
    if(!src){
        puts("NSS_PROBE_V1 native_nss_open=1 original_nss_symbols=0 init=-2 random=-2 nonzero=0 shutdown=-2");
        dlclose(h);
        return 0;
    }
    int init_rc=init(NULL);
    int rnd_rc=-2, shut_rc=-2;
    bool nonzero=false;
    if(init_rc==0){
        unsigned char b[32]={0};
        rnd_rc=generate(b,(int)sizeof(b));
        if(rnd_rc==0)nonzero=any_nonzero(b,sizeof(b));
        memset(b,0,sizeof(b));
        shut_rc=shutdown();
    }
    printf("NSS_PROBE_V1 native_nss_open=1 original_nss_symbols=1 init=%d random=%d nonzero=%d shutdown=%d\n",
        init_rc,rnd_rc,(int)nonzero,shut_rc);
    dlclose(h);
    return 0;
}
