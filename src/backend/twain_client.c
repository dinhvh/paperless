/*
 *  twain_client.c
 *  TestTWAIN
 *
 *  Created by DINH Viêt Hoà on 24/09/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include "twain_client.h"

#include <pthread.h>

// client

struct twain_client {
	unsigned int tc_state;
	struct twain_source * tc_source_list;
    unsigned int tc_source_count;
	TW_STATUS tc_status;
	TW_IDENTITY tc_app_ident;
    struct twain_client_callback tc_callback;
    CFRunLoopSourceRef tc_source;
    CFRunLoopRef tc_runloop;
    pthread_mutex_t tc_queue_lock;
    struct callback_data * tc_queue;
	struct twain_source * tc_current_source;
};

// source

struct twain_source {
	struct twain_client * ts_client;
	
    TW_IDENTITY ts_identity;
	unsigned int ts_state;
	TW_STATUS ts_status;
    enum twain_xfer_mode ts_xfer_mode;
	TW_USERINTERFACE ts_ui;
	
    struct twain_source * ts_next;
};

enum twain_client_state {
	twain_client_presession = 1,		// Source Manager not loaded;
    twain_client_loaded = 2,	// Source Manager loaded;
	twain_client_opened = 3,		// Source Manager Opened;
};

enum twain_source_state {
	twain_source_closed = 3,		// Source Manager Opened;
	twain_source_opened = 4,		// Source Open;
	twain_source_enabled = 5,	// Source Enabled;
	twain_source_transfer_ready = 6,	// Transfer Ready;
	twain_source_transferring = 7		// Transferring;
};

// internals
#if 0
enum twain_can_invoke
{
	canAcquire = 0,
	canSelectSourceModal = 1,
	canSelectSourceModaless = 2,
	canUninitializeTwain = 3,
	canCancelSelectSource = 4
};
#endif

// internals
enum twain_captype
{
	capNone = 0,						// Indicates "No Data"
	capArray = TWON_ARRAY,				// "Array" type of data
	capEnumeration = TWON_ENUMERATION,	// "Enumeration" type of data
	capOneValue = TWON_ONEVALUE,		// "One Value" type of data
	capRange = TWON_RANGE				// "Range" type of data
};

struct twain_capinfo;

// internals - begin
static void twain_client_init(struct twain_client * client);
static void twain_client_destroy(struct twain_client * client);
static TW_STATUS twain_client_get_status(struct twain_client * client);
//static int twain_client_enumerate_sources(struct twain_client * client);
static enum twain_client_state twain_client_get_state(struct twain_client * client);
// internals - end

// low-level - internals
static int twain_source_set_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int value);
static int twain_source_set_value_int16(struct twain_source * source, TW_UINT16 cap, int value);
static int twain_source_set_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int value);
static int twain_source_set_value_int32(struct twain_source * source, TW_UINT16 cap, int value);
static int twain_source_set_value_fix32(struct twain_source * source, TW_UINT16 cap, float value);
static int twain_source_set_one_value_cap(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue);
static int twain_source_set_one_value_with_size_cap(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType,
											 void * pValue, size_t size);
static int twain_source_set_capability(struct twain_source * source, TW_CAPABILITY cap);
static int twain_source_query_capability(struct twain_source * source, TW_CAPABILITY * pCap, struct twain_capinfo * pCapInfo, TW_UINT16 msg);
static int twain_source_disable(struct twain_source * source);

static int twain_source_get_specific_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 msg, TW_UINT16 ItemType, void * pValue);
static int twain_source_get_current_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue);
static int twain_source_get_default_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue);
static int twain_source_get_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue);
static int twain_source_get_current_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes);
static int twain_source_get_current_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_current_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_current_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_current_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_current_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_default_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes);
static int twain_source_get_default_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_default_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_default_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_default_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_default_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes);
static int twain_source_get_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue);
static int twain_source_get_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue);
static int twain_source_get_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue);

static void twain_client_unregister_runloop(struct twain_client * client);
static void twain_client_signal_runloop(struct twain_client * client);

// internals
union twain_capvalue
{
	struct twain_array
	{
		pTW_ARRAY array_pValue;
		long array_nItemSize;
	} array;
    
	struct twain_enumeration
	{
		pTW_ENUMERATION enum_pValue;
		long enum_nItemSize;
	} enumeration;
    
	struct twain_onevalue
	{
		pTW_ONEVALUE oneval_pValue;
	} onevalue;
    
	struct twain_range
	{
		pTW_RANGE range_pValue;
	} range;
};

struct twain_capinfo {
    union twain_capvalue tci_value;
	enum twain_captype tci_type;
};

static void twain_capinfo_init(struct twain_capinfo * capinfo);
static void twain_capinfo_reset(struct twain_capinfo * capinfo);
static enum twain_captype twain_capinfo_get_type(struct twain_capinfo * capinfo);
static void twain_capinfo_set_type(struct twain_capinfo * capinfo, enum twain_captype newType);
static union twain_capvalue twain_capinfo_get_value(struct twain_capinfo * capinfo);
static void twain_capinfo_set_value(struct twain_capinfo * capinfo, union twain_capvalue newValue);


static	TW_STR32		Manufacturer  = "\petPan";
static 	TW_STR32		ProductFamily = "\ptwain-client";
static 	TW_STR32		ProductName   = "\pPaperLess";
static 	TW_STR32		VersionInfo   = "\p2.0";

static float Fix32ToFloat(TW_FIX32 twValue);
static TW_FIX32 FloatToFix32(float fValue);
static long GetTwainTypeSize(long nTwainType);

static TW_STATUS twain_source_get_status(struct twain_source * source);
static void set_twain_client_state(struct twain_client * client, enum twain_client_state new_state);
static void set_twain_source_state(struct twain_source * source, enum twain_source_state new_state);
static enum twain_source_state twain_source_get_state(struct twain_source * source);
static void release_src_list(struct twain_client * client);

static TW_UINT16 ds_entry(struct twain_client * client, struct twain_source * source, TW_UINT32 DG, TW_UINT16 Dat, TW_UINT16 Msg, void * pData);
static TW_UINT16 dsm_entry(struct twain_client * client, TW_UINT32 DG, TW_UINT16 Dat, TW_UINT16 Msg, void * pData);

static void on_source_state_changed(struct twain_source * source, enum twain_source_state new_state);
static void on_client_state_changed(struct twain_client * client, enum twain_client_state new_state);
static void on_low_memory(struct twain_client * client);
static void on_get_identity(struct twain_client * client, pTW_IDENTITY pIdentity);
static int on_source_enum(struct twain_client * client, TW_IDENTITY * indentity , unsigned int source_index);
static int on_setup_file_xfer(struct twain_source * source, pTW_SETUPFILEXFER pSFX, unsigned int imageIndex);
static int on_file_xfer(struct twain_source * source, pTW_SETUPFILEXFER fileXfer, unsigned int imageIndex);
static int on_memory_xfer_ready(struct twain_source * source, pTW_IMAGEINFO imageInfo);
static int on_mem_xfer_buffer(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int nRow, unsigned int image_index);
static int on_mem_xfer_row(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int row, void * buffer, unsigned int image_index);
static int on_mem_xfer_next_image(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int image_index);
static void on_mem_xfer_done(struct twain_source * source, int success);
static int on_copy_image(struct twain_source * source, PicHandle hPict, pTW_IMAGEINFO imageInfo, unsigned int imageIndex);
static int on_twain_message(struct twain_client * client, pTW_IDENTITY dest, TW_UINT16 MSG);

static TW_UINT16 global_callback(pTW_IDENTITY pOrigin,
                                 pTW_IDENTITY	pDest,
                                 TW_UINT32		DG,
                                 TW_UINT16		DAT,
                                 TW_UINT16		MSG,
                                 TW_MEMREF		pData);
static TW_INT16 register_callback(struct twain_client * client);
static void unregister_callback(struct twain_client * client);

static void on_close_ds_request(struct twain_source * source);
static void on_xfer_ready(struct twain_source * source);
static void on_closed_ok(struct twain_source * source);
static void on_device_event(struct twain_source * source);
static int twain_source_get_device_event(struct twain_source * source, unsigned int * pEvent);
static void twain_log(const char * format, ...);

static TW_HANDLE twainAllocHandle(size_t size)
{
	return NewHandle((ssize_t) size);
}

static TW_MEMREF twainLockHandle (TW_HANDLE handle)
{
    return *handle;
}

static void twainUnlockHandle (TW_HANDLE handle)
{
    /* NOP */
}

