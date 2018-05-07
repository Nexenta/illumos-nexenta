/*-
 * Copyright (c) 2000 Doug Rabson
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/cdefs.h>

#include <efi.h>
#include <efilib.h>
#include <sys/tem_impl.h>
#include <sys/multiboot2.h>
#include <machine/metadata.h>
#include <gfx_fb.h>

#include "bootstrap.h"

struct efi_fb		efifb;
EFI_GRAPHICS_OUTPUT	*gop;
EFI_UGA_DRAW_PROTOCOL	*uga;

static EFI_GUID ccontrol_protocol_guid = EFI_CONSOLE_CONTROL_PROTOCOL_GUID;
static EFI_CONSOLE_CONTROL_PROTOCOL	*console_control;
static EFI_GUID simple_input_ex_guid = EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL_GUID;
static EFI_SIMPLE_TEXT_INPUT_EX_PROTOCOL *coninex;
static SIMPLE_TEXT_OUTPUT_INTERFACE	*conout;
static SIMPLE_INPUT_INTERFACE		*conin;
static EFI_CONSOLE_CONTROL_SCREEN_MODE	console_mode;

/* mode change callback and argument from tem */
static vis_modechg_cb_t modechg_cb;
static struct vis_modechg_arg *modechg_arg;
static tem_vt_state_t tem;

#define	KEYBUFSZ 10
static unsigned keybuf[KEYBUFSZ];      /* keybuf for extended codes */

static const unsigned char solaris_color_to_efi_color[16] = {
	EFI_WHITE,
	EFI_BLACK,
	EFI_BLUE,
	EFI_GREEN,
	EFI_CYAN,
	EFI_RED,
	EFI_MAGENTA,
	EFI_BROWN,
	EFI_LIGHTGRAY,
	EFI_DARKGRAY,
	EFI_LIGHTBLUE,
	EFI_LIGHTGREEN,
	EFI_LIGHTCYAN,
	EFI_LIGHTRED,
	EFI_LIGHTMAGENTA,
	EFI_YELLOW
};

#define	DEFAULT_FGCOLOR	EFI_LIGHTGRAY
#define	DEFAULT_BGCOLOR	EFI_BLACK

extern int efi_find_framebuffer(struct efi_fb *efifb);

static void efi_framebuffer_setup(void);
static void efi_cons_probe(struct console *);
static int efi_cons_init(struct console *, int);
static void efi_cons_putchar(struct console *, int);
static void efi_cons_efiputchar(int);
static int efi_cons_getchar(struct console *);
static int efi_cons_poll(struct console *);
static int efi_cons_ioctl(struct console *cp, int cmd, void *data);

static int efi_fb_devinit(struct vis_devinit *);
static void efi_cons_cursor(struct vis_conscursor *);

static int efi_text_devinit(struct vis_devinit *);
static int efi_text_cons_clear(struct vis_consclear *);
static void efi_text_cons_copy(struct vis_conscopy *);
static void efi_text_cons_display(struct vis_consdisplay *);

struct console efi_console = {
	.c_name = "text",
	.c_desc = "EFI console",
	.c_flags = C_WIDEOUT,
	.c_probe = efi_cons_probe,
	.c_init = efi_cons_init,
	.c_out = efi_cons_putchar,
	.c_in = efi_cons_getchar,
	.c_ready = efi_cons_poll,
	.c_ioctl = efi_cons_ioctl,
	.c_private = NULL
};

static struct vis_identifier fb_ident = { "efi_fb" };
static struct vis_identifier text_ident = { "efi_text" };

struct visual_ops fb_ops = {
	.ident = &fb_ident,
	.kdsetmode = NULL,
	.devinit = efi_fb_devinit,
	.cons_copy = NULL,
	.cons_display = NULL,
	.cons_cursor = efi_cons_cursor,
	.cons_clear = NULL,
	.cons_put_cmap = NULL
};

