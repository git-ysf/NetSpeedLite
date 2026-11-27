/*
 * NetSpeedLite for Linux — Ultra-featherlight zero-dependency network monitor
 * Reads /proc/net/dev directly with microsecond monotonic deltas.
 *
 * Modes:
 *   --waybar   Streaming JSON lines for Waybar custom module (with sparkline)
 *   --polybar  Streaming formatted lines for Polybar custom/script module
 *   --tui      Live terminal UI with sparkline, colors, and interface stats
 *   --once     Single human-readable snapshot and exit
 *   --json     Single JSON snapshot and exit
 *
 * License: MIT
 */

#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define NSL_VERSION     "1.1.0"
#define PROC_NET_DEV    "/proc/net/dev"
#define MAX_IFACES      64
#define IFACE_NAME_LEN  32
#define SPARK_LEN       24
#define DEFAULT_MS      1000
#define MIN_MS          100
#define MAX_MS          60000

typedef enum {
    MODE_AUTO = 0,
    MODE_WAYBAR,
    MODE_POLYBAR,
    MODE_TUI,
    MODE_ONCE,
    MODE_JSON
} RunMode;

typedef enum {
    UNIT_AUTO = 0,
    UNIT_BYTES,
    UNIT_BITS
} UnitMode;

typedef enum {
    THEME_DARK = 0,
    THEME_LIGHT,
    THEME_NORD,
    THEME_DRACULA,
    THEME_CATPPUCCIN,
    THEME_MONO
} ThemeId;

typedef struct {
    const char *name;
    const char *tx_ansi;
    const char *rx_ansi;
    const char *accent_ansi;
    const char *muted_ansi;
    const char *border_ansi;
    const char *tx_hex;
    const char *rx_hex;
} Theme;

static const Theme THEMES[] = {
    { "dark",       "\033[38;2;56;189;248m",  "\033[38;2;52;211;153m",  "\033[38;2;129;140;248m", "\033[38;2;148;163;184m", "\033[38;2;71;85;105m",   "#38BDF8", "#34D399" },
    { "light",      "\033[38;2;37;99;235m",   "\033[38;2;5;150;105m",   "\033[38;2;79;70;229m",   "\033[38;2;100;116;139m", "\033[38;2;148;163;184m", "#2563EB", "#059669" },
    { "nord",       "\033[38;2;136;192;208m", "\033[38;2;163;190;140m", "\033[38;2;129;161;193m", "\033[38;2;143;156;179m", "\033[38;2;76;86;106m",   "#88C0D0", "#A3BE8C" },
    { "dracula",    "\033[38;2;139;233;253m", "\033[38;2;80;250;123m",  "\033[38;2;189;147;249m", "\033[38;2;98;114;164m",  "\033[38;2;68;71;90m",    "#8BE9FD", "#50FA7B" },
    { "catppuccin", "\033[38;2;137;180;250m", "\033[38;2;166;227;161m", "\033[38;2;203;166;247m", "\033[38;2;166;173;200m", "\033[38;2;88;91;112m",   "#89B4FA", "#A6E3A1" },
    { "mono",       "\033[1m",                "\033[1m",                "\033[0m",                "\033[2m",                "\033[2m",                "#FFFFFF", "#CCCCCC" }
};

typedef struct {
    char     name[IFACE_NAME_LEN];
    uint64_t rx_bytes;
    uint64_t tx_bytes;
} IfaceSample;

typedef struct {
    IfaceSample ifaces[MAX_IFACES];
    size_t      count;
    uint64_t    total_rx;
    uint64_t    total_tx;
    double      timestamp_s;
} NetSnapshot;

typedef struct {
    char   name[IFACE_NAME_LEN];
    double rx_bps;
    double tx_bps;
    uint64_t rx_total;
    uint64_t tx_total;
} IfaceRate;

typedef struct {
    RunMode  mode;
    UnitMode unit;
    ThemeId  theme;
    int      interval_ms;
    bool     sparkline;
    bool     color;
    char     iface_filter[IFACE_NAME_LEN];
} Config;

