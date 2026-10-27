// SPDX-License-Identifier: GPL-2.0-or-later
// A bounded virtual keymap.json, translated into the same records Studio uses.
// The protocol adapter is original code; no Work Louder implementation is embedded.
typedef struct { size_t start, end; } input_json_t;
static bool input_json_invalid;
static char input_file[INPUT_DOCUMENT_CAPACITY + 1];
static char input_pending[INPUT_DOCUMENT_CAPACITY + 1];
static char input_base64[4097];
static const char *const input_native_names[] = {
#define PAD_ACTION(id, wire, code) wire,
#include "native_actions.def"
#undef PAD_ACTION
};
_Static_assert(sizeof(input_native_names) / sizeof(input_native_names[0]) == PAD_ACTION_COUNT, "Native action catalog mismatch");

static input_json_t input_field(const char *json, input_json_t object, const char *name) {
    input_json_t found = {0, 0};
    size_t p = skip_space(json, object.end, object.start);
    if (p >= object.end || json[p++] != '{') { input_json_invalid = true; return found; }
    while ((p = skip_space(json, object.end, p)) < object.end && json[p] != '}') {
        char key[40];
        if (!parse_plain_string(json, object.end, &p, key, sizeof(key))) { input_json_invalid = true; break; }
        p = skip_space(json, object.end, p);
        if (p >= object.end || json[p++] != ':') { input_json_invalid = true; break; }
        p = skip_space(json, object.end, p);
        size_t start = p;
        if (!skip_value(json, object.end, &p)) { input_json_invalid = true; break; }
        if (strcmp(key, name) == 0) {
            if (found.end) input_json_invalid = true;
            found = (input_json_t){start, p};
        }
        p = skip_space(json, object.end, p);
        if (p < object.end && json[p] == ',') ++p;
        else break;
    }
    return found;
}
static size_t input_array(const char *json, input_json_t array, input_json_t *items, size_t capacity) {
    size_t p = skip_space(json, array.end, array.start), count = 0;
    if (p >= array.end || json[p++] != '[') { input_json_invalid = true; return 0; }
    while ((p = skip_space(json, array.end, p)) < array.end && json[p] != ']') {
        size_t start = p;
        if (!skip_value(json, array.end, &p) || count >= capacity) { input_json_invalid = true; return count; }
        items[count++] = (input_json_t){start, p};
        p = skip_space(json, array.end, p);
        if (p < array.end && json[p] == ',') ++p;
        else break;
    }
    return count;
}
static bool input_string(const char *json, input_json_t value, char *out, size_t capacity) {
    size_t p = value.start;
    return value.end && parse_plain_string(json, value.end, &p, out, capacity) && p == value.end;
}
static bool input_number(const char *json, input_json_t value, uint32_t *out, uint32_t maximum) {
    size_t p = value.start;
    return value.end && parse_u32(json, value.end, &p, out, maximum) && p == value.end;
}
static bool input_empty(const char *json, input_json_t object, const char *name) {
    input_json_t value = input_field(json, object, name);
    if (!value.end) return true;
    size_t p = skip_space(json, value.end, value.start);
    if (value.end - p == 4 && memcmp(json + p, "null", 4) == 0) return true;
    if (json[p] != '[' && json[p] != '{') return false;
    char closing = json[p++] == '[' ? ']' : '}';
    p = skip_space(json, value.end, p);
    return p + 1 == value.end && json[p] == closing;
}
static int input_action(const char *wire) {
    // The UI and QMK use a few different aliases for the same HID key.
    if (strcmp(wire, "KC_RIGHT") == 0) wire = "KC_RGHT";
    if (strcmp(wire, "KC_ENTER") == 0) wire = "KC_ENT";
    if (strcmp(wire, "KC_SPACE") == 0) wire = "KC_SPC";
    if (strcmp(wire, "KC_BSPACE") == 0) wire = "KC_BSPC";
    if (strcmp(wire, "KC_NO") == 0 || strcmp(wire, "KC_NONE") == 0) return 82;
    for (uint8_t i = 1; i < PAD_ACTION_COUNT; ++i)
        if (i != 95 && strcmp(wire, input_native_names[i]) == 0) return i;
    return -1;
}
static bool input_validate_document(const char *json, size_t length, uint8_t next[OAI_MAX_LAYERS][16]) {
    size_t end = 0;
    if (!skip_value(json, length, &end) || skip_space(json, length, end) != length) return false;
    input_json_invalid = false;
    input_json_t root = {0, length}, profiles[1], layers[OAI_MAX_LAYERS];
    uint32_t value;
    if (!input_number(json, input_field(json, root, "version"), &value, 1) || value != 1
        || !input_number(json, input_field(json, root, "activeProfileId"), &value, 0)) return false;
    const char *unsupported[] = {"macros", "multiActions", "linkedApps", "deviceSpecificConfig"};
    for (size_t i = 0; i < sizeof(unsupported) / sizeof(unsupported[0]); ++i)
        if (!input_empty(json, root, unsupported[i])) return false;
    if (input_array(json, input_field(json, root, "profiles"), profiles, 1) != 1
        || !input_number(json, input_field(json, profiles[0], "id"), &value, 0)) return false;
    size_t count=input_array(json,input_field(json,profiles[0],"layers"),layers,OAI_MAX_LAYERS);
    if (count<4 || count>OAI_MAX_LAYERS) return false;
    memset(&input_prepared,0,sizeof(input_prepared));
    input_prepared.count=(uint8_t)count;
    input_json_t profile_name=input_field(json,profiles[0],"name");
    if (!profile_name.end || json[profile_name.start]!='"' || profile_name.end-profile_name.start>=INPUT_NAME_CAPACITY) return false;
    memcpy(input_prepared.profile_name,json+profile_name.start,profile_name.end-profile_name.start);
    for (uint8_t l = 0; l < count; ++l) {
        if (!input_number(json, input_field(json, layers[l], "id"), &value, 65535)) return false;
        for (uint8_t earlier=0;earlier<l;++earlier) if (input_prepared.layers[earlier].id==value) return false;
        input_prepared.layers[l].id=(uint16_t)value;
        input_json_t name=input_field(json,layers[l],"name"), os=input_field(json,layers[l],"os");
        if (!name.end || json[name.start]!='"' || name.end-name.start>=INPUT_NAME_CAPACITY) return false;
        memcpy(input_prepared.layers[l].name,json+name.start,name.end-name.start);
        if (os.end) {
            if (!input_number(json,os,&value,1)) return false;
            input_prepared.layers[l].os=(uint8_t)value;
        }
        if (!input_empty(json, layers[l], "linkedAppId")) return false;
        if (!input_number(json, input_field(json, layers[l], "color"), &value, 0xFFFFFF)) return false;
        next[l][13] = value >> 16; next[l][14] = value >> 8; next[l][15] = value;
        input_json_t layout = input_field(json, layers[l], "layout"), rows[4];
        if (!input_empty(json, layout, "buttons")
            || input_array(json, input_field(json, layout, "keymap"), rows, 4) != 4) return false;
        uint8_t position = 0;
        const uint8_t widths[] = {2, 4, 4, 3};
        for (uint8_t r = 0; r < 4; ++r) {
            input_json_t keys[4];
            if (input_array(json, rows[r], keys, 4) != widths[r]) return false;
            for (uint8_t k = 0; k < widths[r]; ++k) {
                char wire[32];
                if (!input_string(json, keys[k], wire, sizeof(wire))) return false;
                int action = input_action(wire);
                if (action < 0 || (action>=136 && (size_t)((action-136)%16)>=count)) return false;
                next[l][position] = (l == 0 && action == 82 + oai_keymap[position]) ? 0 : (uint8_t)action;
                ++position;
            }
        }
        input_json_t encoders[1], controls[3];
        if (input_array(json, input_field(json, layout, "encoders"), encoders, 1) != 1
            || input_array(json, encoders[0], controls, 3) != 3) return false;
        const char *fixed[] = {"KV_OAI_ENC_CC", "KV_OAI_ENC_CW", "KV_OAI_ENC_CLK"};
        for (uint8_t k = 0; k < 3; ++k) {
            char wire[24];
            if (!input_string(json, controls[k], wire, sizeof(wire)) || (strcmp(wire, fixed[k]) != 0 && !(l>=4 && strcmp(wire,"KC_NONE")==0))) return false;
        }
        input_json_t joystick = input_field(json, layout, "joystick");
        char type[12];
        if (!input_string(json, input_field(json, joystick, "type"), type, sizeof(type))) return false;
        if (strcmp(type,"VENDOR")==0) {
            if (!input_empty(json,joystick,"sectors")) return false;
        } else if (l>=4 && strcmp(type,"RADIAL")==0) {
            input_json_t sectors[2];
            if (input_array(json,input_field(json,joystick,"sectors"),sectors,2)!=2) return false;
            for (uint8_t k=0;k<2;++k) {
                char wire[16];
                if (!input_string(json,input_field(json,sectors[k],"k"),wire,sizeof(wire))
                    || strcmp(wire,k==0 ? "KI_X" : "KC_NONE")!=0) return false;
            }
        } else return false;
    }
    return !input_json_invalid;
}