struct visual_ops text_ops = {
	.ident = &text_ident,
	.kdsetmode = NULL,
	.devinit = efi_text_devinit,
	.cons_copy = efi_text_cons_copy,
	.cons_display = efi_text_cons_display,
	.cons_cursor = efi_cons_cursor,
	.cons_clear = efi_text_cons_clear,
	.cons_put_cmap = NULL
};

/*
 * platform specific functions for tem
 */
int
plat_stdout_is_framebuffer(void)
{
	return (console_mode == EfiConsoleControlScreenGraphics);
}

void
plat_tem_hide_prom_cursor(void)
{
	conout->EnableCursor(conout, FALSE);
}

void
plat_tem_get_prom_pos(uint32_t *row, uint32_t *col)
{
	if (console_mode == EfiConsoleControlScreenText) {
		*col = (uint32_t)conout->Mode->CursorColumn;
		*row = (uint32_t)conout->Mode->CursorRow;
	} else {
		*col = 0;
		*row = 0;
	}
}

/*
 * plat_tem_get_prom_size() is supposed to return screen size
 * in chars. Return real data for text mode and TEM defaults for graphical
 * mode, so the tem can compute values based on default and font.
 */
void
plat_tem_get_prom_size(size_t *height, size_t *width)
{
	UINTN cols, rows;
	if (console_mode == EfiConsoleControlScreenText) {
		(void) conout->QueryMode(conout, conout->Mode->Mode,
		    &cols, &rows);
		*height = (size_t)rows;
		*width = (size_t)cols;
	} else {
		*height = TEM_DEFAULT_ROWS;
		*width = TEM_DEFAULT_COLS;
	}
}

/*
 * Callback to notify about console mode change.
 * mode is value from enum EFI_CONSOLE_CONTROL_SCREEN_MODE.
 */
void
plat_cons_update_mode(int mode)
{
	EFI_STATUS status;
	UINTN cols, rows;
	struct vis_devinit devinit;

	/* Make sure we have usable console. */
	if (efi_find_framebuffer(&efifb)) {
		console_mode = EfiConsoleControlScreenText;
	} else {
		efi_framebuffer_setup();
		if (mode != -1 && console_mode != mode)
			console_mode = mode;
	}

	if (console_control != NULL)
		(void)console_control->SetMode(console_control, console_mode);

	/* some firmware enables the cursor when switching modes */
	conout->EnableCursor(conout, FALSE);
	if (console_mode == EfiConsoleControlScreenText) {
		(void)conout->QueryMode(conout, conout->Mode->Mode,
		    &cols, &rows);
		devinit.version = VIS_CONS_REV;
		devinit.width = cols;
		devinit.height = rows;
		devinit.depth = 4;
		devinit.linebytes = cols;
		devinit.color_map = NULL;
		devinit.mode = VIS_TEXT;
		efi_console.c_private = &text_ops;
	} else {
		devinit.version = VIS_CONS_REV;
		devinit.width = gfx_fb.framebuffer_common.framebuffer_width;
		devinit.height = gfx_fb.framebuffer_common.framebuffer_height;
		devinit.depth = gfx_fb.framebuffer_common.framebuffer_bpp;
		devinit.linebytes = gfx_fb.framebuffer_common.framebuffer_pitch;
		devinit.color_map = gfx_fb_color_map;
		devinit.mode = VIS_PIXEL;
		efi_console.c_private = &fb_ops;
	}

	modechg_cb(modechg_arg, &devinit);
}

static int
efi_fb_devinit(struct vis_devinit *data)
{
	if (console_mode != EfiConsoleControlScreenGraphics)
		return (1);

	data->version = VIS_CONS_REV;
	data->width = gfx_fb.framebuffer_common.framebuffer_width;
	data->height = gfx_fb.framebuffer_common.framebuffer_height;
	data->depth = gfx_fb.framebuffer_common.framebuffer_bpp;
	data->linebytes = gfx_fb.framebuffer_common.framebuffer_pitch;
	data->color_map = gfx_fb_color_map;
	data->mode = VIS_PIXEL;

	modechg_cb = data->modechg_cb;
	modechg_arg = data->modechg_arg;

	return (0);
}

