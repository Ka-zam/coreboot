# LattePanda Mu Valkra Variant Build Guide

This guide covers building coreboot for the LattePanda Mu Valkra variant using Docker.

## Overview

The **Valkra variant** is an industrial data acquisition system configuration optimized for:
- **Platform**: LattePanda Mu with Intel Core i3-N305 (8-core, 15W)
- **Storage**: 2× NVMe Gen3 x2 drives (RAID 1) + eMMC boot
- **FPGA**: Kintex-7 with PCIe Gen3 x4 for 8-channel ADC at 225 MSPS
- **Network**: Gigabit Ethernet (Realtek RTL8111H)
- **USB**: 2× USB 2.0 only (JTAG + console)

## Prerequisites

### Required Software

1. **Docker** - Container runtime for coreboot SDK
   - Ubuntu/Debian: `sudo apt-get install docker.io`
   - Arch: `sudo pacman -S docker`
   - Fedora: `sudo dnf install docker`

2. **Git** - Version control (if not already installed)
   - Ubuntu/Debian: `sudo apt-get install git`
   - Arch: `sudo pacman -S git`
   - Fedora: `sudo dnf install git`

3. **Add yourself to docker group** (to run Docker without sudo):
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in for group membership to take effect
   ```

### Optional: QEMU for Testing

To test the built ROM in emulation:
- Ubuntu/Debian: `sudo apt-get install qemu-system-x86`
- Arch: `sudo pacman -S qemu`
- Fedora: `sudo dnf install qemu-system-x86`

## Build Methods

There are two recommended methods to build coreboot using Docker:

### Method 1: Interactive Docker Shell (Recommended for First Build)

This method gives you a shell inside the coreboot SDK container where you can run multiple commands.

```bash
# From the coreboot root directory
cd /home/magnus/src/kazam/coreboot

# Start an interactive shell in the SDK container
make -C util/docker docker-shell
```

Inside the Docker container:

```bash
# Configure for LattePanda Mu Valkra variant
make menuconfig
```

In menuconfig:
1. Navigate to **Mainboard** menu
2. Select **Mainboard vendor** → Choose `LattePanda`
3. Select **Mainboard model** → Choose `Mu`
4. Navigate to **Mainboard** menu again
5. Select **Board variant** → Choose `Valkra`
6. Exit and save configuration

```bash
# Build coreboot (use all CPU cores)
make -j$(nproc)

# ROM will be created at: build/coreboot.rom
```

To exit the Docker shell: `exit`

### Method 2: One-Shot Docker Build

This method builds without entering the container shell:

```bash
# From the coreboot root directory
cd /home/magnus/src/kazam/coreboot

# Configure the build first (interactive)
make -C util/docker docker-shell
# Inside container: run menuconfig and select Valkra variant, then exit

# Build with Docker in one command
make -C util/docker docker-build-coreboot BUILD_CMD="-j$(nproc)"
```

## Configuration Details

### What `make menuconfig` Should Show

After selecting the Valkra variant, your configuration should have:

**Mainboard:**
- Vendor: `LattePanda`
- Model: `Mu`
- Variant: `Valkra`

**Key Differences from Base `mu` Variant:**
- **RP1 enabled**: NVMe Drive 1 (PCIe Gen3 x2)
- **RP3 enabled**: NVMe Drive 2 (PCIe Gen3 x2)
- **RP4 disabled**: No WiFi module (industrial deployment)
- **RP9 enabled**: FPGA (PCIe Gen3 x4)
- **USB 3.x disabled**: Frees HSIO lanes for PCIe
- **USB 2.0 enabled**: 2 ports for JTAG + console

### Saving Your Configuration (Optional)

To save a minimal defconfig:

```bash
make savedefconfig
cat defconfig
```

You can check this into git or use it to restore your configuration later:

```bash
# Restore from defconfig
cp defconfig .config
make olddefconfig
```

## Build Outputs

After a successful build, you'll find:

```
build/
├── coreboot.rom          # Main ROM image (flash this)
├── coreboot.rom.elf      # ELF format ROM
└── coreboot.config       # Full build configuration
```

**ROM Size**: Approximately 16 MB (depends on payload)

## Testing with QEMU

**⚠️ WARNING**: You cannot directly test the Valkra build in QEMU because:
1. QEMU doesn't emulate Intel Alder Lake-N hardware
2. The Valkra configuration is hardware-specific
3. PCIe bifurcation settings are board-specific

However, you can verify the ROM structure:

```bash
# Extract and view CBFS (Coreboot File System) contents
./build/cbfstool build/coreboot.rom print
```

This will show you all the components packed into the ROM.

## Flashing the ROM

**⚠️ CRITICAL BEFORE FLASHING**: You MUST configure Flash Descriptor bifurcation soft straps before first boot!

### Flash Descriptor Soft Strap Requirements

The Valkra variant requires specific PCIe bifurcation modes that cannot be set via coreboot devicetree. These are configured in the Intel Flash Descriptor:

**Required Bifurcation Settings:**
- **Controller 1** (HSIO 0-3): `2x2` mode
  - RP1 gets lanes 0-1 (x2 for NVMe Drive 1)
  - RP3 gets lanes 2-3 (x2 for NVMe Drive 2)
- **Controller 3** (HSIO 8-11): `1x4` mode
  - RP9 gets lanes 8-11 (x4 for FPGA)

**Without correct bifurcation settings, your PCIe devices will NOT enumerate!**

### Configure Bifurcation with ifdtool

```bash
# Build ifdtool
cd util/ifdtool
make