static volatile sig_atomic_t g_running = 1;

static void handle_signal(int sig) {
    (void)sig;
    g_running = 0;
}

static void setup_signals(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);
}

static double monotonic_seconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0.0;
    }
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void sleep_ms(int ms) {
    struct timespec req;
    req.tv_sec = ms / 1000;
    req.tv_nsec = (long)(ms % 1000) * 1000000L;
    while (nanosleep(&req, &req) == -1 && errno == EINTR && g_running) {
        /* continue remaining sleep unless interrupted by exit signal */
    }
}

static bool is_virtual_ignored(const char *name) {
    return strcmp(name, "lo") == 0;
}

static bool read_proc_net_dev(NetSnapshot *snap, const char *iface_filter) {
    FILE *fp = fopen(PROC_NET_DEV, "r");
    if (!fp) {
        return false;
    }

    memset(snap, 0, sizeof(*snap));
    snap->timestamp_s = monotonic_seconds();

    char line[512];
    int line_no = 0;
    while (fgets(line, sizeof(line), fp) != NULL) {
        line_no++;
        if (line_no <= 2) {
            continue; /* Skip header lines */
        }

        char *colon = strchr(line, ':');
        if (!colon) {
            continue;
        }

        *colon = '\0';
        char *name = line;
        while (*name && isspace((unsigned char)*name)) {
            name++;
        }
        char *end = name + strlen(name);
        while (end > name && isspace((unsigned char)end[-1])) {
            end--;
        }
        *end = '\0';

        if (name[0] == '\0') {
            continue;
        }
        if (iface_filter[0] != '\0') {
            if (strcmp(name, iface_filter) != 0) {
                continue;
            }
        } else if (is_virtual_ignored(name)) {
            continue;
        }

        uint64_t rx_bytes = 0, tx_bytes = 0;
        uint64_t dummy = 0;
        int matched = sscanf(
            colon + 1,
            "%" SCNu64 " %" SCNu64 " %" SCNu64 " %" SCNu64
            " %" SCNu64 " %" SCNu64 " %" SCNu64 " %" SCNu64
            " %" SCNu64,
            &rx_bytes, &dummy, &dummy, &dummy,
            &dummy, &dummy, &dummy, &dummy,
            &tx_bytes
        );

        if (matched < 9) {
            continue;
        }

        if (snap->count < MAX_IFACES) {
            IfaceSample *s = &snap->ifaces[snap->count++];
            snprintf(s->name, sizeof(s->name), "%s", name);
            s->rx_bytes = rx_bytes;
            s->tx_bytes = tx_bytes;
        }
        snap->total_rx += rx_bytes;
        snap->total_tx += tx_bytes;
    }

    fclose(fp);
    return true;
}

static const IfaceSample *find_iface(const NetSnapshot *snap, const char *name) {
    for (size_t i = 0; i < snap->count; i++) {
        if (strcmp(snap->ifaces[i].name, name) == 0) {
            return &snap->ifaces[i];
        }
    }
    return NULL;
}

static void format_rate(double bytes_per_sec, UnitMode unit, char *buf, size_t len) {
    if (bytes_per_sec < 0.0) {
        bytes_per_sec = 0.0;
    }

    if (unit == UNIT_BITS) {
        double bits = bytes_per_sec * 8.0;
        if (bits < 1000.0) {
            snprintf(buf, len, "%6.0f bps", bits);
        } else if (bits < 1000.0 * 1000.0) {
            snprintf(buf, len, "%6.2f Kbps", bits / 1000.0);
        } else if (bits < 1000.0 * 1000.0 * 1000.0) {
            snprintf(buf, len, "%6.2f Mbps", bits / (1000.0 * 1000.0));
        } else {
            snprintf(buf, len, "%6.2f Gbps", bits / (1000.0 * 1000.0 * 1000.0));
        }
        return;
    }

    /* Binary/SI-friendly byte units matching NetSpeedLite Windows display */
    if (bytes_per_sec < 1024.0) {
        snprintf(buf, len, "%6.0f B/s", bytes_per_sec);
    } else if (bytes_per_sec < 1024.0 * 1024.0) {
        snprintf(buf, len, "%6.2f KB/s", bytes_per_sec / 1024.0);
    } else if (bytes_per_sec < 1024.0 * 1024.0 * 1024.0) {
        snprintf(buf, len, "%6.2f MB/s", bytes_per_sec / (1024.0 * 1024.0));
    } else {
        snprintf(buf, len, "%6.2f GB/s", bytes_per_sec / (1024.0 * 1024.0 * 1024.0));
    }
}

