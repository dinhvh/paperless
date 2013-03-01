/*
 *  twain_client.h
 *  TestTWAIN
 *
 *  Created by DINH Viêt Hoà on 24/09/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef TWAIN_CLIENT_H

#define TWAIN_CLIENT_H

#include <TWAIN/TWAIN.h>
#include <CoreFoundation/CoreFoundation.h>

enum twain_xfer_mode
{
	twain_xfer_native = TWSX_NATIVE,
	twain_xfer_file = TWSX_FILE,
	twain_xfer_memory = TWSX_MEMORY,
};

enum twain_unit {
	twain_unit_inches = TWUN_INCHES,
	twain_unit_centimeters = TWUN_CENTIMETERS,
	twain_unit_picas = TWUN_PICAS,
	twain_unit_points = TWUN_POINTS,
	twain_unit_twips = TWUN_TWIPS,
	twain_unit_pixels = TWUN_PIXELS,
};

enum twain_pixel_type {
	twain_pixel_type_bw = TWPT_BW, 
	twain_pixel_type_gray = TWPT_GRAY,
	twain_pixel_type_rgb = TWPT_RGB,
	twain_pixel_type_palette = TWPT_PALETTE,
	twain_pixel_type_cmy = TWPT_CMY,
	twain_pixel_type_cmyk = TWPT_CMYK,
	twain_pixel_type_yuv = TWPT_YUV, 
	twain_pixel_type_yuvk = TWPT_YUVK,
	twain_pixel_type_ciexyz = TWPT_CIEXYZ,
	
};

struct twain_source;
struct twain_client;

struct twain_client_callback {
    void (* tcc_image_begin)(struct twain_source * source, pTW_IMAGEINFO imageInfo, void * cb_data);
    void (* tcc_image_data)(struct twain_source * source, unsigned int row, void * data, size_t size, void * cb_data);
    void (* tcc_image_end)(struct twain_source * source, void * cb_data);
    void (* tcc_image_file_data)(struct twain_source * source, void * data, size_t length, void * cb_data);
    void * tcc_cb_data;
};

struct twain_client * twain_client_new(void);
void twain_client_free(struct twain_client * client);

void twain_client_set_callback(struct twain_client * client, struct twain_client_callback * callback);

int twain_client_init_twain(struct twain_client * client);
int twain_client_release_twain(struct twain_client * client);

unsigned int twain_client_get_source_count(struct twain_client * client);
struct twain_source * twain_client_get_source_with_index(struct twain_client * client, long source_index);

int twain_source_open(struct twain_source * source);
int twain_source_close(struct twain_source * source);

int twain_source_get_resolution(struct twain_source * source, float * pfRes);
int twain_source_set_resolution(struct twain_source * source, float fRes);

int twain_source_get_units(struct twain_source * source, enum twain_unit * pUnits);
int twain_source_set_units(struct twain_source * source, enum twain_unit uUnits);
int twain_source_is_units_supported(struct twain_source * source, enum twain_unit units);

int twain_source_set_pixel_type(struct twain_source * source, enum twain_pixel_type nType);
int twain_source_get_pixel_type(struct twain_source * source, enum twain_pixel_type *  pPixelType);

int twain_source_get_xfer_count(struct twain_source * source, int * pCount);
int twain_source_set_xfer_count(struct twain_source * source, int count);

int twain_source_get_brightness(struct twain_source * source, float * pfBrightness);
int twain_source_set_brightness(struct twain_source * source, float fBrightness);

int twain_source_get_contrast(struct twain_source * source, float * pfContrast);
int twain_source_set_contrast(struct twain_source * source, float fContrast);

int twain_source_set_image_layout(struct twain_source * source, float left, float top, float width, float height);
int twain_source_get_image_layout(struct twain_source * source, float * pLeft, float * pTop, float * pWidth, float * pHeight);

int twain_source_set_xfer_mode(struct twain_source * source, enum twain_xfer_mode mode);
enum twain_xfer_mode twain_source_get_xfer_mode(struct twain_source * source);
int twain_source_is_xfer_mode_supported(struct twain_source * source, enum twain_xfer_mode mode);

int twain_source_get_bit_depth(struct twain_source * source, int * pDepth);
int twain_source_set_bit_depth(struct twain_source * source, int depth);

int twain_source_is_uicontrollable(struct twain_source * source);
int twain_source_is_online(struct twain_source * source);

int twain_source_set_indicators_enabled(struct twain_source * source, int enabled);
int twain_source_get_indicators_enabled(struct twain_source * source, int * p_enabled);

int twain_source_acquire(struct twain_source * source, int show_ui);

int twain_client_enumerate_sources(struct twain_client * client);

char * twain_source_get_name(struct twain_source * source);

int twain_source_set_feeder_enabled(struct twain_source * source, int enabled);
int twain_source_has_feeder(struct twain_source * source);
int twain_source_is_feeder_loaded(struct twain_source * source);

int twain_source_set_auto_feeder_enabled(struct twain_source * source, int enabled);

void twain_client_register_runloop(struct twain_client * client, CFRunLoopRef runloop);

#endif