static void twainFreeHandle (TW_HANDLE handle)
{
    DisposeHandle (handle);
}

static float Fix32ToFloat(TW_FIX32 twValue)
{
	return (float)twValue.Whole + (float)twValue.Frac / 65536.0;
}

static TW_FIX32 FloatToFix32(float fValue)
{
	TW_INT32 val = fValue * 65536.0 + 0.5;
	TW_FIX32 fix = {(TW_INT16) (val>>16), (TW_UINT16) (val & 0x0000ffff)};
	return fix;
}

static long GetTwainTypeSize(long nTwainType)
{
	if(nTwainType < 0 || nTwainType > 14)
		return 0;
    
	const long nTypeSize[] ={sizeof(TW_INT8), sizeof (TW_INT16), sizeof (TW_INT32), sizeof (TW_UINT8),
        sizeof (TW_UINT16),	sizeof (TW_UINT32),	sizeof (TW_BOOL), sizeof (TW_FIX32),
        sizeof (TW_FRAME), sizeof (TW_STR32), sizeof (TW_STR64), sizeof (TW_STR128),
    sizeof (TW_STR255) /*, sizeof(TW_STR1024), sizeof(TW_UNI512) */};
    
	return nTypeSize[nTwainType];
}

static TW_UINT16 ds_entry(struct twain_client * client, struct twain_source * source, TW_UINT32 DG, TW_UINT16 Dat, TW_UINT16 Msg, void * pData )
{
    pTW_IDENTITY pIdentity;
    TW_UINT16 rc;
    
    twain_log("%p %p %x %x %x %p", client, source, DG, Dat, Msg, pData);
    
	memset(&client->tc_status, 0, sizeof(client->tc_status)); // Reset current status;
    
	if (twain_client_get_state(client) < twain_client_loaded)	// If TWAIN isn't loaded yet;
		return TWRC_FAILURE;			// Return with error;
    
    pIdentity = NULL;
    if (source != NULL) {
        pIdentity = &source->ts_identity;
    }
    
    twain_log("identity: %p", (void *) pIdentity);
    
    rc = DSM_Entry(&client->tc_app_ident, pIdentity, DG, Dat, Msg, (TW_MEMREF) pData);
    twain_log("ok ? %u", rc);
    if (rc != TWRC_SUCCESS) {
        twain_log("error while ds_entry %u", rc);
    }
	if (rc == TWRC_FAILURE) {
        if (source != NULL) {
            DSM_Entry(&client->tc_app_ident, pIdentity, DG_CONTROL, DAT_STATUS, MSG_GET, (TW_MEMREF) &source->ts_status);
            twain_log("get status %u", source->ts_status.ConditionCode);
            if (source->ts_status.ConditionCode == TWCC_LOWMEMORY)
                on_low_memory(client);
        }
        else {
            DSM_Entry(&client->tc_app_ident, pIdentity, DG_CONTROL, DAT_STATUS, MSG_GET, (TW_MEMREF) &client->tc_status);
            twain_log("get status %u", client->tc_status.ConditionCode);
            if (client->tc_status.ConditionCode == TWCC_LOWMEMORY)
                on_low_memory(client);
        }
	}
    
    return rc;
}

static TW_UINT16 dsm_entry(struct twain_client * client, TW_UINT32 DG, TW_UINT16 Dat, TW_UINT16 Msg, void * pData )
{
    return ds_entry(client, NULL, DG, Dat, Msg, pData);
}


static void twain_capinfo_init(struct twain_capinfo * capinfo)
{
	memset(capinfo, 0, sizeof(* capinfo));
}

static enum twain_captype twain_capinfo_get_type(struct twain_capinfo * capinfo)
{
	return capinfo->tci_type;
}


static union twain_capvalue twain_capinfo_get_value(struct twain_capinfo * capinfo)
{
	return capinfo->tci_value;
}


void twain_capinfo_set_value(struct twain_capinfo * capinfo, union twain_capvalue newValue)
{
	capinfo->tci_value = newValue;
}

void twain_capinfo_set_type(struct twain_capinfo * capinfo, enum twain_captype newType)
{
	capinfo->tci_type = newType;
}

static void twain_capinfo_reset(struct twain_capinfo * capinfo)
{
	switch(capinfo->tci_type)
	{
        case capArray:
		{
			free(capinfo->tci_value.array.array_pValue);
			break;
		}
        case capEnumeration:
		{
			free(capinfo->tci_value.enumeration.enum_pValue);
			break;
		}
        case capOneValue:
		{
			free(capinfo->tci_value.onevalue.oneval_pValue);
			break;
		}
        case capRange:
		{
			free(capinfo->tci_value.range.range_pValue);
			break;
		}
        default:
            break;
	}
    
	memset(capinfo, 0, sizeof(* capinfo)); // Sets 0 for all properties;
}

static int on_source_enum(struct twain_client * client, TW_IDENTITY * indentity , unsigned int source_index)
{
    twain_log("on source enum : %u", source_index);
	return 1; // Always approve all TWAIN Sources;
}


static int on_setup_file_xfer(struct twain_source * source, pTW_SETUPFILEXFER pSFX, unsigned int image_index)
{
    twain_log("on setup file xfer : %u", image_index);
	return 1; // Continue with the transfer;
}


static int on_file_xfer(struct twain_source * source, pTW_SETUPFILEXFER fileXfer, unsigned int image_index)
{
    twain_log("on file xfer : %u", image_index);
	return 1; // Continue with the transfer;
}


static int on_memory_xfer_ready(struct twain_source * source, pTW_IMAGEINFO imageInfo)
{
    struct twain_client * client;
    
    client = source->ts_client;
    
    twain_log("on memory xfer ready");
    if (client->tc_callback.tcc_image_begin != NULL) {
        client->tc_callback.tcc_image_begin(source, imageInfo, client->tc_callback.tcc_cb_data);
    }
	return 1; // Continue with the transfer;
}


static int on_mem_xfer_buffer(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int nRow, unsigned int image_index)
{
    struct twain_client * client;
	char * pBuffer = (char *) pMX->Memory.TheMem;
    
    client = source->ts_client;
    twain_log("on memory xfer buffer : %u %u %u", nRow, pMX->Rows, image_index);
	if (pBuffer != NULL) {
        TW_UINT32 i;
        
		for(i = 0 ; i < pMX->Rows; i++) {
			if(!on_mem_xfer_row(source, pMX, pMX->YOffset + nRow, pBuffer, image_index))
				return 0; // Stop transfer;
			nRow++;
			pBuffer += pMX->BytesPerRow;
		}
    }
	return 1; // Continue with the transfer;
}


static int on_mem_xfer_row(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int row, void * buffer, unsigned int imageIndex)
{
    struct twain_client * client;
    client = source->ts_client;
    
    if (client->tc_callback.tcc_image_data != NULL) {
        //client->tc_callback.tcc_image_data(source, pMX, nRow * pMX->BytesPerRow, pBuffer, pMX->BytesWritten, client->tc_callback.tcc_cb_data);
        client->tc_callback.tcc_image_data(source, row, buffer, pMX->BytesPerRow, client->tc_callback.tcc_cb_data);
    }
    //twain_log("on memory xfer row: %u %u", row, imageIndex);
	return 1; // Continue with the transfer;
}

static int on_mem_xfer_next_image(struct twain_source * source, pTW_IMAGEMEMXFER pMX, unsigned int imageIndex)
{
    twain_log("on memory xfer next image %u", imageIndex);
	return 1; // Yes, send another image;
}