static void format_rate_compact(double bytes_per_sec, UnitMode unit, char *buf, size_t len) {
    char tmp[32];
    format_rate(bytes_per_sec, unit, tmp, sizeof(tmp));
    const char *p = tmp;
    while (*p == ' ') {
        p++;
    }
    snprintf(buf, len, "%s", p);
}

static void format_bytes_total(uint64_t bytes, char *buf, size_t len) {
    double v = (double)bytes;
    if (v < 1024.0) {
        snprintf(buf, len, "%" PRIu64 " B", bytes);
    } else if (v < 1024.0 * 1024.0) {
        snprintf(buf, len, "%.1f KB", v / 1024.0);
    } else if (v < 1024.0 * 1024.0 * 1024.0) {
        snprintf(buf, len, "%.2f MB", v / (1024.0 * 1024.0));
    } else {
        snprintf(buf, len, "%.2f GB", v / (1024.0 * 1024.0 * 1024.0));
    }
}

static void build_sparkline(const double *history, size_t count, size_t width, char *out, size_t out_len) {
    static const char *BLOCKS[8] = {
        "\xe2\x96\x81", "\xe2\x96\x82", "\xe2\x96\x83", "\xe2\x96\x84",
        "\xe2\x96\x85", "\xe2\x96\x86", "\xe2\x96\x87", "\xe2\x96\x88"
    };

    if (out_len == 0) {
        return;
    }
    out[0] = '\0';
    if (width == 0 || count == 0) {
        return;
    }

    if (width > count) {
        width = count;
    }
    size_t start = count - width;

    double max_val = 1024.0; /* 1 KB/s floor so idle stays flat */
    for (size_t i = start; i < count; i++) {
        if (history[i] > max_val) {
            max_val = history[i];
        }
    }

    size_t pos = 0;
    for (size_t i = start; i < count; i++) {
        double norm = history[i] / max_val;
        if (norm < 0.0) norm = 0.0;
        if (norm > 1.0) norm = 1.0;
        int idx = (int)(norm * 7.0 + 0.5);
        if (idx < 0) idx = 0;
        if (idx > 7) idx = 7;

        const char *blk = BLOCKS[idx];
        size_t blen = strlen(blk);
        if (pos + blen + 1 >= out_len) {
            break;
        }
        memcpy(out + pos, blk, blen);
        pos += blen;
    }
    out[pos] = '\0';
}

static void json_escape(const char *src, char *dst, size_t dst_len) {
    size_t j = 0;
    for (size_t i = 0; src[i] != '\0' && j + 2 < dst_len; i++) {
        unsigned char c = (unsigned char)src[i];
        if (c == '"' || c == '\\') {
            if (j + 3 >= dst_len) break;
            dst[j++] = '\\';
            dst[j++] = (char)c;
        } else if (c == '\n') {
            if (j + 3 >= dst_len) break;
            dst[j++] = '\\';
            dst[j++] = 'n';
        } else if (c == '\r') {
            if (j + 3 >= dst_len) break;
            dst[j++] = '\\';
            dst[j++] = 'r';
        } else if (c == '\t') {
            if (j + 3 >= dst_len) break;
            dst[j++] = '\\';
            dst[j++] = 't';
        } else if (c < 0x20) {
            continue;
        } else {
            dst[j++] = (char)c;
        }
    }
    dst[j] = '\0';
}

