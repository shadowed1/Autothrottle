// compile: clang -o autothrottle_brightness autothrottle_brightness.c -framework CoreGraphics
// usage:   brightness                            - print current brightness
//          brightness 0.75                       - set brightness
//          brightness --monitor <file> [freeze]  - write to file on each change; skip writes while freeze path exists
//          brightness --hold 0.75                - hold brightness at value until killed
//          brightness --freeze 0.75              - freeze brightness until killed
//          brightness --freeze 0.75 3            - freeze brightness for 3 seconds
// shadowed1
// autothrottle_brightness paired with autothrottle.sh prevents power modes altering out brightness.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <dlfcn.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <CoreGraphics/CoreGraphics.h>

typedef int (*DSGetBrightness_t)(CGDirectDisplayID, float *);
typedef int (*DSSetBrightness_t)(CGDirectDisplayID, float);

static inline int time_diff_us(struct timeval *start, struct timeval *now) {
    return (int)((now->tv_sec - start->tv_sec) * 1000000 +
                 (now->tv_usec - start->tv_usec));
}

static int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

static void write_brightness_file(const char *path, float value) {
    char tmp[512];
    snprintf(tmp, sizeof(tmp), "%s.tmp", path);
    FILE *f = fopen(tmp, "w");
    if (!f) return;
    fprintf(f, "%.6f\n", value);
    fclose(f);
    rename(tmp, path);
}

int main(int argc, char *argv[]) {
    void *ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY);
    if (!ds) { fprintf(stderr, "Failed to load DisplayServices\n"); return 1; }

    DSGetBrightness_t getB = dlsym(ds, "DisplayServicesGetBrightness");
    DSSetBrightness_t setB = dlsym(ds, "DisplayServicesSetBrightness");
    if (!getB || !setB) {
        fprintf(stderr, "Failed to find symbols\n");
        dlclose(ds);
        return 1;
    }

    CGDirectDisplayID display = CGMainDisplayID();
    float brightness;

    if (argc == 1) {
        if (getB(display, &brightness) != 0) {
            fprintf(stderr, "Failed to get brightness\n");
            return 1;
        }
        printf("%.6f\n", brightness);
    }

    else if (argc == 2) {
        brightness = (float)atof(argv[1]);
        if (brightness < 0.0f) brightness = 0.0f;
        if (brightness > 1.0f) brightness = 1.0f;
        if (setB(display, brightness) != 0) {
            fprintf(stderr, "Failed to set brightness\n");
            return 1;
        }
    }

    else if (argc >= 3 && strcmp(argv[1], "--monitor") == 0) {
        const char *out_file   = argv[2];
        const char *freeze_flag = argc >= 4 ? argv[3] : NULL;
        float last = -1.0f;

        if (getB(display, &brightness) == 0) {
            write_brightness_file(out_file, brightness);
            last = brightness;
        }

        while (1) {
                usleep(50000);

                float current;
                if (getB(display, &current) != 0) continue;

                if (fabsf(current - last) <= 0.00005f) continue;

                if (freeze_flag && file_exists(freeze_flag)) {
                    continue;
                }

                write_brightness_file(out_file, current);
                last = current;
            }
        }

    else if (argc == 3 && strcmp(argv[1], "--hold") == 0) {
        float target = (float)atof(argv[2]);
        if (target < 0.0f) target = 0.0f;
        if (target > 1.0f) target = 1.0f;

        while (1) {
            setB(display, target);
            usleep(200);
        }
    }

    else if (argc >= 3 && strcmp(argv[1], "--freeze") == 0) {
        float target = (float)atof(argv[2]);
        if (target < 0.0f) target = 0.0f;
        if (target > 1.0f) target = 1.0f;

        int duration_us = 0;
        if (argc == 4) {
            duration_us = (int)(atof(argv[3]) * 1000000.0);
        }

        setB(display, target);
        setB(display, target);

        struct timeval start, now;
        gettimeofday(&start, NULL);

        while (1) {
            float current;
            if (getB(display, &current) == 0) {
                if (fabsf(current - target) > 0.00005f) {
                    setB(display, target);
                    setB(display, target);
                    usleep(1000);
                } else {
                    usleep(2000);
                }
            } else {
                usleep(2000);
            }

            if (duration_us > 0) {
                gettimeofday(&now, NULL);
                if (time_diff_us(&start, &now) >= duration_us) break;
            }
        }

        setB(display, target);
        setB(display, target);
    }

    else {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "  brightness\n");
        fprintf(stderr, "  brightness <value>\n");
        fprintf(stderr, "  brightness --monitor <file> [freeze_flag_path]\n");
        fprintf(stderr, "  brightness --hold <value>\n");
        fprintf(stderr, "  brightness --freeze <value>\n");
        fprintf(stderr, "  brightness --freeze <value> <seconds>\n");
        return 1;
    }

    dlclose(ds);
    return 0;
}