static int
efi_text_devinit(struct vis_devinit *data)
{
	UINTN cols, rows;

	if (console_mode != EfiConsoleControlScreenText)
		return (1);

	(void)conout->QueryMode(conout, conout->Mode->Mode, &cols, &rows);
	data->version = VIS_CONS_REV;
	data->width = cols;
	data->height = rows;
	data->depth = 4;
	data->linebytes = cols;
	data->color_map = NULL;
	data->mode = VIS_TEXT;

	modechg_cb = data->modechg_cb;
	modechg_arg = data->modechg_arg;

	return (0);
}

static int
efi_text_cons_clear(struct vis_consclear *ca)
{
	EFI_STATUS st;
	UINTN attr = conout->Mode->Attribute & 0x0F;

	attr = EFI_TEXT_ATTR(attr,
	    solaris_color_to_efi_color[ca->bg_color & 0xF]);
	st = conout->SetAttribute(conout, attr);
	if (EFI_ERROR(st))
		return (1);
	st = conout->ClearScreen(conout);
	if (EFI_ERROR(st))
		return (1);
	return (0);
}

static void
efi_text_cons_copy(struct vis_conscopy *ma)
{
	UINTN col, row;

	col = 0;
	row = ma->e_row;
	conout->SetCursorPosition(conout, col, row);

	efi_cons_efiputchar('\n');
}

static void
efi_text_cons_display(struct vis_consdisplay *da)
{
	EFI_STATUS st;
	UINTN attr;
	UINTN row, col;
	tem_char_t *data;
	int i;

	(void)conout->QueryMode(conout, conout->Mode->Mode, &col, &row);

	/* reduce clear line on bottom row by one to prevent autoscroll */
	if (row - 1 == da->row && da->col == 0 && da->width == col)
		da->width--;

	data = (tem_char_t *)da->data;
	attr = EFI_TEXT_ATTR(solaris_color_to_efi_color[da->fg_color & 0xf],
	    solaris_color_to_efi_color[da->bg_color & 0xf]);
	st = conout->SetAttribute(conout, attr);
	if (EFI_ERROR(st))
		return;
	row = da->row;
	col = da->col;
	conout->SetCursorPosition(conout, col, row);
	for (i = 0; i < da->width; i++)
		efi_cons_efiputchar(data[i]);
}

static void efi_cons_cursor(struct vis_conscursor *cc)
{
	switch (cc->action) {
	case VIS_HIDE_CURSOR:
		if (plat_stdout_is_framebuffer())
			gfx_fb_display_cursor(cc);
		else
			plat_tem_hide_prom_cursor();
		break;
	case VIS_DISPLAY_CURSOR:
		if (plat_stdout_is_framebuffer())
			gfx_fb_display_cursor(cc);
		else {
			UINTN row, col;
			row = cc->row;
			col = cc->col;
			conout->SetCursorPosition(conout, col, row);
			conout->EnableCursor(conout, TRUE);
		}
		break;
	case VIS_GET_CURSOR: {	/* only used at startup */
		uint32_t row, col;

		plat_tem_get_prom_pos(&row, &col);
		cc->row = row;
		cc->col = col;
		}
		break;
	}
}

static int
efi_cons_ioctl(struct console *cp, int cmd, void *data)
{
	struct visual_ops *ops = cp->c_private;

	switch (cmd) {
	case VIS_GETIDENTIFIER:
		memmove(data, ops->ident, sizeof (struct vis_identifier));
		break;
	case VIS_DEVINIT:
		return (ops->devinit(data));
	case VIS_CONSCLEAR:
		return (ops->cons_clear(data));
	case VIS_CONSCOPY:
		ops->cons_copy(data);
		break;
	case VIS_CONSDISPLAY:
		ops->cons_display(data);
		break;
	case VIS_CONSCURSOR:
		ops->cons_cursor(data);
		break;
	default:
		return (EINVAL);
	}
	return (0);
}