static int get_term_width(void) {
#ifdef TIOCGWINSZ
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 20) {
        return (int)ws.ws_col;
    }
#endif
    return 80;
}

static void print_usage(const char *prog) {
    printf(
        "NetSpeedLite v%s (Linux) — Ultra-featherlight native network speed monitor\n\n"
        "Usage: %s [OPTIONS]\n\n"
        "Modes:\n"
        "  --waybar            Stream Waybar custom module JSON lines (with sparkline)\n"
        "  --polybar           Stream Polybar formatted output lines\n"
        "  --tui               Live interactive terminal UI with sparkline & colors\n"
        "  --once              Print a single human-readable snapshot and exit\n"
        "  --json              Print a single JSON snapshot and exit\n\n"
        "Options:\n"
        "  -i, --iface <name>  Monitor specific interface (default: all non-lo)\n"
        "  -t, --interval <ms> Sampling interval in ms (%d-%d, default: %d)\n"
        "  -u, --unit <mode>   Unit display: bytes (default) or bits\n"
        "  --theme <name>      Theme: dark, light, nord, dracula, catppuccin, mono\n"
        "  --no-sparkline      Disable sparkline in Waybar/TUI output\n"
        "  --no-color          Disable ANSI/Polybar color tags\n"
        "  -h, --help          Show this help message\n"
        "  -v, --version       Show version\n",
        NSL_VERSION, prog, MIN_MS, MAX_MS, DEFAULT_MS
    );
}

static bool parse_theme(const char *s, ThemeId *out) {
    size_t n = sizeof(THEMES) / sizeof(THEMES[0]);
    for (size_t i = 0; i < n; i++) {
        if (strcmp(s, THEMES[i].name) == 0) {
            *out = (ThemeId)i;
            return true;
        }
    }
    return false;
}

static bool parse_args(int argc, char **argv, Config *cfg) {
    cfg->mode = MODE_AUTO;
    cfg->unit = UNIT_BYTES;
    cfg->theme = THEME_DARK;
    cfg->interval_ms = DEFAULT_MS;
    cfg->sparkline = true;
    cfg->color = true;
    cfg->iface_filter[0] = '\0';

    for (int i = 1; i < argc; i++) {
        const char *arg = argv[i];
        if (strcmp(arg, "--waybar") == 0) {
            cfg->mode = MODE_WAYBAR;
        } else if (strcmp(arg, "--polybar") == 0) {
            cfg->mode = MODE_POLYBAR;
        } else if (strcmp(arg, "--tui") == 0) {
            cfg->mode = MODE_TUI;
        } else if (strcmp(arg, "--once") == 0) {
            cfg->mode = MODE_ONCE;
        } else if (strcmp(arg, "--json") == 0) {
            cfg->mode = MODE_JSON;
        } else if (strcmp(arg, "--no-sparkline") == 0) {
            cfg->sparkline = false;
        } else if (strcmp(arg, "--no-color") == 0) {
            cfg->color = false;
        } else if (strcmp(arg, "-i") == 0 || strcmp(arg, "--iface") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: %s requires an interface name\n", arg);
                return false;
            }
            snprintf(cfg->iface_filter, sizeof(cfg->iface_filter), "%s", argv[++i]);
        } else if (strcmp(arg, "-t") == 0 || strcmp(arg, "--interval") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: %s requires milliseconds\n", arg);
                return false;
            }
            long ms = strtol(argv[++i], NULL, 10);
            if (ms < MIN_MS || ms > MAX_MS) {
                fprintf(stderr, "Error: interval must be between %d and %d ms\n", MIN_MS, MAX_MS);
                return false;
            }
            cfg->interval_ms = (int)ms;
        } else if (strcmp(arg, "-u") == 0 || strcmp(arg, "--unit") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: %s requires 'bytes' or 'bits'\n", arg);
                return false;
            }
            const char *u = argv[++i];
            if (strcmp(u, "bytes") == 0 || strcmp(u, "auto") == 0) {
                cfg->unit = UNIT_BYTES;
            } else if (strcmp(u, "bits") == 0) {
                cfg->unit = UNIT_BITS;
            } else {
                fprintf(stderr, "Error: unknown unit '%s' (use bytes or bits)\n", u);
                return false;
            }
        } else if (strcmp(arg, "--theme") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "Error: --theme requires a theme name\n");
                return false;
            }
            if (!parse_theme(argv[++i], &cfg->theme)) {
                fprintf(stderr, "Error: unknown theme '%s'\n", argv[i]);
                return false;
            }
        } else if (strcmp(arg, "-h") == 0 || strcmp(arg, "--help") == 0) {
            print_usage(argv[0]);
            exit(0);
        } else if (strcmp(arg, "-v") == 0 || strcmp(arg, "--version") == 0) {
            printf("NetSpeedLite %s\n", NSL_VERSION);
            exit(0);
        } else {
            fprintf(stderr, "Error: unknown option '%s' (try --help)\n", arg);
            return false;
        }
    }

    if (cfg->mode == MODE_AUTO) {
        cfg->mode = isatty(STDOUT_FILENO) ? MODE_TUI : MODE_ONCE;
    }
    return true;
}