// SHA-1 is required by Input's post-write checksum comparison, not used for security.
static uint32_t input_rol(uint32_t x, uint8_t n) { return (x << n) | (x >> (32 - n)); }
static void input_sha1(const char *data, size_t length, char hex[41]) {
    uint32_t h[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};
    size_t padded = (length + 9 + 63) & ~(size_t)63;
    for (size_t block = 0; block < padded; block += 64) {
        uint32_t w[80] = {0};
        for (size_t i = 0; i < 64; ++i) {
            size_t index = block + i;
            uint8_t byte = index < length ? (uint8_t)data[index] : index == length ? 0x80 : 0;
            if (index >= padded - 8) byte = (uint8_t)(((uint64_t)length * 8) >> ((padded - index - 1) * 8));
            w[i / 4] |= (uint32_t)byte << (24 - (i % 4) * 8);
        }
        for (uint8_t i = 16; i < 80; ++i) w[i] = input_rol(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
        uint32_t a=h[0], b=h[1], c=h[2], d=h[3], e=h[4];
        for (uint8_t i = 0; i < 80; ++i) {
            uint32_t f, k;
            if (i < 20) { f=(b & c) | (~b & d); k=0x5A827999; }
            else if (i < 40) { f=b ^ c ^ d; k=0x6ED9EBA1; }
            else if (i < 60) { f=(b & c) | (b & d) | (c & d); k=0x8F1BBCDC; }
            else { f=b ^ c ^ d; k=0xCA62C1D6; }
            uint32_t t=input_rol(a,5)+f+e+k+w[i]; e=d; d=c; c=input_rol(b,30); b=a; a=t;
        }
        h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d; h[4]+=e;
    }
    for (uint8_t i=0; i<20; ++i) {
        uint8_t b=(uint8_t)(h[i/4] >> (24-(i%4)*8));
        hex[2*i]=hex_digit(b >> 4); hex[2*i+1]=hex_digit(b & 15);
    }
    hex[40]=0;
}

static uint16_t input_get_file(void) {
    if (input_cache_length && memcmp(input_cache_oai,oai_keymap,sizeof(input_cache_oai))==0) {
        memcpy(input_file,input_cache,input_cache_length);
        input_file[input_cache_length]=0;
        return input_cache_length;
    }
    size_t n = 0;
#define INPUT_PRINT(...) do { \
    int count = snprintf(input_file+n, sizeof(input_file)-n, __VA_ARGS__); \
    if (count < 0 || (size_t)count >= sizeof(input_file)-n) return 0; \
    n += (size_t)count; \
} while (0)
    INPUT_PRINT("{\"version\":1,\"activeProfileId\":0,\"language\":0,\"profiles\":[{\"id\":0,\"name\":%s,\"layers\":[",input_store.profile_name[0] ? input_store.profile_name : "\"AgentPad13\"");
    const char *names[] = {"CODEX", "FN", "NAV", "MEDIA"};
    for (uint8_t l=0; l<codex_pad_layer_count(); ++l) {
        uint32_t color=((uint32_t)pad_config[l][13]<<16)|((uint32_t)pad_config[l][14]<<8)|pad_config[l][15];
        char default_name[24];
        if (l<4) snprintf(default_name,sizeof(default_name),"\"%s\"",names[l]);
        else snprintf(default_name,sizeof(default_name),"\"LAYER %u\"",l+1);
        const input_layer_metadata_t *meta=&input_store.layers[l];
        unsigned id=input_store.count ? meta->id : l;
        INPUT_PRINT("%s{\"id\":%u,\"name\":%s,\"color\":%lu,\"os\":%u,\"layout\":{\"keymap\":[", l ? "," : "", id, meta->name[0] ? meta->name : default_name, (unsigned long)color,meta->os);
        const uint8_t widths[]={2,4,4,3};
        uint8_t pos=0;
        for (uint8_t row=0; row<4; ++row) {
            INPUT_PRINT("%s[",row ? "," : "");
            for (uint8_t key=0; key<widths[row]; ++key, ++pos) {
                uint8_t action=pad_config[l][pos];
                if (l == 0 && action == 0) action = 82 + oai_keymap[pos];
                else if (action == 0) action = 82;
                INPUT_PRINT("%s\"%s\"",key ? "," : "",input_native_names[action]);
            }
            INPUT_PRINT("]");
        }
        INPUT_PRINT("],\"encoders\":[[\"KV_OAI_ENC_CC\",\"KV_OAI_ENC_CW\",\"KV_OAI_ENC_CLK\"]],\"joystick\":{\"type\":\"VENDOR\",\"sectors\":[]}}}");
    }
    INPUT_PRINT("]}],\"macros\":[],\"multiActions\":[],\"macrosGroups\":[],\"multiActionsGroups\":[]}");
#undef INPUT_PRINT
    return (uint16_t)n;
}