static void on_mem_xfer_done(struct twain_source * source, int success)
{
    struct twain_client * client;
    
    client = source->ts_client;
    
    twain_log("on memory xfer done %u", success);
    if (client->tc_callback.tcc_image_end != NULL) {
        client->tc_callback.tcc_image_end(source, client->tc_callback.tcc_cb_data);
    }
}

static int on_copy_image(struct twain_source * source, PicHandle hPict, pTW_IMAGEINFO imageInfo, unsigned int imageIndex)
{
    struct twain_client * client;
    
    client = source->ts_client;
    
    twain_log("on copy image %u", imageIndex);
    
    twainLockHandle((Handle) hPict);
    if (client->tc_callback.tcc_image_file_data != NULL) {
        client->tc_callback.tcc_image_file_data(source, * hPict, GetHandleSize((Handle)hPict), client->tc_callback.tcc_cb_data);
    }
    twainUnlockHandle((Handle) hPict);
	return 1;
}

static void on_low_memory(struct twain_client * client)
{
}

static void on_get_identity(struct twain_client * client, pTW_IDENTITY pIdentity)
{
	memset(pIdentity, 0, sizeof(* pIdentity));
	pIdentity->ProtocolMajor = TWON_PROTOCOLMAJOR;
	pIdentity->ProtocolMinor = TWON_PROTOCOLMINOR;
	pIdentity->SupportedGroups = DG_IMAGE | DG_CONTROL;
}

static void on_client_state_changed(struct twain_client * client, enum twain_client_state new_state)
{
}

static void on_source_state_changed(struct twain_source * source, enum twain_source_state new_state)
{
}

static void release_src_list(struct twain_client * client)
{
	client->tc_source_count = 0;			// No Sources;
	while (client->tc_source_list != NULL) {
		struct twain_source * next;
        
        next = client->tc_source_list->ts_next;	// Get the next Source in the list;
		free(client->tc_source_list);								// Delete one element;
		client->tc_source_list = next;								// Assume the next pointer in the list;
	}
}


static void set_twain_client_state(struct twain_client * client, enum twain_client_state new_state)
{
    twain_log("twain state %u", new_state);
	if(client->tc_state != new_state) {
		client->tc_state = new_state;	// Save new state;
		on_client_state_changed(client, new_state);	// Notify the client;
	}
}

static void set_twain_source_state(struct twain_source * source, enum twain_source_state new_state)
{
    twain_log("twain state %u", new_state);
	if(source->ts_state != new_state) {
		source->ts_state = new_state;	// Save new state;
		on_source_state_changed(source, new_state);	// Notify the client;
	}
}

struct twain_client * twain_client_new(void)
{
    struct twain_client * client;
    
    client = calloc(1, sizeof(* client));
    twain_client_init(client);
    
    return client;
}

void twain_client_free(struct twain_client * client)
{
    twain_client_destroy(client);
    free(client);
}

static void twain_client_init(struct twain_client * client)
{
    TW_IDENTITY	Identity;
    
    memset(client, 0, sizeof(* client));
    twain_client_register_runloop(client, CFRunLoopGetMain());
    
    client->tc_state = twain_client_presession;	// No TWAIN loaded;
    client->tc_source_count = 0;						// No Sources;
    client->tc_source_list = NULL;					// No Sources;
    
    // setup the applications identity structure
    Identity.Id					= (void *) 1;
    Identity.Version.MajorNum	= 1;
    Identity.Version.MinorNum	= 0;
    Identity.Version.Language	= TWLG_USA;
    Identity.Version.Country	= TWCY_USA;
    strcpy((char *)Identity.Version.Info, (char *)VersionInfo);
    Identity.ProtocolMajor		= TWON_PROTOCOLMAJOR;
    Identity.ProtocolMinor		= TWON_PROTOCOLMINOR;
    Identity.SupportedGroups	= DG_CONTROL|DG_IMAGE;
    strcpy((char *)(pTW_UINT8)Identity.Manufacturer,(char *)(pTW_UINT8)Manufacturer);
    strcpy((char *)(pTW_UINT8)Identity.ProductFamily,(char *)(pTW_UINT8)ProductFamily);
    strcpy((char *)(pTW_UINT8)Identity.ProductName,(char *)(pTW_UINT8)ProductName);
    client->tc_app_ident = Identity;
    // load and initialize TWAIN DSM
    pthread_mutex_init(&client->tc_queue_lock, NULL);
}

static void twain_client_destroy(struct twain_client * client)
{
    twain_client_release_twain(client);
    pthread_mutex_destroy(&client->tc_queue_lock);
}

void twain_client_set_callback(struct twain_client * client, struct twain_client_callback * callback)
{
    client->tc_callback = * callback;
}

int twain_client_init_twain(struct twain_client * client)
{
	int reinitialize;
	
	reinitialize = 1;
	
    /////////////////////////////////
    // Releasing TWAIN, if required:
    //
    if (reinitialize)		// If requested to re-initialzie;
        twain_client_release_twain(client);		// Releasing TWAIN;
    
    if(twain_client_get_state(client) != twain_client_presession)	// If TWAIN hasn't been uninitialized;
        return -1;					// Return with error;
    
    ////////////////////////////
    // TWAIN state has changed:
    //
    set_twain_client_state(client, twain_client_loaded);
    
    ///////////////////////////////////////////
    // Initializing application identity
    // information. This virtual method must
    // be overridden by the client application;
    //
    on_get_identity(client, &client->tc_app_ident);
    
    /////////////////////////////////////
    // Opening the TWAIN Source Manager;
    //
    TW_UINT16 rc = dsm_entry(client, DG_CONTROL, DAT_PARENT, MSG_OPENDSM, NULL);
    if (rc != TWRC_SUCCESS) {
        twain_client_release_twain(client);	// Releasing all the TWAIN support;
        return -1;	// Returning with error;
    }
    
    ////////////////////////////
    // TWAIN state has changed:
    //
    set_twain_client_state(client, twain_client_opened);
	
	twain_client_enumerate_sources(client);
    
    register_callback(client);
    
    return 0;	// Successfully initialized TWAIN;
}

int twain_client_release_twain(struct twain_client * client)
{
	struct twain_source * source;
	
    ////////////////////////////////////////
    // We cannot uninitialize TWAIN while
    // Source Select dialog box is displayed:
    //
	
	for(source = client->tc_source_list ; source != NULL ; source = source->ts_next) {
		twain_source_disable(source);
		twain_source_close(source);
	}
	
    //////////////////////////////////////
    // Releasing the list of TWAIN Sources:
    //
    release_src_list(client);
    
    if (twain_client_get_state(client) == twain_client_opened) {
        //static TW_UINT16 dsm_entry(struct twain_client * client, TW_UINT32 DG, TW_UINT16 Dat, TW_UINT16 Msg, void * pData )
        dsm_entry(client, DG_CONTROL, (TW_UINT16) DAT_PARENT, (TW_UINT16) MSG_CLOSEDSM, NULL);
        
        unregister_callback(client);
        
        /////////////////////////////////////
        // Change the TWAIN state, even if it
        // fails to close the Source Manager:
        //
        set_twain_client_state(client, twain_client_loaded);
    }
    
    set_twain_client_state(client, twain_client_presession);
    
    return 0; // Successful TWAIN shutdown;
}

unsigned int twain_client_get_source_count(struct twain_client * client)
{
    return client->tc_source_count;
}

struct twain_source * twain_client_get_source_with_index(struct twain_client * client, long source_index)
{
	struct twain_source * source;
	
    source = client->tc_source_list;
	if (source == NULL)
		return NULL;
	
    while (source_index > 0) {
        source = source->ts_next;
		if (source == NULL)
			return NULL;
		
		source_index --;
	}
    
    return source;	// Return the Source Identity pointer;
}