# Examine your current flash descriptor
./ifdtool -d /path/to/your/current_flash.bin

# Look for soft strap settings related to PCIe bifurcation
# The exact bit positions are platform-specific (see ADL-N datasheet)
```

**Note**: Currently, ifdtool does not have built-in support for modifying ADL-N bifurcation soft straps. You have two options:

1. **Use Intel Flash Image Tool (FIT)** - Official Intel tool (Windows only)
   - Download from Intel: https://www.intel.com/content/www/us/en/download/
   - Load your coreboot.rom
   - Navigate to PCH Soft Straps
   - Configure Controller 1 = "2x2", Controller 3 = "1x4"
   - Save and export modified ROM

2. **Work with LattePanda** - Contact LattePanda to provide a flash descriptor with correct bifurcation settings for your Valkra carrier board design

### Flash Commands

**⚠️ WARNING**: Flashing incorrect firmware can brick your device!

**Using flashrom (Linux):**
```bash
# Install flashrom
sudo apt-get install flashrom  # Debian/Ubuntu
sudo pacman -S flashrom        # Arch
sudo dnf install flashrom      # Fedora

# Identify your flash chip
sudo flashrom -p internal

# Backup your current firmware FIRST!
sudo flashrom -p internal -r backup_$(date +%Y%m%d).rom

# Flash the new ROM (only after configuring bifurcation!)
sudo flashrom -p internal -w build/coreboot.rom
```

**Using external programmer (recommended for first flash):**
- CH341A USB programmer
- Dediprog SF100/SF600
- Bus Pirate

Refer to LattePanda documentation for SPI flash chip location and pinout.

## Troubleshooting

### Docker Permission Denied

```bash
# Error: permission denied while trying to connect to Docker daemon
sudo usermod -aG docker $USER
# Log out and back in
```

### ccache Directory Errors

```bash
# Create ccache directory if it doesn't exist
mkdir -p ~/.ccache
```

### PCIe Devices Not Detected After Flash

**Cause**: Bifurcation soft straps not configured correctly in flash descriptor.

**Solution**:
1. Verify flash descriptor soft straps with `ifdtool -d`
2. Use Intel FIT to configure bifurcation correctly
3. Reflash with corrected descriptor

### Build Fails with "blobs" Error

Some platforms require proprietary blobs (FSP, microcode, etc.). Enable in menuconfig:
```
General Setup → Allow use of binary-only repository
```

Then download blobs:
```bash
git submodule update --init --checkout 3rdparty/blobs
```

### NVMe Drives Not Detected

**Possible causes:**
1. Flash descriptor bifurcation incorrect (Controller 1 must be "2x2")
2. NVMe drives not properly seated in M.2 connectors
3. Reference clocks not provided (check carrier board design)

**Debug steps:**
1. Enable coreboot debug output in menuconfig: `Console → Debug level → Debug`
2. Check serial console output for PCIe enumeration messages
3. Look for "RP1" and "RP3" initialization messages

### FPGA Not Detected

**Possible causes:**
1. Flash descriptor bifurcation incorrect (Controller 3 must be "1x4")
2. FPGA not configured/powered correctly
3. Detection timeout too short (increase `PcieRpDetectTimeoutMs` in overridetree.cb)

**Debug steps:**
1. Verify FPGA configuration bitstream loads correctly
2. Check FPGA PCIe hard IP is configured for Gen3 x4
3. Monitor PERST# signal timing on carrier board
4. Increase timeout: edit `variants/valkra/overridetree.cb`, change `PcieRpDetectTimeoutMs = 100` to `500`

## Verification After Flashing

After successfully flashing and booting:

```bash
# Check PCIe devices enumerated by coreboot
dmesg | grep -i pcie

