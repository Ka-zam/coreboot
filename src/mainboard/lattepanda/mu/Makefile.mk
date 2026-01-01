## SPDX-License-Identifier: GPL-2.0-only

VARIANT_DIR:=$(call strip_quotes,$(CONFIG_VARIANT_DIR))

subdirs-y += spd

bootblock-y += bootblock.c
bootblock-y += variants/$(VARIANT_DIR)/early_gpio.c

romstage-y += romstage_fsp_params.c
romstage-y += variants/$(VARIANT_DIR)/memory.c

ramstage-y += mainboard.c
ramstage-y += variants/$(VARIANT_DIR)/gpio.c
ramstage-y += ramstage.c

smm-y += smihandler.c

CPPFLAGS_common += -I$(src)/mainboard/$(MAINBOARDDIR)/include