int twain_client_enumerate_sources(struct twain_client * client)
{
    TW_IDENTITY Identity;			// Identity parameter for request;
    TW_UINT16 uMsg;
	struct twain_source * last_source;
	
    if (twain_client_get_state(client) < twain_client_opened)
        return -1;
    
    ///////////////////////////////
    // Releasing the previous list
    // of all found Sources:
    //
    release_src_list(client);
    
    uMsg = MSG_GETFIRST;	// Message ID;
    last_source = NULL;
    
    ////////////////////////////////////////////////
    // Querying for all TWAIN Sources in the system,
    // till the end of the list has been reached:
    while (dsm_entry(client, DG_CONTROL, DAT_IDENTITY, uMsg, &Identity) != TWRC_ENDOFLIST) {
        struct twain_source * source;
        
        if (uMsg == MSG_GETFIRST)
            uMsg = MSG_GETNEXT;
        if (!on_source_enum(client, &Identity, client->tc_source_count))
            continue;
        
        client->tc_source_count ++;
        source = calloc(1, sizeof(* source));
        source->ts_client = client;
        source->ts_identity = Identity;
        source->ts_state = twain_source_closed;
        source->ts_xfer_mode = twain_xfer_native;
        if (last_source != NULL)
            last_source->ts_next = source;
        else
            client->tc_source_list = source;
        last_source = source;
    }
    return 0;
}

static enum twain_client_state twain_client_get_state(struct twain_client * client)
{
	return client->tc_state;
}

static TW_STATUS twain_client_get_status(struct twain_client * client)
{
    return client->tc_status;
}

static enum twain_source_state twain_source_get_state(struct twain_source * source)
{
	return source->ts_state;
}

static int twain_source_query_capability(struct twain_source * source, TW_CAPABILITY * pCap, struct twain_capinfo * pCapInfo, TW_UINT16 msg)
{
    twain_log("querycap 1 %p %p %p %x", source, pCap, pCapInfo, msg);
    
    if(pCapInfo == NULL) // Cannot be NULL;
        return -1;
    
    twain_log("querycap 2");
    twain_capinfo_reset(pCapInfo);
    
    twain_log("querycap 3");
    // Filter out allowed messages:
    if(msg != MSG_GET && msg != MSG_GETCURRENT && msg != MSG_GETDEFAULT && msg != MSG_QUERYSUPPORT && msg != MSG_RESET)
        return -1;
    
#if 0
    twain_source_open(source);
#endif
    
    twain_log("querycap 4");
    if (twain_source_get_state(source) < twain_source_opened)
        return -1;
    
    twain_log("querycap 5");
    if(msg == MSG_RESET && twain_source_get_state(source) != twain_source_opened)
        return -1;
    
    twain_log("querycap 6");
    if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_CAPABILITY, msg, pCap) != TWRC_SUCCESS)
        return -1;
    
    twain_log("querycap 7");
    if (pCap->hContainer == NULL)
        return -1;
    
    // Locking result for direct memory access:
    void * pValue = twainLockHandle(pCap->hContainer);
    if (pValue == NULL)
        return -1;
    
    twain_log("querycap 8");
    /////////////////////////////////////////
    // Depending on the TWAIN data type,
    // copying all data into object pCapInfo:
    //
    switch(pCap->ConType)
    {
        case TWON_ARRAY:
        {
            twain_log("querycap 9");
            pTW_ARRAY pArray = (pTW_ARRAY) pValue;
            long nItemSize = GetTwainTypeSize(pArray->ItemType);
            if(nItemSize) {
                long nSize = sizeof(TW_ARRAY) - sizeof(TW_UINT8) + nItemSize * pArray->NumItems;
                void * pMem = calloc(nSize, sizeof(char));
                memcpy(pMem, pArray, nSize);
                pCapInfo->tci_value.array.array_pValue = (pTW_ARRAY) pMem;
                pCapInfo->tci_value.array.array_nItemSize = nItemSize;
                pCapInfo->tci_type = capArray;
            }
            break;
        }
        case TWON_ENUMERATION:
        {
            twain_log("querycap 10");
            pTW_ENUMERATION pEnum = (pTW_ENUMERATION) pValue;
            long nItemSize = GetTwainTypeSize(pEnum->ItemType);
            if(nItemSize)
            {
                long nSize = sizeof(TW_ENUMERATION) - sizeof(TW_UINT8) + nItemSize * pEnum->NumItems;
                void * pMem = calloc(nSize, sizeof(char));
                memcpy(pMem, pEnum, nSize);
                pCapInfo->tci_value.enumeration.enum_pValue = (pTW_ENUMERATION) pMem;
                pCapInfo->tci_value.enumeration.enum_nItemSize = nItemSize;
                pCapInfo->tci_type = capEnumeration;
            }
            break;
        }
        case TWON_ONEVALUE:
        {
            twain_log("querycap 11");
            pCapInfo->tci_value.onevalue.oneval_pValue = calloc(1, sizeof(TW_ONEVALUE));
            memcpy(pCapInfo->tci_value.onevalue.oneval_pValue, pValue, sizeof(TW_ONEVALUE));
            pCapInfo->tci_type = capOneValue;
            break;
        }
        case TWON_RANGE:
        {
            twain_log("querycap 12");
            pCapInfo->tci_value.range.range_pValue = calloc(1, sizeof(TW_RANGE));
            memcpy(pCapInfo->tci_value.range.range_pValue, pValue, sizeof(TW_RANGE));
            pCapInfo->tci_type = capRange;
            break;
        }
        default:
            return -1;
    }
    
    twain_log("querycap 13");
    twainUnlockHandle(pCap->hContainer);
    twainFreeHandle(pCap->hContainer);
    pCap->hContainer = NULL;
    
    twain_log("querycap 14");
    if (pCapInfo->tci_type == capNone)
        return -1;
    
    twain_log("querycap 15");
    return 0;
}

static int twain_source_set_capability(struct twain_source * source, TW_CAPABILITY cap)
{
#if 0
	twain_source_open(source);
#endif
    
	//////////////////////////////////////////////////////////////////
	// Modify this verification, if your application also allows for
	// CAP_EXTENDEDCAPS returning that you can change source
	// while in state tsSourceEnabled or tsTransferReady;
#if 0
	if (twain_source_get_state(source) != twain_source_opened)
		return -1;
#endif
    
    twain_log("cap: %u", cap.Cap);
    if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &cap) != TWRC_SUCCESS)
        return -1;
    
    return 0;
}

static int twain_source_set_one_value_cap(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue)
{
    long nTypeSize;
    
    nTypeSize = GetTwainTypeSize(ItemType);
    return twain_source_set_one_value_with_size_cap(source, cap, ItemType, pValue, nTypeSize);
}

static int twain_source_set_one_value_with_size_cap(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue,
                                                    size_t size)
{
    pTW_ONEVALUE pVal;
    void * hGlobal;
    int bSuccess;
    
	if (pValue == NULL)
		return -1;
    
	hGlobal = twainAllocHandle(offsetof(TW_ONEVALUE, Item) + size);
	pVal = (pTW_ONEVALUE) twainLockHandle(hGlobal);
	pVal->ItemType = ItemType;
    
	memcpy(&pVal->Item, pValue, size);
    
    twainUnlockHandle(hGlobal);
    
	bSuccess = -1;
    TW_CAPABILITY twCap = {cap, TWON_ONEVALUE, hGlobal};
    bSuccess = twain_source_set_capability(source, twCap);
    
	twainFreeHandle(hGlobal);
    
	return bSuccess;
}

static int twain_source_set_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int value)
{
    return twain_source_set_one_value_cap(source, cap, TWTY_UINT16, &value);
}

static int twain_source_set_value_int16(struct twain_source * source, TW_UINT16 cap, int value)
{
    return twain_source_set_one_value_cap(source, cap, TWTY_INT16, &value);
}

static int twain_source_set_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int value)
{
    return twain_source_set_one_value_cap(source, cap, TWTY_UINT32, &value);
}

static int twain_source_set_value_int32(struct twain_source * source, TW_UINT16 cap, int value)
{
    return twain_source_set_one_value_cap(source, cap, TWTY_INT32, &value);
}

static int twain_source_set_value_fix32(struct twain_source * source, TW_UINT16 cap, float value)
{
    TW_FIX32 fix32;
    
    fix32 = FloatToFix32(value);
    return twain_source_set_one_value_cap(source, cap, TWTY_FIX32, &fix32);
}