static void push_history(double *buf, size_t *count, size_t cap, double val) {
    if (*count < cap) {
        buf[(*count)++] = val;
    } else {
        memmove(buf, buf + 1, (cap - 1) * sizeof(double));
        buf[cap - 1] = val;
    }
}

static void render_waybar(const Config *cfg, double rx_bps, double tx_bps,
                          uint64_t sess_rx, uint64_t sess_tx,
                          const double *comb_hist, size_t hist_len,
                          const IfaceRate *rates, size_t rate_count) {
    char rx_s[32], tx_s[32], tot_rx_s[32], tot_tx_s[32];
    char spark[128] = "";
    format_rate_compact(rx_bps, cfg->unit, rx_s, sizeof(rx_s));
    format_rate_compact(tx_bps, cfg->unit, tx_s, sizeof(tx_s));
    format_bytes_total(sess_rx, tot_rx_s, sizeof(tot_rx_s));
    format_bytes_total(sess_tx, tot_tx_s, sizeof(tot_tx_s));

    if (cfg->sparkline) {
        build_sparkline(comb_hist, hist_len, 8, spark, sizeof(spark));
    }

    char text_raw[256];
    if (cfg->sparkline && spark[0] != '\0') {
        snprintf(text_raw, sizeof(text_raw), "\xe2\x86\x91 %s \xe2\x86\x93 %s %s", tx_s, rx_s, spark);
    } else {
        snprintf(text_raw, sizeof(text_raw), "\xe2\x86\x91 %s \xe2\x86\x93 %s", tx_s, rx_s);
    }

    char tip_raw[1024];
    int pos = snprintf(tip_raw, sizeof(tip_raw),
                       "NetSpeedLite v%s\nUpload: %s\nDownload: %s\nSession: \xe2\x86\x91 %s  \xe2\x86\x93 %s",
                       NSL_VERSION, tx_s, rx_s, tot_tx_s, tot_rx_s);

    for (size_t i = 0; i < rate_count && pos > 0 && (size_t)pos < sizeof(tip_raw) - 64; i++) {
        char irx[32], itx[32];
        format_rate_compact(rates[i].rx_bps, cfg->unit, irx, sizeof(irx));
        format_rate_compact(rates[i].tx_bps, cfg->unit, itx, sizeof(itx));
        pos += snprintf(tip_raw + pos, sizeof(tip_raw) - (size_t)pos,
                        "\n%s: \xe2\x86\x91 %s  \xe2\x86\x93 %s",
                        rates[i].name, itx, irx);
    }

    double total_bps = rx_bps + tx_bps;
    const char *cls = "idle";
    if (total_bps >= 10.0 * 1024.0 * 1024.0) {
        cls = "high";
    } else if (total_bps >= 1024.0) {
        cls = "active";
    }

    int pct = (int)((total_bps / (100.0 * 1024.0 * 1024.0)) * 100.0);
    if (pct > 100) pct = 100;
    if (pct < 0) pct = 0;

    char text_esc[512], tip_esc[2048];
    json_escape(text_raw, text_esc, sizeof(text_esc));
    json_escape(tip_raw, tip_esc, sizeof(tip_esc));

    printf("{\"text\":\"%s\",\"tooltip\":\"%s\",\"class\":\"%s\",\"percentage\":%d}\n",
           text_esc, tip_esc, cls, pct);
    fflush(stdout);
}