// Streaming replies keep both stack and report boundaries bounded.
static uint8_t input_tx[OAI_REPORT_SIZE], input_tx_length;
static void input_flush(void) {
    if (!input_tx_length) return;
    input_tx[0]=OAI_REPORT_ID; input_tx[1]=OAI_CHANNEL_RPC; input_tx[2]=input_tx_length;
    raw_hid_send(input_tx, OAI_REPORT_SIZE);
    memset(input_tx,0,sizeof(input_tx)); input_tx_length=0;
}
static void input_send_char(char c) {
    input_tx[3+input_tx_length++]=(uint8_t)c;
    if (input_tx_length == OAI_MAX_PAYLOAD) input_flush();
}
static void input_send_text(const char *text) { while (*text) input_send_char(*text++); }
static void input_reply_end(uint16_t id) {
    char tail[20];
    snprintf(tail,sizeof(tail),",\"id\":%u}\r\n",(unsigned)id);
    input_send_text(tail); input_flush();
}
static void input_error(uint16_t id) {
    send_response("{\"error\":{\"code\":-32602,\"message\":\"Unsupported or invalid keymap\"},\"id\":", id);
}
static const char input_b64[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static int input_b64_value(char c) {
    const char *p = c ? strchr(input_b64,c) : NULL;
    return p ? (int)(p-input_b64) : -1;
}
static bool input_decode_chunk(const char *text, size_t *written) {
    size_t length=strlen(text), output=0;
    if (length % 4) return false;
    for (size_t i=0; i<length; i+=4) {
        int a=input_b64_value(text[i]), b=input_b64_value(text[i+1]);
        int c=text[i+2]=='=' ? 0 : input_b64_value(text[i+2]);
        int d=text[i+3]=='=' ? 0 : input_b64_value(text[i+3]);
        bool pad2=text[i+2]=='=', pad1=text[i+3]=='=';
        if (a<0||b<0||c<0||d<0 || (pad2&&!pad1) || ((pad1||pad2)&&i+4!=length)
            || (pad2 && (b&15)) || (pad1 && !pad2 && (c&3))) return false;
        uint32_t bits=(uint32_t)a<<18|(uint32_t)b<<12|(uint32_t)c<<6|(uint32_t)d;
        uint8_t count=pad2 ? 1 : pad1 ? 2 : 3;
        if (input_pending_length+output+count>INPUT_DOCUMENT_CAPACITY) return false;
        for (uint8_t j=0;j<count;++j) input_pending[input_pending_length+output++]=(char)(bits>>(16-j*8));
    }
    *written=output;
    return true;
}
static bool input_fs_request(const char *json, const oai_request_t *request) {
    input_json_invalid=false;
    input_json_t params={request->params_start,request->params_end};
    if (strcmp(request->method,"fs.list")==0) {
        uint16_t size=input_get_file(); char checksum[41],prefix[96];
        input_sha1(input_file,size,checksum);
        snprintf(prefix,sizeof(prefix),"{\"result\":[{\"name\":\"keymap.json\",\"size\":%u,\"checksum\":\"",size);
        input_send_text(prefix); input_send_text(checksum); input_send_text("\"}]"); input_reply_end(request->id);
        return true;
    }
    char file[24];
    if (!input_string(json,input_field(json,params,"file"),file,sizeof(file)) || strcmp(file,"keymap.json")!=0 || input_json_invalid) {
        input_writing=false; input_error(request->id); return true;
    }
    if (strcmp(request->method,"fs.readbin")==0) {
        uint32_t offset=0,len=0;
        uint16_t size=input_get_file();
        if (!input_number(json,input_field(json,params,"offset"),&offset,size)
            || !input_number(json,input_field(json,params,"len"),&len,3072) || input_json_invalid) {
            input_error(request->id); return true;
        }
        if (len>size-offset) len=size-offset;
        // Small replies also fit other clients' decoders on the shared endpoint.
        if (len>192) len=192;
        char prefix[64];
        snprintf(prefix,sizeof(prefix),"{\"result\":{\"total_size\":%u,\"data\":\"",size);
        input_send_text(prefix);
        for (uint32_t i=0;i<len;i+=3) {
            uint32_t word=(uint32_t)(uint8_t)input_file[offset+i]<<16;
            if(i+1<len) word|=(uint32_t)(uint8_t)input_file[offset+i+1]<<8;
            if(i+2<len) word|=(uint8_t)input_file[offset+i+2];
            input_send_char(input_b64[(word>>18)&63]); input_send_char(input_b64[(word>>12)&63]);
            input_send_char(i+1<len ? input_b64[(word>>6)&63] : '=');
            input_send_char(i+2<len ? input_b64[word&63] : '=');
        }
        input_send_text("\"}"); input_reply_end(request->id); return true;
    }
    if (strcmp(request->method,"fs.read")==0) {
        input_get_file(); input_send_text("{\"result\":"); input_send_text(input_file); input_reply_end(request->id); return true;
    }
    bool complete=true;
    if (strcmp(request->method,"fs.writebin")==0) {
        uint32_t offset;
        bool append=false;
        input_json_t done=input_field(json,params,"completed"), app=input_field(json,params,"append");
        size_t cursor=done.start;
        if (!done.end || !parse_bool(json,done.end,&cursor,&complete) || cursor!=done.end) goto invalid;
        cursor=app.start;
        if (!app.end || !parse_bool(json,app.end,&cursor,&append) || cursor!=app.end || !append
            || !input_empty(json,params,"tx")
            || !input_number(json,input_field(json,params,"offset"),&offset,INPUT_DOCUMENT_CAPACITY)
            || !input_string(json,input_field(json,params,"data"),input_base64,sizeof(input_base64)) || input_json_invalid) goto invalid;
        if (offset==0) {
            input_pending_length=0; input_writing=true; input_write_revision=input_config_revision;
        }
        if (!input_writing || offset!=input_pending_length || input_write_revision!=input_config_revision) goto invalid;
        size_t added=0;
        if (!input_decode_chunk(input_base64,&added) || added==0) goto invalid;
        input_pending_length+=(uint16_t)added;
    } else if (strcmp(request->method,"fs.write")==0) {
        input_json_t data=input_field(json,params,"data");
        if (!data.end || data.end-data.start>INPUT_DOCUMENT_CAPACITY || input_json_invalid) goto invalid;
        input_pending_length=(uint16_t)(data.end-data.start);
        memcpy(input_pending,json+data.start,input_pending_length);
    } else {
        send_response("{\"error\":{\"code\":-32601,\"message\":\"Unsupported on AgentPad13\"},\"id\":",request->id); return true;
    }
    if (complete) {
        uint8_t next[OAI_MAX_LAYERS][16] = {{0}};
        input_writing=false;
        input_pending[input_pending_length]=0;
        if (!input_validate_document(input_pending,input_pending_length,next)
            || !input_persist(&next[0][0],input_pending,input_pending_length)) goto invalid;
        memcpy(pad_config,next,sizeof(next));
    }
    send_response("{\"result\":true,\"id\":",request->id); return true;
invalid:
    input_writing=false; input_pending_length=0; input_error(request->id); return true;
}