static int twain_source_set_value_bool(struct twain_source * source, TW_UINT16 cap, int value)
{
    return twain_source_set_one_value_cap(source, cap, TWTY_BOOL, &value);
}

static int twain_source_get_specific_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 msg, TW_UINT16 ItemType, void * pValue)
{
    struct twain_capinfo capInfo;
    TW_CAPABILITY twCap = {cap, TWON_DONTCARE16, NULL};
    long nTypeSize;
    
    nTypeSize = GetTwainTypeSize(ItemType);
    if (twain_source_query_capability(source, &twCap, &capInfo, msg) == 0) {
        if(capInfo.tci_type == capOneValue && capInfo.tci_value.onevalue.oneval_pValue->ItemType == ItemType) {
            memcpy(pValue, &capInfo.tci_value.onevalue.oneval_pValue->Item, nTypeSize);
            return 0;
        }
    }
    return -1;
}

static int twain_source_get_current_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue)
{
    return twain_source_get_specific_value(source, cap, MSG_GETCURRENT, ItemType, pValue);
}

static int twain_source_get_default_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue)
{
    return twain_source_get_specific_value(source, cap, MSG_GETDEFAULT, ItemType, pValue);
}

static int twain_source_get_value(struct twain_source * source, TW_UINT16 cap, TW_UINT16 ItemType, void * pValue)
{
    return twain_source_get_specific_value(source, cap, MSG_GET, ItemType, pValue);
}

static int twain_source_get_current_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes)
{
    TW_FIX32 value;
    
    if (twain_source_get_current_value(source, cap, TWTY_FIX32, &value) == -1)
        return -1;
    
    * pfRes = Fix32ToFloat(value);
    return 0;
}