static void render_polybar(const Config *cfg, double rx_bps, double tx_bps) {
    char rx_s[32], tx_s[32];
    format_rate_compact(rx_bps, cfg->unit, rx_s, sizeof(rx_s));
    format_rate_compact(tx_bps, cfg->unit, tx_s, sizeof(tx_s));

    const Theme *th = &THEMES[cfg->theme];
    if (cfg->color && cfg->theme != THEME_MONO) {
        printf("%%{F%s}\xe2\x86\x91 %s%%{F-}  %%{F%s}\xe2\x86\x93 %s%%{F-}\n",
               th->tx_hex, tx_s, th->rx_hex, rx_s);
    } else {
        printf("\xe2\x86\x91 %s  \xe2\x86\x93 %s\n", tx_s, rx_s);
    }
    fflush(stdout);
}

static void render_json_once(const Config *cfg, double rx_bps, double tx_bps,
                             uint64_t sess_rx, uint64_t sess_tx,
                             const IfaceRate *rates, size_t rate_count) {
    char rx_s[32], tx_s[32];
    format_rate_compact(rx_bps, cfg->unit, rx_s, sizeof(rx_s));
    format_rate_compact(tx_bps, cfg->unit, tx_s, sizeof(tx_s));

    printf("{\"version\":\"%s\",\"rx_bytes_per_sec\":%.2f,\"tx_bytes_per_sec\":%.2f,"
           "\"rx_formatted\":\"%s\",\"tx_formatted\":\"%s\","
           "\"session_rx_bytes\":%" PRIu64 ",\"session_tx_bytes\":%" PRIu64 ","
           "\"interfaces\":[",
           NSL_VERSION, rx_bps, tx_bps, rx_s, tx_s, sess_rx, sess_tx);

    for (size_t i = 0; i < rate_count; i++) {
        char name_esc[IFACE_NAME_LEN * 2];
        json_escape(rates[i].name, name_esc, sizeof(name_esc));
        printf("%s{\"name\":\"%s\",\"rx_bytes_per_sec\":%.2f,\"tx_bytes_per_sec\":%.2f,"
               "\"rx_total_bytes\":%" PRIu64 ",\"tx_total_bytes\":%" PRIu64 "}",
               (i > 0 ? "," : ""), name_esc,
               rates[i].rx_bps, rates[i].tx_bps,
               rates[i].rx_total, rates[i].tx_total);
    }
    printf("]}\n");
    fflush(stdout);
}

static void render_once(const Config *cfg, double rx_bps, double tx_bps,
                        uint64_t sess_rx, uint64_t sess_tx) {
    char rx_s[32], tx_s[32], tot_rx_s[32], tot_tx_s[32];
    format_rate_compact(rx_bps, cfg->unit, rx_s, sizeof(rx_s));
    format_rate_compact(tx_bps, cfg->unit, tx_s, sizeof(tx_s));
    format_bytes_total(sess_rx, tot_rx_s, sizeof(tot_rx_s));
    format_bytes_total(sess_tx, tot_tx_s, sizeof(tot_tx_s));

    printf("\xe2\x86\x91 %s  \xe2\x86\x93 %s  (session: \xe2\x86\x91 %s, \xe2\x86\x93 %s)\n",
           tx_s, rx_s, tot_tx_s, tot_rx_s);
    fflush(stdout);
}