# List all PCIe devices
lspci -tv

# Expected devices:
# 00:1c.0 - RP1 - NVMe Drive 1
# 00:1c.2 - RP3 - NVMe Drive 2
# 00:1c.6 - RP7 - RTL8111H Ethernet
# 00:1d.0 - RP9 - FPGA (Kintex-7)

# Verify NVMe drives
lsblk | grep nvme
# Expected: /dev/nvme0n1 and /dev/nvme1n1

# Check FPGA PCIe link status
sudo lspci -vv -s $(lspci | grep FPGA | cut -d' ' -f1) | grep LnkSta
# Expected: "Speed 8GT/s (ok), Width x4 (ok)"
```

## Setting Up RAID 1 for Data Acquisition

The Valkra variant is designed for redundant storage using 2× NVMe drives:

```bash
# Install mdadm
sudo apt-get install mdadm

# Create RAID 1 array
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1

# Format with ext4
sudo mkfs.ext4 /dev/md0

# Mount
sudo mkdir /mnt/data
sudo mount /dev/md0 /mnt/data

# Make persistent (add to /etc/fstab)
echo '/dev/md0 /mnt/data ext4 defaults 0 2' | sudo tee -a /etc/fstab

# Save RAID configuration
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf
sudo update-initramfs -u
```

**Performance**: RAID 1 provides ~1.8 GB/s write bandwidth, sufficient for ~112 MSPS continuous recording from 8-channel 16-bit ADC. For higher rates, use burst recording to RAM.

## Performance Tuning

### Enable ASPM for Power Savings

The Valkra configuration enables ASPM on NVMe drives for power savings. If you need maximum performance at all times:

Edit `variants/valkra/overridetree.cb`:
```c
register "pch_pcie_rp[PCH_RP(1)]" = "{
    .pcie_rp_aspm = ASPM_DISABLE,  // Change from ASPM_L0S_L1
    .PcieRpL1Substates = L1_SS_DISABLED,  // Change from L1_SS_L1_2
}"
```

Rebuild and reflash.

### Verify FPGA Link Training

Check that FPGA negotiates Gen3 x4:
```bash
sudo lspci -vv -s $(lspci | grep FPGA | cut -d' ' -f1) | grep -E "LnkCap|LnkSta"
```

Expected output:
```
LnkCap: Port #0, Speed 8GT/s, Width x4, ...
LnkSta: Speed 8GT/s (ok), Width x4 (ok)
```

If negotiating lower speed/width:
1. Check FPGA PCIe IP configuration
2. Verify differential pair routing on carrier board (85Ω impedance)
3. Check reference clock quality (100 MHz, < 100 ppm)

## Additional Resources

- **LattePanda Mu Documentation**: https://docs.lattepanda.com/
- **coreboot Documentation**: https://doc.coreboot.org/
- **Intel ADL-N Datasheet**: `/home/magnus/src/kazam/coreboot/doc/759603-002.md`
- **HSIO Configuration Guide**: `HSIO_MAPPING.md` (this directory)
- **PCIe Configuration Guide**: `PCIE_CONFIGURATION_GUIDE.md` (this directory)
- **Valkra Configuration**: `variants/valkra/overridetree.cb`

## Quick Reference Commands

```bash
# Build with Docker (interactive)
cd /home/magnus/src/kazam/coreboot
make -C util/docker docker-shell
# Inside: make menuconfig, select Valkra, then make -j$(nproc)

# Build with Docker (one-shot)
make -C util/docker docker-build-coreboot BUILD_CMD="-j$(nproc)"

# Check ROM contents
./build/cbfstool build/coreboot.rom print

# Flash ROM (BACKUP FIRST!)
sudo flashrom -p internal -r backup.rom
sudo flashrom -p internal -w build/coreboot.rom

# Verify PCIe devices after boot
lspci -tv
dmesg | grep -i pcie
```

## Support

For issues specific to:
- **LattePanda Mu hardware**: https://discord.gg/lattepanda
- **coreboot build system**: https://coreboot.org/support.html
- **Intel Alder Lake-N**: Intel product documentation

## License

This build guide is licensed under GPL-2.0-only, consistent with the coreboot project.
