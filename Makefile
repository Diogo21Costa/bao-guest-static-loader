
ifeq ($(and $(IMAGE), $(DTB), $(TARGET), $(ARCH)),)
ifneq ($(MAKECMDGOALS), clean)
 $(error Linux image (IMAGE) and/or device tree (DTB) and/or target name \
 	(TARGET) and/or architecture (ARCH) not specified)
endif
endif

ARCH=aarch64
ifeq ($(ARCH), aarch64)
CROSS_COMPILE?=aarch64-none-elf-
OPTIONS=-mcmodel=large 
else ifeq ($(ARCH), aarch32)
CROSS_COMPILE?=arm-none-eabi-
OPTIONS=-march=armv7-a
else ifeq ($(ARCH), riscv)
CROSS_COMPILE?=riscv64-unknown-elf-
OPTIONS=-mcmodel=medany
else
$(error unkown architecture $(ARCH))
endif

MODIFIED_DTB=modified.dtb

ifeq ($(INITRAMFS),)
    TARGET_DTB=$(DTB)
else
    TARGET_DTB=$(MODIFIED_DTB)
endif


all: $(TARGET).bin

clean:
	-rm *.elf *.bin $(MODIFIED_DTB)

.PHONY: all clean
	
$(TARGET).bin: $(TARGET).elf
	$(CROSS_COMPILE)objcopy -S -O binary $(TARGET).elf $(TARGET).bin

$(TARGET).elf: $(ARCH).S $(IMAGE) $(TARGET_DTB) loader_$(ARCH).ld 
	$(CROSS_COMPILE)gcc -Wl,-build-id=none -nostdlib -T loader_$(ARCH).ld \
		-o $(TARGET).elf $(OPTIONS) $(ARCH).S -I. -D IMAGE=$(IMAGE) -D DTB=$(TARGET_DTB) \
		$(if $(INITRAMFS),-D INITRAMFS=$(INITRAMFS))

# Rule for modifying DTB if INITRAMFS is not empty
ifeq ($(INITRAMFS),)
    $(info INITRAMFS is empty, skipping DTB modification)
else
    $(MODIFIED_DTB): $(DTB)
	@if [ -z "${INITRD_START}" ]; then \
		echo "INITRD_START is not defined"; \
		exit 1; \
	fi
	@echo "Modifying DTB with initrd details..."
	INITRAMFS_SIZE=$$(stat -c%s $(INITRAMFS)); \
	INITRD_END=$$(printf "0x%08x" $$(($$INITRD_START + $$INITRAMFS_SIZE)));\
	dtc -I dtb -O dts $(DTB) > linux.dts; \
	sed -i '/bootargs/ s/\(bootargs *= *"[^"]*\)\("\)/\1 root=\/dev\/ram0\2/' linux.dts; \
	sed -i "/bootargs/a \\\t\tlinux,initrd-start = <$$INITRD_START>;\n\t\tlinux,initrd-end = <$$INITRD_END>;" linux.dts; \
	dtc -I dts -O dtb linux.dts > $(MODIFIED_DTB);
endif