static void render_tui(const Config *cfg, double rx_bps, double tx_bps,
                       double peak_rx, double peak_tx,
                       uint64_t sess_rx, uint64_t sess_tx,
                       const double *rx_hist, const double *tx_hist, size_t hist_len,
                       const IfaceRate *rates, size_t rate_count) {
    const Theme *th = &THEMES[cfg->theme];
    const char *rst = cfg->color ? "\033[0m" : "";
    const char *bold = cfg->color ? "\033[1m" : "";
    const char *c_tx = cfg->color ? th->tx_ansi : "";
    const char *c_rx = cfg->color ? th->rx_ansi : "";
    const char *c_acc = cfg->color ? th->accent_ansi : "";
    const char *c_mut = cfg->color ? th->muted_ansi : "";
    const char *c_brd = cfg->color ? th->border_ansi : "";

    char rx_s[32], tx_s[32], prx_s[32], ptx_s[32], trx_s[32], ttx_s[32];
    format_rate(rx_bps, cfg->unit, rx_s, sizeof(rx_s));
    format_rate(tx_bps, cfg->unit, tx_s, sizeof(tx_s));
    format_rate_compact(peak_rx, cfg->unit, prx_s, sizeof(prx_s));
    format_rate_compact(peak_tx, cfg->unit, ptx_s, sizeof(ptx_s));
    format_bytes_total(sess_rx, trx_s, sizeof(trx_s));
    format_bytes_total(sess_tx, ttx_s, sizeof(ttx_s));

    int term_w = get_term_width();
    size_t spark_w = (term_w >= 64) ? SPARK_LEN : 12;
    char rx_spark[128] = "", tx_spark[128] = "";
    if (cfg->sparkline) {
        build_sparkline(rx_hist, hist_len, spark_w, rx_spark, sizeof(rx_spark));
        build_sparkline(tx_hist, hist_len, spark_w, tx_spark, sizeof(tx_spark));
    }

    printf("\033[H\033[J");
    printf("%s%sNetSpeedLite%s %sv%s%s  %s[%s | %dms | Ctrl+C to quit]%s\n",
           bold, c_acc, rst, c_mut, NSL_VERSION, rst,
           c_mut, th->name, cfg->interval_ms, rst);
    printf("%s────────────────────────────────────────────────────────────%s\n", c_brd, rst);

    printf("  %s%s\xe2\x86\x91 Upload  %s  %s%s%s", bold, c_tx, tx_s, rst, c_tx, tx_spark);
    printf("%s   %s(peak %s)%s\n", rst, c_mut, ptx_s, rst);

    printf("  %s%s\xe2\x86\x93 Download%s  %s%s%s", bold, c_rx, rx_s, rst, c_rx, rx_spark);
    printf("%s   %s(peak %s)%s\n", rst, c_mut, prx_s, rst);

    printf("  %sSession Totals:%s  \xe2\x86\x91 %-10s   \xe2\x86\x93 %-10s\n",
           c_mut, rst, ttx_s, trx_s);

    printf("%s────────────────────────────────────────────────────────────%s\n", c_brd, rst);
    printf("  %s%-14s  %12s  %12s  %10s%s\n",
           c_mut, "Interface", "Upload", "Download", "RX Total", rst);

    for (size_t i = 0; i < rate_count; i++) {
        char irx[32], itx[32], itot[32];
        format_rate_compact(rates[i].rx_bps, cfg->unit, irx, sizeof(irx));
        format_rate_compact(rates[i].tx_bps, cfg->unit, itx, sizeof(itx));
        format_bytes_total(rates[i].rx_total, itot, sizeof(itot));
        printf("  %-14s  %s%12s%s  %s%12s%s  %s%10s%s\n",
               rates[i].name, c_tx, itx, rst, c_rx, irx, rst, c_mut, itot, rst);
    }

    fflush(stdout);
}