static void
efi_framebuffer_setup(void)
{
	int bpp, pos;

	bpp = fls(efifb.fb_mask_red | efifb.fb_mask_green |
	    efifb.fb_mask_blue | efifb.fb_mask_reserved);

	gfx_fb.framebuffer_common.mb_type = MULTIBOOT_TAG_TYPE_FRAMEBUFFER;
	gfx_fb.framebuffer_common.mb_size = sizeof (gfx_fb);
	gfx_fb.framebuffer_common.framebuffer_addr = efifb.fb_addr;
	gfx_fb.framebuffer_common.framebuffer_width = efifb.fb_width;
	gfx_fb.framebuffer_common.framebuffer_height = efifb.fb_height;
	gfx_fb.framebuffer_common.framebuffer_bpp = bpp;
	gfx_fb.framebuffer_common.framebuffer_pitch =
	    efifb.fb_stride * (bpp >> 3);
	gfx_fb.framebuffer_common.framebuffer_type =
	    MULTIBOOT_FRAMEBUFFER_TYPE_RGB;
	gfx_fb.framebuffer_common.mb_reserved = 0;

	pos = ffs(efifb.fb_mask_red);
	if (pos != 0)
		pos--;
	gfx_fb.u.fb2.framebuffer_red_mask_size = fls(efifb.fb_mask_red >> pos);
	gfx_fb.u.fb2.framebuffer_red_field_position = pos;
	pos = ffs(efifb.fb_mask_green);
	if (pos != 0)
		pos--;
	gfx_fb.u.fb2.framebuffer_green_mask_size =
	    fls(efifb.fb_mask_green >> pos);
	gfx_fb.u.fb2.framebuffer_green_field_position = pos;
	pos = ffs(efifb.fb_mask_blue);
	if (pos != 0)
		pos--;
	gfx_fb.u.fb2.framebuffer_blue_mask_size =
	    fls(efifb.fb_mask_blue >> pos);
	gfx_fb.u.fb2.framebuffer_blue_field_position = pos;
}

static void
efi_cons_probe(struct console *cp)
{
	EFI_STATUS status;
	UINTN i, max_dim, best_mode, cols, rows;

	conout = ST->ConOut;
	conin = ST->ConIn;
	cp->c_flags |= C_PRESENTIN | C_PRESENTOUT;

	status = BS->LocateProtocol(&ccontrol_protocol_guid, NULL,
	    (VOID **)&console_control);
	if (status == EFI_SUCCESS) {
		BOOLEAN GopUgaExists, StdInLocked;
		status = console_control->GetMode(console_control,
		    &console_mode, &GopUgaExists, &StdInLocked);
	} else {
		console_mode = EfiConsoleControlScreenText;
	}

	max_dim = best_mode = 0;
	for (i = 0; i <= conout->Mode->MaxMode ; i++) {
		status = conout->QueryMode(conout, i, &cols, &rows);
		if (EFI_ERROR(status))
			continue;
		if (cols * rows > max_dim) {
			max_dim = cols * rows;
			best_mode = i;
		}
	}
	if (max_dim > 0)
		conout->SetMode(conout, best_mode);
	status = conout->QueryMode(conout, best_mode, &cols, &rows);
	if (EFI_ERROR(status)) {
		setenv("screen-#rows", "24", 1);
		setenv("screen-#cols", "80", 1);
	} else {
		char env[8];
		sprintf(env, "%u", (unsigned)rows);
		setenv("screen-#rows", env, 1);
		sprintf(env, "%u", (unsigned)cols);
		setenv("screen-#cols", env, 1);
	}

	if (efi_find_framebuffer(&efifb)) {
		console_mode = EfiConsoleControlScreenText;
		cp->c_private = &text_ops;
	} else {
		efi_framebuffer_setup();
		console_mode = EfiConsoleControlScreenGraphics;
		cp->c_private = &fb_ops;
	}

	if (console_control != NULL)
		(void)console_control->SetMode(console_control, console_mode);

	/* some firmware enables the cursor when switching modes */
	conout->EnableCursor(conout, FALSE);
}