static int twain_source_get_current_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT16 value;
    
    if (twain_source_get_current_value(source, cap, TWTY_INT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_current_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT16 value;
    
    if (twain_source_get_current_value(source, cap, TWTY_UINT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_current_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT32 value;
    
    if (twain_source_get_current_value(source, cap, TWTY_INT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_current_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT32 value;
    
    if (twain_source_get_current_value(source, cap, TWTY_UINT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_current_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_BOOL value;
    
    if (twain_source_get_current_value(source, cap, TWTY_BOOL, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_default_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes)
{
    TW_FIX32 fix;
    
    if (twain_source_get_default_value(source, cap, TWTY_FIX32, &fix) == -1)
        return -1;
    
    * pfRes = Fix32ToFloat(fix);
    return 0;
}

static int twain_source_get_default_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT16 value;
    
    if (twain_source_get_default_value(source, cap, TWTY_INT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_default_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT16 value;
    
    if (twain_source_get_default_value(source, cap, TWTY_UINT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_default_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT32 value;
    
    if (twain_source_get_default_value(source, cap, TWTY_INT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_default_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT32 value;
    
    if (twain_source_get_default_value(source, cap, TWTY_UINT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_default_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_BOOL value;
    
    if (twain_source_get_default_value(source, cap, TWTY_BOOL, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_value_fix32(struct twain_source * source, TW_UINT16 cap, float * pfRes)
{
    TW_FIX32 fix;
    
    if (twain_source_get_value(source, cap, TWTY_FIX32, &fix) == -1)
        return -1;
    
    * pfRes = Fix32ToFloat(fix);
    return 0;
}

static int twain_source_get_value_int16(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT16 value;
    
    if (twain_source_get_value(source, cap, TWTY_INT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_value_uint16(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT16 value;
    
    if (twain_source_get_value(source, cap, TWTY_UINT16, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_value_int32(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_INT32 value;
    
    if (twain_source_get_value(source, cap, TWTY_INT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_value_uint32(struct twain_source * source, TW_UINT16 cap, unsigned int * pValue)
{
    TW_UINT32 value;
    
    if (twain_source_get_value(source, cap, TWTY_UINT32, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_get_value_bool(struct twain_source * source, TW_UINT16 cap, int * pValue)
{
    TW_BOOL value;
    
    if (twain_source_get_value(source, cap, TWTY_BOOL, &value) == -1)
        return -1;
    
    * pValue = value;
    return 0;
}

static int twain_source_is_item_in_cap_supported(struct twain_source * source, int cap, int value)
{
    TW_CAPABILITY twCap = {cap, TWON_DONTCARE16, NULL};
    struct twain_capinfo info;
    if (twain_source_query_capability(source, &twCap, &info, MSG_GET) == -1)
        return 0;
    
    if (info.tci_type == capEnumeration && info.tci_value.enumeration.enum_nItemSize == sizeof(TW_UINT16)) {
        long nItems;
        TW_UINT16 i;
        
        nItems = info.tci_value.enumeration.enum_pValue->NumItems;
        for(i = 0 ; i < nItems ; i ++)
            if(info.tci_value.enumeration.enum_pValue->ItemList[i * 2] == value)
                return 1;
    }
    return 0;
}

int twain_source_get_resolution(struct twain_source * source, float * pfRes)
{
    return twain_source_get_current_value_fix32(source, ICAP_XRESOLUTION, pfRes);
}

int twain_source_set_resolution(struct twain_source * source, float fRes)
{
    int res;
    
    res = twain_source_set_value_fix32(source, ICAP_XRESOLUTION, fRes);
    if (res == -1)
        return res;
    
    res = twain_source_set_value_fix32(source, ICAP_YRESOLUTION, fRes);
    if (res == -1)
        return res;
    
    return 0;
}

int twain_source_get_units(struct twain_source * source, enum twain_unit * pUnits)
{
	unsigned int units;
	
    return twain_source_get_current_value_uint16(source, ICAP_UNITS, &units);
	* pUnits = units;
}

int twain_source_set_units(struct twain_source * source, enum twain_unit uUnits)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 490;
    return twain_source_set_value_uint16(source, ICAP_UNITS, uUnits);
}


int twain_source_is_units_supported(struct twain_source * source, enum twain_unit units)
{
	return twain_source_is_item_in_cap_supported(source, ICAP_UNITS, units);
}

int twain_source_set_pixel_type(struct twain_source * source, enum twain_pixel_type type)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 475;
    return twain_source_set_value_uint16(source, ICAP_PIXELTYPE, type);
}

int twain_source_get_pixel_type(struct twain_source * source, enum twain_pixel_type * pType)
{
	unsigned int value;
	
    if (twain_source_get_current_value_uint16(source, ICAP_PIXELTYPE, &value) == -1)
		return -1;
	* pType = value;
	
	return 0;
}

int twain_source_set_xfer_count(struct twain_source * source, int count)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 411;
    return twain_source_set_value_int16(source, CAP_XFERCOUNT, count);
}

int twain_source_get_xfer_count(struct twain_source * source, int * pCount)
{
    return twain_source_get_current_value_int16(source, CAP_XFERCOUNT, pCount);
}

int twain_source_set_brightness(struct twain_source * source, float fBrightness)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 428;
    return twain_source_set_value_fix32(source, ICAP_BRIGHTNESS, fBrightness);
}

int twain_source_get_brightness(struct twain_source * source, float * pfBrightness)
{
    return twain_source_get_current_value_fix32(source, ICAP_BRIGHTNESS, pfBrightness);
}

int twain_source_set_contrast(struct twain_source * source, float fContrast)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 432;
    return twain_source_set_value_fix32(source, ICAP_CONTRAST, fContrast);
}

int twain_source_get_contrast(struct twain_source * source, float * pfContrast)
{
    return twain_source_get_current_value_fix32(source, ICAP_CONTRAST, pfContrast);
}

int twain_source_set_image_layout(struct twain_source * source, float left, float top, float width, float height)
{
    // See TWAIN Spec. 1.9, Chapter 7, page 242;
	TW_IMAGELAYOUT layout;
	
#if 0
    twain_source_open(source);
#endif
    
    if (twain_source_get_state(source) != twain_source_opened)
        return -1;
    
    layout.Frame.Left = FloatToFix32(left);
    layout.Frame.Top = FloatToFix32(top);
    layout.Frame.Right = FloatToFix32(left + width);
    layout.Frame.Bottom = FloatToFix32(top + height);
    layout.DocumentNumber = TWON_DONTCARE32;
    layout.PageNumber = TWON_DONTCARE32;
    layout.FrameNumber = TWON_DONTCARE32;
	
    if (ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGELAYOUT, MSG_SET, &layout) != TWRC_SUCCESS)
        return -1;
    
    return 0;
}

int twain_source_get_image_layout(struct twain_source * source, float * pLeft, float * pTop, float * pWidth, float * pHeight)
{
    // See TWAIN Spec. 1.9, Chapter 7, page 238;
	TW_IMAGELAYOUT layout;
	
#if 0
    twain_source_open(source);
#endif
    
    if (twain_source_get_state(source) < twain_source_opened || twain_client_get_state(source->ts_client) > twain_source_transfer_ready)
        return -1;
    
    if (ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGELAYOUT, MSG_GET, &layout) != TWRC_SUCCESS)
        return -1;
    
	* pLeft = Fix32ToFloat(layout.Frame.Left);
	* pTop = Fix32ToFloat(layout.Frame.Top);
	* pWidth = Fix32ToFloat(layout.Frame.Right) - Fix32ToFloat(layout.Frame.Left);
	* pHeight = Fix32ToFloat(layout.Frame.Bottom) - Fix32ToFloat(layout.Frame.Top);
	
    return 0;
}

int twain_source_set_xfer_mode(struct twain_source * source, enum twain_xfer_mode mode)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 491;
    int res;
    
    res = twain_source_set_value_uint16(source, CAP_XFERCOUNT, mode);
    if (res == 0) {
        source->ts_xfer_mode = mode;
    }
    return res;
}

enum twain_xfer_mode twain_source_get_xfer_mode(struct twain_source * source)
{
    return source->ts_xfer_mode;
}

int twain_source_is_xfer_mode_supported(struct twain_source * source, enum twain_xfer_mode mode)
{
	return twain_source_is_item_in_cap_supported(source, ICAP_XFERMECH, mode);
}

int twain_source_set_bit_depth(struct twain_source * source, int depth)
{
    // See TWAIN Spec. 1.9, Chapter 9, page 491;
    return twain_source_set_value_int16(source, ICAP_BITDEPTH, depth);
}

int twain_source_get_bit_depth(struct twain_source * source, int * pDepth)
{
	return twain_source_get_current_value_int16(source, ICAP_BITDEPTH, pDepth);
}

int twain_source_is_uicontrollable(struct twain_source * source)
{
	int result;
	
	result = 0;
	twain_source_get_current_value_bool(source, CAP_UICONTROLLABLE, &result);
	if (result)
		return 1;
	
	twain_source_get_default_value_bool(source, CAP_UICONTROLLABLE, &result);
	if (result)
		return 1;
	
	twain_source_get_value_bool(source, CAP_UICONTROLLABLE, &result);
	if (result)
		return 1;
	
	return 0;
}

int twain_source_is_online(struct twain_source * source)
{
    int result;
    
    result = 0;
	twain_source_get_current_value_bool(source, CAP_DEVICEONLINE, &result);
    if (result)
        return 1;
    
	twain_source_get_value_bool(source, CAP_DEVICEONLINE, &result);
    if (result)
        return 1;
    
    return 0;
}

int twain_source_open(struct twain_source * source)
{
    if(twain_source_get_state(source) == twain_source_opened)
        return 0;
    
    if(twain_source_get_state(source) != twain_source_closed)
        return -1;
    
    if (dsm_entry(source->ts_client, DG_CONTROL, DAT_IDENTITY, MSG_OPENDS, (TW_MEMREF) &source->ts_identity) == TWRC_SUCCESS) {
        set_twain_source_state(source, twain_source_opened);
        return 0;
    }
    
    return -1;
}

int twain_source_close(struct twain_source * source)
{
    twain_source_disable(source);
    
    if (twain_source_get_state(source) != twain_source_opened)
		return -1;
	
	if (dsm_entry(source->ts_client, DG_CONTROL, DAT_IDENTITY, MSG_CLOSEDS, (TW_MEMREF) &source->ts_identity) != TWRC_SUCCESS)
		return -1;
	
	set_twain_source_state(source, twain_source_closed);
	
	return 0;
}

static int twain_source_disable(struct twain_source * source)
{
    if (twain_source_get_state(source) >= twain_source_enabled) {
        if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, &source->ts_ui) == TWRC_SUCCESS) {
            set_twain_source_state(source, twain_source_opened);
            return 0;
        }
    }
    return -1;
}

static TW_STATUS twain_source_get_status(struct twain_source * source)
{
    return source->ts_status;
}

static int twain_source_set_device_event(struct twain_source * source, TW_UINT16 * values_array, unsigned int count)
{
    pTW_ARRAY pVal;
    void * hGlobal;
    
	hGlobal = twainAllocHandle(offsetof(TW_ARRAY, ItemList) + sizeof(TW_UINT16) * count);
	pVal = (pTW_ARRAY) twainLockHandle(hGlobal);
	pVal->ItemType = TWTY_UINT16;
    pVal->NumItems = count;
    
	memcpy(&pVal->ItemList, values_array, sizeof(TW_UINT16) * count);
    
    twainUnlockHandle(hGlobal);
    
    TW_CAPABILITY twCap = {CAP_DEVICEEVENT, TWON_ARRAY, hGlobal};
    if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &twCap) != TWRC_SUCCESS) {
        twain_log("failed");
        return -1;
    }
    
	twainFreeHandle(hGlobal);
    
	return 0;
}

static TW_INT16 register_callback(struct twain_client * client)
{
    TW_INT16 result = TWRC_SUCCESS;
    TW_CALLBACK	callback;
    
#if 0
    struct twain_source * cur;
    TW_UINT16 event_array[15];
    
#if 0
    event_array[0] = TWDE_CHECKAUTOMATICCAPTURE;
    event_array[1] = TWDE_CHECKBATTERY;
    event_array[2] = TWDE_CHECKFLASH;
    event_array[3] = TWDE_CHECKPOWERSUPPLY;
    event_array[4] = TWDE_CHECKRESOLUTION;
    event_array[5] = TWDE_DEVICEADDED;
    event_array[6] = TWDE_DEVICEOFFLINE;
    event_array[7] = TWDE_DEVICEREADY;
    event_array[8] = TWDE_DEVICEREMOVED;
    event_array[9] = TWDE_IMAGECAPTURED;
    event_array[10] = TWDE_IMAGEDELETED;
    event_array[11] = TWDE_PAPERDOUBLEFEED;
    event_array[12] = TWDE_PAPERJAM;
    event_array[13] = TWDE_LAMPFAILURE;
    event_array[14] = TWDE_POWERSAVENOTIFY;
#endif
    event_array[0] = TWDE_DEVICEADDED;
    event_array[1] = TWDE_DEVICEREMOVED;
    event_array[2] = TWDE_DEVICEREADY;
    //twain_source_set_device_event(client, event_array, 2);
#if 1
    for(cur = client->tc_source_list ; cur != NULL ; cur = cur->ts_next) {
        twain_source_set_device_event(cur, event_array, 2);
    }
#endif
#endif
    
    callback.CallBackProc = (TW_MEMREF) global_callback;
    callback.RefCon       = (TW_MEMREF) client;
    callback.Message      = 0;
    result = dsm_entry(client, DG_CONTROL, DAT_CALLBACK, MSG_REGISTER_CALLBACK, &callback);
	
    return result;
}

static void unregister_callback(struct twain_client * client)
{
}

struct callback_data {
    struct twain_client * client;
	pTW_IDENTITY origin;
    TW_UINT16 MSG;
    struct callback_data * next;
};

#if 0
static void event_timer(EventLoopTimerRef inTimer, void * inUserData)
{
    struct callback_data * data;
    
    data = inUserData;
	on_twain_message(data->client, data->origin, data->MSG);
    free(data);
}
#endif

static TW_UINT16 global_callback(pTW_IDENTITY pOrigin,
                                 pTW_IDENTITY	pDest,
                                 TW_UINT32		DG,
                                 TW_UINT16		DAT,
                                 TW_UINT16		MSG,
                                 TW_MEMREF		pData)
{
    pTW_CALLBACK pCallback;
    struct twain_client * client;
    struct callback_data * data;
    struct callback_data * current_data;
    struct callback_data * last;
    
    pCallback = (pTW_CALLBACK) pData;
    
    client = (struct twain_client *) pCallback->RefCon;
    twain_log("global callback %p %u", client, MSG);
    
    data = calloc(1, sizeof(* data));
    data->client = client;
	data->origin = pOrigin;
    data->MSG = MSG;
    
    pthread_mutex_lock(&client->tc_queue_lock);
    current_data = client->tc_queue;
    last = NULL;
    while (current_data != NULL) {
        last = current_data;
        current_data = current_data->next;
    }
    if (last == NULL) {
        client->tc_queue = data;
    }
    else {
        last->next = data;
    }
    pthread_mutex_unlock(&client->tc_queue_lock);
    
    //InstallEventLoopTimer(GetCurrentEventLoop(), 0, 0, event_timer, data, NULL);
    twain_client_signal_runloop(client);
    
    return TWRC_SUCCESS;
}

int twain_source_acquire(struct twain_source * source, int show_ui)
{
    TW_UINT16 rc;
    
#if 0
    twain_source_open(source); // Open, if it is not open yet;
#endif
    
    if (twain_source_get_state(source) != twain_source_opened)
        return -1;
    
    source->ts_client->tc_current_source = source;
    
    source->ts_ui.ShowUI = show_ui;
    source->ts_ui.hParent = (TW_HANDLE) NULL;
    source->ts_ui.ModalUI = 0;//(TW_BOOL) show_ui;
	
    twain_log("client acquire");
    rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, &source->ts_ui);
    if (!show_ui && rc == TWRC_CHECKSTATUS) {	// If the Source doesn't support "No UI" mode;
        source->ts_ui.ShowUI = true;				// We do have UI displayed;
        rc = TWRC_SUCCESS;					// And it is a successful operation anyway;
    }
    twain_log("client acquire ok");
    if (rc == TWRC_SUCCESS) {					// If successful;
        set_twain_source_state(source, twain_source_enabled);			// Update the state;
        return 0;						// Return "Success"
    }
    return -1; // Return "Failed";
}

static int on_twain_message(struct twain_client * client, pTW_IDENTITY dest, TW_UINT16 MSG)
{
	/////////////////////////////////////////////////////////
	// Any message coming from the window while TWAIN status
	// is not tsSourceEnabled should not be processed at all;
	// See TWAIN Spec 1.9, page 222 at the bottom;
	//
    struct twain_source * cur;
    struct twain_source * source;
    
    twain_log("on twain message");
#if 0
	if(client->tc_twainState < tsSourceEnabled)	// If the Source isn't enabled;
		return 0;				// Return "Not Processed";
#endif
    
    source = NULL;
    for(cur = client->tc_source_list ; cur != NULL ; cur = cur->ts_next) {
        twain_log("%p / %p", dest->Id, cur->ts_identity.Id);
        if (dest->Id == cur->ts_identity.Id) {
            source = cur;
        }
#if 0
        if (memcmp(&cur->ts_identity, dest, sizeof(cur->ts_identity)) == 0) {
            source = cur;
        }
#endif
    }
    
    if (source == NULL) {
        //twain_log("null source %p", dest->Id);
        //source = client->tc_source_list;
        source = client->tc_current_source;
    }
    client->tc_current_source = NULL;
    
	/////////////////////////////////////////////
	// Once we are here, the event was processed
	// by the Source, and we can continue on:
	//
	//switch(twEvent.TWMessage) {
	switch(MSG) {
        case MSG_CLOSEDSREQ: // Requested to close the Source UI;
            on_close_ds_request(source);
			break;
        case MSG_XFERREADY: // Ready to start transfer of images;
            on_xfer_ready(source);
        case MSG_CLOSEDSOK:
            on_closed_ok(source);
            break;
        case MSG_DEVICEEVENT:
            on_device_event(source);
            break;
        default:
            break;
	}
	return 1;
}

static void on_closed_ok(struct twain_source * source)
{
    twain_log("closed ok");
    twain_source_disable(source);
    twain_source_close(source);
}

static void on_device_event(struct twain_source * source)
{
    unsigned int event;
    
    event = 0;
    twain_log("device event %p", source);
    twain_source_get_device_event(source, &event);
    twain_log("device event %p, %i", source, event);
}

static void on_close_ds_request(struct twain_source * source)
{
    twain_log("closed sreq");
    if (source->ts_state == twain_source_enabled){
        if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, &source->ts_ui) == TWRC_SUCCESS) {
            set_twain_source_state(source, twain_source_opened);
        }
        //CloseSource();//8514
    }
    twain_source_close(source);//8514
}

static void on_xfer_ready(struct twain_source * source)
{
    TW_UINT16 rc;
    PicHandle hBitmap;
    int PendingXfers;
    long nImageIndex;
    TW_IMAGEINFO twImageInfo;
    TW_SETUPFILEXFER twsfx;
    TW_SETUPMEMXFER twsx;
    TW_IMAGEMEMXFER mx;
    TW_PENDINGXFERS twPendingXfers;
    
    twain_log("xfer ready");
    set_twain_source_state(source, twain_source_transfer_ready);
    
    rc = TWRC_SUCCESS;
    hBitmap = NULL;
    PendingXfers = 1;
    nImageIndex = 0;
    
    memset(&twImageInfo, 0, sizeof(TW_IMAGEINFO));
    memset(&twsfx, 0, sizeof(TW_SETUPFILEXFER));
    memset(&twsx, 0, sizeof(TW_SETUPMEMXFER));
    memset(&mx, 0, sizeof(TW_IMAGEMEMXFER));
    
    while (PendingXfers){
        switch(source->ts_xfer_mode) {
            case twain_xfer_native:
            {
                rc = ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGEINFO, MSG_GET, (TW_MEMREF)&twImageInfo);
                rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_GET, (TW_MEMREF)&twPendingXfers );
                break;
            }
            case twain_xfer_file:
            {
                rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_SETUPFILEXFER, MSG_GET, &twsfx);
                if(rc == TWRC_SUCCESS) {
                    if (on_setup_file_xfer(source, &twsfx, nImageIndex))
                        rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_SETUPFILEXFER, MSG_SET, &twsfx);
                    else
                        rc  = TWRC_FAILURE;
                }
                rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_GET, (TW_MEMREF)&twPendingXfers );
                break;
            }
            case twain_xfer_memory:
            {
                twain_log("xfer mem 1");
                rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_SETUPMEMXFER, MSG_GET, &twsx);
                if (rc == TWRC_SUCCESS) {
                    twain_log("xfer mem 2");
                    rc = ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGEINFO, MSG_GET, &twImageInfo);
                    if (rc == TWRC_SUCCESS) {
                        twain_log("xfer mem 3");
                        if(!on_memory_xfer_ready(source, &twImageInfo)) {
                            twain_log("failure");
                            rc  = TWRC_FAILURE;
                        }
                        else {
                            twain_log("image info: %g %g %u %u", 0.0, 0.0, twImageInfo.ImageWidth, twImageInfo.ImageLength);
                        }
                    }
                }
                rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_GET, (TW_MEMREF)&twPendingXfers );
                break;
            }
            default:
                break;
        }
        
        nImageIndex ++; // Increment images;
        
        if(rc != TWRC_SUCCESS) {
            rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &twPendingXfers);
            if(rc == TWRC_FAILURE && twain_source_get_status(source).ConditionCode == TWCC_SEQERROR) {
                set_twain_source_state(source, twain_source_closed);
                return;
            }
            break;
        }
        
        hBitmap = NULL;
        
        switch (source->ts_xfer_mode) {
            case twain_xfer_native:
            {
                rc = ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGENATIVEXFER, MSG_GET, &hBitmap);
                break;
            }
            case twain_xfer_file:
            {
                rc = ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGEFILEXFER, MSG_GET, NULL);
                break;
            }
            case twain_xfer_memory:
            {
                void * pBuffer = malloc(twsx.Preferred);
                if(pBuffer) {
                    long nRow = 0;
                    while(rc == TWRC_SUCCESS) {
                        mx.Compression = TWON_DONTCARE16;
                        mx.BytesPerRow = TWON_DONTCARE32;
                        mx.BytesWritten = TWON_DONTCARE32;
                        mx.Columns = TWON_DONTCARE32;
                        mx.Rows = TWON_DONTCARE32;
                        mx.XOffset = TWON_DONTCARE32;
                        mx.YOffset = TWON_DONTCARE32;
                        mx.Memory.TheMem = pBuffer;
                        mx.Memory.Length = twsx.Preferred;
                        mx.Memory.Flags = TWMF_APPOWNS | TWMF_POINTER;
                        rc = ds_entry(source->ts_client, source, DG_IMAGE, DAT_IMAGEMEMXFER, MSG_GET, &mx);
                        if (rc == TWRC_SUCCESS || rc == TWRC_XFERDONE) {
                            if(mx.Rows > (TW_UINT32) twImageInfo.ImageLength - nRow)
                                mx.Rows = twImageInfo.ImageLength - nRow;
                            
                            if (!on_mem_xfer_buffer(source, &mx, nRow, nImageIndex - 1)) {
                                rc = TWRC_CANCEL;
                                break;
                            }
                            
                            // transfer the information here
                            ////////////////////////////////
                            
                            nRow += mx.Rows;
                        }
                    }
                    free(pBuffer);
                    on_mem_xfer_done(source, 1);
                }
                else
                {
                    on_low_memory(source->ts_client); // Memory shortage;
                    on_mem_xfer_done(source, 0);
                }
                break;
            }
            default:
                break;
        }
        
        twain_log("xfer done ?");
        switch(rc) {
            case TWRC_XFERDONE:
            {
                bool bCancelTransfer;
                
                set_twain_source_state(source, twain_source_transferring);
                bCancelTransfer = true;
                switch (source->ts_xfer_mode) {
                    case twain_xfer_native:
                    {
                        bCancelTransfer = !on_copy_image(source, hBitmap, &twImageInfo, nImageIndex - 1);
                        break;
                    }
                    case twain_xfer_file:
                    {
                        bCancelTransfer = !on_file_xfer(source, &twsfx, nImageIndex - 1);
                        break;
                    }
                    case twain_xfer_memory:
                    {
                        bCancelTransfer = !on_mem_xfer_next_image(source, &mx, nImageIndex);
                        break;
                    }
                    default:
                        break;
                }
                
                twain_log("cancel transfer ? %i", bCancelTransfer);
                if (bCancelTransfer) {
                    // The application requested to stop transfer of images;
                    rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &twPendingXfers);
                    if (rc == TWRC_FAILURE && twain_source_get_status(source).ConditionCode == TWCC_SEQERROR) {
                        /////////////////////////////////////////////////////////////
                        // This only happens for UI-s that disappear automatically
                        // once they start feeding in images back to the application;
                        // This means the Source has been already disabled, and all we
                        // need is to change the state:
                        set_twain_source_state(source, twain_source_closed);
                        return;
                    }
                    PendingXfers = 0; // No more images, please;
                }
                else 
                {
                    twain_log("xfer done xx");
                    rc = ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, &twPendingXfers);
                    if(rc == TWRC_SUCCESS) {
                        set_twain_source_state(source, twain_source_transfer_ready);
                        if (twPendingXfers.Count) { // If more images pending;
                            continue;
                        }
                        else {
                            // No more images left;
                            set_twain_source_state(source, twain_source_enabled);
                            PendingXfers = 0; // No more images;
                        }
                    }
                }
                break;
            }
            case TWRC_CANCEL:
            {
                set_twain_source_state(source, twain_source_transfer_ready);
                ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, &twPendingXfers);
                PendingXfers = 0;
                break;
            }
            case TWRC_FAILURE:
            {
                ds_entry(source->ts_client, source, DG_CONTROL, DAT_PENDINGXFERS, MSG_RESET, &twPendingXfers);
                set_twain_source_state(source, twain_source_enabled); // This is only for images; For audio it remains tsTransferReady;
                PendingXfers = 0;
                break;
            }
            default:
                break;
        }
        ReleaseResource((Handle) hBitmap);
    }
    
    ds_entry(source->ts_client, source, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, &source->ts_ui);
    set_twain_source_state(source, twain_source_opened);
}

int twain_source_set_indicators_enabled(struct twain_source * source, int enabled)
{
    return twain_source_set_value_bool(source, CAP_INDICATORS, enabled);
}

int twain_source_get_indicators_enabled(struct twain_source * source, int * p_enabled)
{
    return twain_source_get_current_value_bool(source, CAP_INDICATORS, p_enabled);
}

static int twain_source_get_device_event(struct twain_source * source, unsigned int * pEvent)
{
	TW_UINT16 event;
	
    if (ds_entry(source->ts_client, source, DG_CONTROL, DAT_DEVICEEVENT, MSG_GET, &event) != TWRC_SUCCESS)
        return -1;
    
	* pEvent = event;
    
    return 0;
}

char * twain_source_get_name(struct twain_source * source)
{
    return ((char *) source->ts_identity.ProductName) + 1;
}

int twain_source_set_feeder_enabled(struct twain_source * source, int enabled)
{
    return twain_source_set_value_bool(source, CAP_FEEDERENABLED, enabled);
}

int twain_source_set_auto_feeder_enabled(struct twain_source * source, int enabled)
{
    return twain_source_set_value_bool(source, CAP_AUTOFEED, enabled);
}

int twain_source_has_feeder(struct twain_source * source)
{
    int value;
    
    value = 0;
    twain_source_get_current_value_bool(source, CAP_FEEDERENABLED, &value);
    if (value)
        return 1;
    
    twain_source_get_value_bool(source, CAP_FEEDERENABLED, &value);
    if (value)
        return 1;
    
    return 0;
}

int twain_source_is_feeder_loaded(struct twain_source * source)
{
    int value;
    
    value = 0;
    twain_source_get_current_value_bool(source, CAP_FEEDERLOADED, &value);
    if (value)
        return 1;
    
    twain_source_get_value_bool(source, CAP_FEEDERLOADED, &value);
    if (value)
        return 1;
    
    return 0;
}

static void client_schedule(void * info, CFRunLoopRef rl, CFStringRef mode)
{
}

static void client_perform(void * info)
{
    struct twain_client * client;
    struct callback_data * data;
    
    client = info;
    
    pthread_mutex_lock(&client->tc_queue_lock);
    data = client->tc_queue;
    client->tc_queue = data->next;
    pthread_mutex_unlock(&client->tc_queue_lock);
    
	on_twain_message(data->client, data->origin, data->MSG);
    free(data);
}

static void client_cancel(void * info, CFRunLoopRef rl, CFStringRef mode)
{
}

static void twain_client_signal_runloop(struct twain_client * client)
{
    CFRunLoopSourceSignal(client->tc_source);
    CFRunLoopWakeUp(client->tc_runloop);
}

void twain_client_register_runloop(struct twain_client * client, CFRunLoopRef runloop)
{
    CFRunLoopSourceContext context = {
        0,
        client,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        client_schedule,
        client_cancel,
        client_perform,
    };
    
    if (client->tc_source != NULL) {
        twain_client_unregister_runloop(client);
    }
    
    client->tc_runloop = runloop;
	client->tc_source = CFRunLoopSourceCreate(NULL, 0, &context);
    CFRunLoopAddSource(client->tc_runloop, client->tc_source, kCFRunLoopCommonModes);
}

static void twain_client_unregister_runloop(struct twain_client * client)
{
    CFRunLoopRemoveSource(client->tc_runloop, client->tc_source, kCFRunLoopCommonModes);
    CFRelease(client->tc_source);
    client->tc_runloop = NULL;
    client->tc_source = NULL;
}

static void twain_log(const char * format, ...)
{
    va_list ap;
    va_start(ap, format);
    (void) vfprintf(stderr, format, ap);
    va_end(ap);
    fprintf(stderr, "\n");
}