int main(int argc, char **argv) {
    Config cfg;
    if (!parse_args(argc, argv, &cfg)) {
        return 1;
    }

    setup_signals();

    NetSnapshot prev, cur;
    if (!read_proc_net_dev(&prev, cfg.iface_filter)) {
        fprintf(stderr, "Error: failed to read %s: %s\n", PROC_NET_DEV, strerror(errno));
        return 1;
    }

    if (cfg.mode == MODE_TUI) {
        printf("\033[?1049h\033[?25l");
        fflush(stdout);
    }

    double rx_hist[SPARK_LEN] = {0};
    double tx_hist[SPARK_LEN] = {0};
    double comb_hist[SPARK_LEN] = {0};
    size_t rx_len = 0;
    size_t tx_len = 0;
    size_t comb_len = 0;

    uint64_t sess_rx = 0;
    uint64_t sess_tx = 0;
    double peak_rx = 0.0;
    double peak_tx = 0.0;

    while (g_running) {
        sleep_ms(cfg.interval_ms);
        if (!g_running) {
            break;
        }

        if (!read_proc_net_dev(&cur, cfg.iface_filter)) {
            break;
        }

        double dt = cur.timestamp_s - prev.timestamp_s;
        if (dt <= 0.001) {
            dt = (double)cfg.interval_ms / 1000.0;
        }

        IfaceRate rates[MAX_IFACES];
        size_t rate_count = 0;
        uint64_t sum_drx = 0;
        uint64_t sum_dtx = 0;

        for (size_t i = 0; i < cur.count; i++) {
            const IfaceSample *c = &cur.ifaces[i];
            const IfaceSample *p = find_iface(&prev, c->name);
            uint64_t drx = (p && c->rx_bytes >= p->rx_bytes) ? (c->rx_bytes - p->rx_bytes) : 0;
            uint64_t dtx = (p && c->tx_bytes >= p->tx_bytes) ? (c->tx_bytes - p->tx_bytes) : 0;

            sum_drx += drx;
            sum_dtx += dtx;

            if (rate_count < MAX_IFACES) {
                IfaceRate *r = &rates[rate_count++];
                snprintf(r->name, sizeof(r->name), "%s", c->name);
                r->rx_bps = (double)drx / dt;
                r->tx_bps = (double)dtx / dt;
                r->rx_total = c->rx_bytes;
                r->tx_total = c->tx_bytes;
            }
        }

        sess_rx += sum_drx;
        sess_tx += sum_dtx;

        double rx_bps = (double)sum_drx / dt;
        double tx_bps = (double)sum_dtx / dt;
        if (rx_bps > peak_rx) peak_rx = rx_bps;
        if (tx_bps > peak_tx) peak_tx = tx_bps;

        push_history(rx_hist, &rx_len, SPARK_LEN, rx_bps);
        push_history(tx_hist, &tx_len, SPARK_LEN, tx_bps);
        push_history(comb_hist, &comb_len, SPARK_LEN, rx_bps + tx_bps);

        switch (cfg.mode) {
            case MODE_WAYBAR:
                render_waybar(&cfg, rx_bps, tx_bps, sess_rx, sess_tx,
                              comb_hist, comb_len, rates, rate_count);
                break;
            case MODE_POLYBAR:
                render_polybar(&cfg, rx_bps, tx_bps);
                break;
            case MODE_TUI:
                render_tui(&cfg, rx_bps, tx_bps, peak_rx, peak_tx,
                           sess_rx, sess_tx, rx_hist, tx_hist, rx_len,
                           rates, rate_count);
                break;
            case MODE_JSON:
                render_json_once(&cfg, rx_bps, tx_bps, sess_rx, sess_tx,
                                 rates, rate_count);
                g_running = 0;
                break;
            case MODE_ONCE:
            case MODE_AUTO:
            default:
                render_once(&cfg, rx_bps, tx_bps, sess_rx, sess_tx);
                g_running = 0;
                break;
        }

        prev = cur;
    }

    if (cfg.mode == MODE_TUI) {
        printf("\033[?25h\033[?1049l");
        fflush(stdout);
    }

    return 0;
}
