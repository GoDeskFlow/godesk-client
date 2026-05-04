// Order matters: vpx_encoder.h MUST come before vp8cx.h, otherwise bindgen
// sees the opaque forward-declaration of vpx_codec_enc_cfg in vp8cx.h first
// and emits `pub struct vpx_codec_enc_cfg { _address: u8 }` instead of the
// real fields (g_w, g_h, kf_*, rc_*, ...). Cargo build then fails with
// dozens of E0609 "no field on type". Discovered with libvpx 1.15.2.
#include <vpx/vpx_integer.h>
#include <vpx/vpx_image.h>
#include <vpx/vpx_codec.h>
#include <vpx/vpx_encoder.h>
#include <vpx/vpx_decoder.h>
#include <vpx/vpx_frame_buffer.h>
#include <vpx/vp8.h>
#include <vpx/vp8cx.h>
#include <vpx/vp8dx.h>
