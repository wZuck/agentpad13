// SPDX-License-Identifier: GPL-2.0-or-later
// Persist compact maps/metadata in the existing EEPROM. Exact upload bytes
// are a runtime cache; after reboot keymap.json is regenerated from this record.
#define INPUT_DOCUMENT_CAPACITY 16384U
#define INPUT_STORAGE_ADDRESS 192U
#define INPUT_STORAGE_MAGIC 0x324B5041UL
#define INPUT_NAME_CAPACITY 128U

typedef struct {
    uint16_t id;
    uint8_t os;
    char name[INPUT_NAME_CAPACITY]; // JSON string literal, including quotes.
} input_layer_metadata_t;
typedef struct {
    uint32_t magic, checksum;
    uint8_t count;
    uint8_t maps[OAI_MAX_LAYERS * 16];
    char profile_name[INPUT_NAME_CAPACITY];
    input_layer_metadata_t layers[OAI_MAX_LAYERS];
} input_store_t;
_Static_assert(INPUT_STORAGE_ADDRESS + sizeof(input_store_t) <= 4096, "Input storage exceeds logical EEPROM");
static input_store_t input_store, input_candidate, input_prepared;
static char input_cache[INPUT_DOCUMENT_CAPACITY + 1];
static uint16_t input_cache_length;
static uint8_t input_cache_oai[OAI_KEYMAP_POSITION_COUNT];
static uint32_t input_config_revision;
static uint16_t input_pending_length;
static bool input_writing;
static uint32_t input_write_revision;
uint8_t codex_pad_layer_count(void) {
    return input_store.count >= 4 && input_store.count <= OAI_MAX_LAYERS ? input_store.count : 4;
}
static uint32_t input_hash(const uint8_t *bytes, size_t length) {
    uint32_t hash = 2166136261UL;
    for (size_t i=0; i<length; ++i) hash=(hash ^ bytes[i])*16777619UL;
    return hash;
}
static uint32_t input_store_checksum(const input_store_t *store) {
    return input_hash((const uint8_t *)store + offsetof(input_store_t,count), sizeof(*store)-offsetof(input_store_t,count));
}
static bool input_commit_candidate(const void *maps, const char *document, uint16_t length) {
    if (length > INPUT_DOCUMENT_CAPACITY) return false;
    input_candidate.magic = INPUT_STORAGE_MAGIC;
    memcpy(input_candidate.maps,maps,sizeof(input_candidate.maps));
    input_candidate.checksum=input_store_checksum(&input_candidate);
#if defined(CODEX_OAI_HAS_WEAR_LEVELING)
    if (wear_leveling_write(INPUT_STORAGE_ADDRESS,&input_candidate,sizeof(input_candidate))==WEAR_LEVELING_FAILED) return false;
#endif
    memcpy(&input_store,&input_candidate,sizeof(input_store));
    input_cache_length=length;
    if (length) memcpy(input_cache,document,length);
    memcpy(input_cache_oai,oai_keymap,sizeof(input_cache_oai));
    ++input_config_revision;
    return true;
}
static bool input_persist(const void *maps, const char *document, uint16_t length) {
    memcpy(&input_candidate,document ? &input_prepared : &input_store,sizeof(input_candidate));
    if (!document) {
        input_candidate.count=codex_pad_layer_count();
        if (!input_store.count) for (uint8_t l=0;l<OAI_MAX_LAYERS;++l) input_candidate.layers[l].id=l;
    }
    return input_commit_candidate(maps,document,length);
}
static bool input_resize(uint8_t count, const void *maps) {
    if (count<4 || count>OAI_MAX_LAYERS) return false;
    memcpy(&input_candidate,&input_store,sizeof(input_candidate));
    uint8_t old=codex_pad_layer_count();
    if (!input_store.count) for (uint8_t l=0;l<OAI_MAX_LAYERS;++l) input_candidate.layers[l].id=l;
    input_candidate.count=count;
    for (uint8_t l=old;l<count;++l) {
        memset(&input_candidate.layers[l],0,sizeof(input_candidate.layers[l]));
        input_candidate.layers[l].id=l;
    }
    return input_commit_candidate(maps,NULL,0);
}
static bool input_load(void *maps) {
    memset(&input_store,0,sizeof(input_store));
    input_cache_length=0;
#if defined(CODEX_OAI_HAS_WEAR_LEVELING)
    uint32_t magic=0;
    if (wear_leveling_read(INPUT_STORAGE_ADDRESS,&magic,sizeof(magic))!=WEAR_LEVELING_SUCCESS) return false;
    // Migrate the earlier four-layer Input record without moving flash.
    if (magic==0x314B5041UL) {
        if (wear_leveling_read(INPUT_STORAGE_ADDRESS,input_cache,3676)!=WEAR_LEVELING_SUCCESS) return false;
        uint16_t length; uint32_t checksum;
        memcpy(&length,input_cache+8,2); memcpy(&checksum,input_cache+4,4);
        if (length>3584 || checksum!=input_hash((const uint8_t *)input_cache+8,81+length)) return false;
        input_store.count=4;
        memcpy(input_store.maps,input_cache+10,64);
        for (uint8_t l=0;l<4;++l) input_store.layers[l].id=l;
        memcpy(input_cache_oai,input_cache+74,sizeof(input_cache_oai));
        memmove(input_cache,input_cache+89,length);
        input_cache_length=length;
    } else {
        if (wear_leveling_read(INPUT_STORAGE_ADDRESS,&input_store,sizeof(input_store))!=WEAR_LEVELING_SUCCESS) return false;
        if (input_store.magic!=INPUT_STORAGE_MAGIC || input_store.count<4 || input_store.count>OAI_MAX_LAYERS
            || input_store.checksum!=input_store_checksum(&input_store)) goto invalid;
    }
#endif
    for (uint8_t l=0;l<codex_pad_layer_count();++l)
        for (uint8_t p=0;p<13;++p)
            if (input_store.maps[l*16+p]>=PAD_ACTION_COUNT || input_store.maps[l*16+p]==95) goto invalid;
    if (input_store.count) memcpy(maps,input_store.maps,input_store.count*16);
    return input_store.count!=0;
invalid:
    memset(&input_store,0,sizeof(input_store)); input_cache_length=0;
    return false;
}