static int
efi_cons_init(struct console *cp, int arg __unused)
{
	EFI_STATUS status;
	int rc;

	conout->SetAttribute(conout, EFI_TEXT_ATTR(DEFAULT_FGCOLOR,
	    DEFAULT_BGCOLOR));
	memset(keybuf, 0, KEYBUFSZ);
#if 0
	status = BS->OpenProtocol(ST->ConsoleInHandle, &simple_input_ex_guid,
	    (void**)&coninex, IH, NULL, EFI_OPEN_PROTOCOL_GET_PROTOCOL);
#endif
	coninex = NULL;

	gfx_framework_init(&fb_ops);
	rc = tem_info_init(cp);

	if (rc == 0 && tem == NULL) {
		tem = tem_init();
		if (tem != NULL)
			tem_activate(tem, B_TRUE);
	}

	if (tem == NULL)
		panic("Failed to set up console terminal");

	return 0;
}

static void
efi_cons_putchar(struct console *cp __unused, int c)
{
	uint8_t buf = c;

	/* make sure we have some console output, support for panic() */
	if (tem == NULL)
		efi_cons_efiputchar(c);
	else
		tem_write(tem, &buf, sizeof (buf));
}

static int
efi_cons_getchar(struct console *cp __unused)
{
	EFI_INPUT_KEY key, *kp;
	EFI_KEY_DATA  key_data;
	EFI_STATUS status;
	UINTN junk;
	int i, c;

	for (i = 0; i < KEYBUFSZ; i++) {
		if (keybuf[i] != 0) {
			c = keybuf[i];
			keybuf[i] = 0;
			return (c);
		}
	}

	if (coninex != NULL) {
		status = coninex->ReadKeyStrokeEx(coninex, &key_data);
		if (status == EFI_NOT_READY) {
			BS->WaitForEvent(1, &coninex->WaitForKeyEx, &junk);
			status = coninex->ReadKeyStrokeEx(coninex, &key_data);
		}
		kp = &key_data.Key;
	} else {
		status = conin->ReadKeyStroke(conin, &key);
		if (status == EFI_NOT_READY) {
			BS->WaitForEvent(1, &conin->WaitForKey, &junk);
			status = conin->ReadKeyStroke(conin, &key);
		}
		kp = &key;
	}

	if (status != EFI_SUCCESS) {
		return (-1);
	}

	switch (kp->ScanCode) {
	case 0x1: /* UP */
		keybuf[0] = '[';
		keybuf[1] = 'A';
		return (0x1b);  /* esc */
	case 0x2: /* DOWN */
		keybuf[0] = '[';
		keybuf[1] = 'B';
		return (0x1b);  /* esc */
	case 0x3: /* RIGHT */
		keybuf[0] = '[';
		keybuf[1] = 'C';
		return (0x1b);  /* esc */
	case 0x4: /* LEFT */
		keybuf[0] = '[';
		keybuf[1] = 'D';
		return (0x1b);  /* esc */
	case 0x17: /* ESC */
		return (0x1b);  /* esc */
	}

	/* this can return  */
	return (kp->UnicodeChar);
}

static int
efi_cons_poll(struct console *cp __unused)
{
	int i;

	for (i = 0; i < KEYBUFSZ; i++) {
		if (keybuf[i] != 0)
			return (1);
	}

	/* This can clear the signaled state. */
	if (coninex != NULL)
		return (BS->CheckEvent(coninex->WaitForKeyEx) == EFI_SUCCESS);
	else
		return (BS->CheckEvent(conin->WaitForKey) == EFI_SUCCESS);
}

/* Plain direct access to EFI OutputString(). */
void
efi_cons_efiputchar(int c)
{
	CHAR16 buf[2];
	EFI_STATUS status;

	buf[0] = c;
        buf[1] = 0;     /* terminate string */

	status = conout->TestString(conout, buf);
	if (EFI_ERROR(status))
		buf[0] = '?';
	conout->OutputString(conout, buf);
}
