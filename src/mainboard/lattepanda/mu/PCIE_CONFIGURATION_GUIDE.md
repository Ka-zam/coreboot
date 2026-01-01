# PCIe Configuration Guide for LattePanda Mu Variants

This guide explains how to configure PCIe lanes for your LattePanda Mu carrier board using the variant system.

## Quick Start

1. Select your variant during configuration:
   ```bash
   make menuconfig
   # Navigate to: Mainboard → Mainboard vendor → LattePanda
   # Select either "Mu (LattePanda Lite Carrier)" or "Valkra (Custom Carrier Board)"
   ```

2. Edit your variant's `overridetree.cb` file to enable/disable PCIe ports

3. Build coreboot:
   ```bash
   make -j$(nproc)
   ```

## Variant System Overview

The LattePanda Mu uses a variant system to support different carrier boards:

- **Base configuration** (`devicetree.cb`): Common settings shared by all variants
- **Variant overrides** (`variants/[variant]/overridetree.cb`): Variant-specific PCIe and device configuration
- **Variant code** (`variants/[variant]/*.c`): Variant-specific GPIO, memory, etc.

## Available Variants

### Mu (Default)
Official LattePanda Lite carrier board configuration:
- RP3: M.2 M-key 2230 (SSD)
- RP4: M.2 E-key 2230 (WiFi)
- RP7: Realtek RTL8111H Gigabit Ethernet (onboard)

**Location:** `variants/mu/overridetree.cb`

### Valkra (Custom)
Custom carrier board with additional PCIe ports enabled:
- RP1: PCIe Slot 1
- RP2: PCIe Slot 2
- RP3: M.2 M-key 2230 (SSD) - inherited from base
- RP4: M.2 E-key 2230 (WiFi) - inherited from base
- RP5: PCIe Slot 3
- RP6: PCIe Slot 4
- RP7: Ethernet - inherited from base

**Location:** `variants/valkra/overridetree.cb`

## Creating a New Variant

To create a new variant for your carrier board:

### 1. Create Variant Directory

```bash
cd src/mainboard/lattepanda/mu
mkdir -p variants/myboard
```

### 2. Copy Base Files

```bash
cp variants/mu/gpio.c variants/myboard/
cp variants/mu/early_gpio.c variants/myboard/
cp variants/mu/memory.c variants/myboard/
```

### 3. Create overridetree.cb

Create `variants/myboard/overridetree.cb` with your PCIe configuration (see examples below).

### 4. Update Kconfig Files

**Edit `Kconfig.name`:**
```kconfig
config BOARD_LATTEPANDA_MYBOARD
	bool "MyBoard (My Custom Carrier)"
	help
	  LattePanda Mu with my custom carrier board.
```

**Edit `Kconfig`:**
```kconfig
config VARIANT_DIR
	default "mu" if BOARD_LATTEPANDA_MU
	default "valkra" if BOARD_LATTEPANDA_VALKRA
	default "myboard" if BOARD_LATTEPANDA_MYBOARD  # Add this line

config MAINBOARD_PART_NUMBER
	default "Mu_8G" if BOARD_LATTEPANDA_MU
	default "Valkra" if BOARD_LATTEPANDA_VALKRA
	default "MyBoard" if BOARD_LATTEPANDA_MYBOARD  # Add this line
```

## PCIe Configuration Examples

### Example 1: Enable a Single PCIe Port

```c
chip soc/intel/alderlake
	device domain 0 on
		device ref pcie_rp1 on
			register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
			register "pch_pcie_rp[PCH_RP(1)]" = "{
				.flags = PCIE_RP_LTR | PCIE_RP_AER | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
				.pcie_rp_aspm = ASPM_DISABLE,
				.PcieRpL1Substates = L1_SS_DISABLED,
			}"
			smbios_slot_desc	"SlotTypePciExpressMini52pinWithoutBSKO" "SlotLengthOther"
						"PCIe x1 Slot" "SlotDataBusWidth1X"
		end
	end
end
```

### Example 2: Built-in Device (Not a Slot)

For a soldered-down PCIe device (e.g., another Ethernet controller):

```c
device ref pcie_rp1 on
	register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
	register "pch_pcie_rp[PCH_RP(1)]" = "{
		.flags = PCIE_RP_LTR | PCIE_RP_AER | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED | PCIE_RP_BUILT_IN,
		.pcie_rp_aspm = ASPM_DISABLE,
		.PcieRpL1Substates = L1_SS_DISABLED,
	}"
	chip drivers/net
		register "device_index" = "1"
		register "add_acpi_dma_property" = "true"
		device pci 00.0 on end
	end
end
```

### Example 3: Dynamic Clock with CLKREQ#

For power-efficient designs using clock request signaling:

```c
device ref pcie_rp1 on
	# Use REFCLK1 and CLKREQ1#
	register "pch_pcie_rp[PCH_RP(1)]" = "{
		.clk_src = 1,  # REFCLK1
		.clk_req = 1,  # CLKREQ1#
		.flags = PCIE_RP_LTR | PCIE_RP_AER,
		.pcie_rp_aspm = ASPM_DISABLE,
		.PcieRpL1Substates = L1_SS_DISABLED,
	}"
	smbios_slot_desc	"SlotTypePciExpressMini52pinWithoutBSKO" "SlotLengthOther"
					"PCIe x1 Slot" "SlotDataBusWidth1X"
end
```

**Note:** When using dynamic clocking:
- Wire the PCIe reference clock from SODIMM pins to your device
- Wire the CLKREQ# signal back to the SODIMM connector
- Check `HSIO_MAPPING.md` for available REFCLK and CLKREQ# signals

### Example 4: Enable ASPM Power Management

For devices that support Active State Power Management:

```c
device ref pcie_rp1 on
	register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
	register "pch_pcie_rp[PCH_RP(1)]" = "{
		.flags = PCIE_RP_LTR | PCIE_RP_AER | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
		.pcie_rp_aspm = ASPM_L0S_L1,  # Enable L0s and L1 states
		.PcieRpL1Substates = L1_SS_L1_2,  # Enable L1.2 substates
	}"
	smbios_slot_desc	"SlotTypePciExpressMini52pinWithoutBSKO" "SlotLengthOther"
					"PCIe x1 Slot" "SlotDataBusWidth1X"
end
```

**ASPM Options:**
- `ASPM_DISABLE` - No power management (maximum compatibility)
- `ASPM_L0S` - L0s state only
- `ASPM_L1` - L1 state only
- `ASPM_L0S_L1` - Both L0s and L1 states
- `ASPM_L0S_L1_1` - L0s, L1, and L1.1
- `ASPM_L0S_L1_2` - L0s, L1, and L1.2

**L1 Substate Options:**
- `L1_SS_DISABLED` - No L1 substates
- `L1_SS_L1_1` - L1.1 only
- `L1_SS_L1_2` - L1.2 only (recommended)
- `L1_SS_L1_1_L1_2` - Both L1.1 and L1.2

### Example 5: Hotplug-Capable Slot

For slots that support hot-plugging devices:

```c
device ref pcie_rp1 on
	register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
	register "pch_pcie_rp[PCH_RP(1)]" = "{
		.flags = PCIE_RP_LTR | PCIE_RP_AER | PCIE_RP_HOTPLUG | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
		.pcie_rp_aspm = ASPM_DISABLE,
		.PcieRpL1Substates = L1_SS_DISABLED,
	}"
	smbios_slot_desc	"SlotTypePciExpressMini52pinWithoutBSKO" "SlotLengthOther"
					"Hot-Plug PCIe x1" "SlotDataBusWidth1X"
end
```

### Example 6: M.2 NVMe Slot

For adding an additional M.2 NVMe slot:

```c
device ref pcie_rp1 on
	register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
	register "pch_pcie_rp[PCH_RP(1)]" = "{
		.flags = PCIE_RP_LTR | PCIE_RP_AER | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
		.pcie_rp_aspm = ASPM_DISABLE,
		.PcieRpL1Substates = L1_SS_DISABLED,
	}"
	smbios_slot_desc	"SlotTypeM2Socket3" "SlotLengthOther"
					"M.2 NVMe (2280)" "SlotDataBusWidth4X"
	chip drivers/storage
		register "media_type" = "STORAGE_MEDIA_NVME"
		device pci 00.0 on end
	end
end
```

## Available PCIe Root Ports

| Port | PCI Address | Status in Base | Available | Notes |
|------|-------------|----------------|-----------|-------|
| RP1  | 0:1c.0      | Off            | ✓ Yes     | General purpose |
| RP2  | 0:1c.1      | Off            | ✓ Yes     | General purpose |
| RP3  | 0:1c.2      | On             | In use    | M.2 SSD (base config) |
| RP4  | 0:1c.3      | On             | In use    | M.2 WiFi (base config) |
| RP5  | 0:1c.4      | Off            | ✓ Yes     | General purpose |
| RP6  | 0:1c.5      | Off            | ✓ Yes     | General purpose |
| RP7  | 0:1c.6      | On             | In use    | GbE NIC (base config) |
| RP8  | 0:1c.7      | Off            | ✓ Yes     | General purpose |
| RP9  | 0:1d.0      | Off            | ✓ Yes     | General purpose |
| RP10 | 0:1d.1      | Off            | ✓ Yes     | General purpose |
| RP11 | 0:1d.2      | Off            | ✓ Yes     | General purpose |
| RP12 | 0:1d.3      | Off            | ✓ Yes     | General purpose |

**Total:** 12 PCIe root ports, 3 used in base configuration, 9 available

## Clock Configuration

### Available Reference Clocks

| Clock   | SODIMM Pins | Status in Base | Notes |
|---------|-------------|----------------|-------|
| REFCLK0 | 85, 87      | Used (RP3)     | M.2 SSD |
| REFCLK1 | 91, 93      | Available      | Free-running capable |
| REFCLK2 | 97, 99      | Available      | Free-running capable |
| REFCLK3 | 88, 90      | Used (RP4)     | M.2 WiFi |
| REFCLK4 | 94, 96      | Used (RP7)     | GbE NIC |

### Clock Request Signals

| Signal         | Pin | GPIO    | Associated Clock |
|----------------|-----|---------|------------------|
| PCIECLK_REQ3#  | 100 | GPP_D8  | REFCLK3 |
| PCIECLK_REQ4#  | 102 | GPP_H19 | REFCLK4 |

**Note:** The base configuration uses free-running clocks (always on) for maximum compatibility. If your design supports clock request signaling for power savings, you can configure dynamic clocking as shown in Example 3.

## SMBIOS Slot Types

Common slot type identifiers for `smbios_slot_desc`:

- `SlotTypePciExpressMini52pinWithoutBSKO` - Mini PCIe (52-pin)
- `SlotTypePciExpressMini76pinWithoutBSKO` - Mini PCIe (76-pin)
- `SlotTypeM2Socket3` - M.2 Socket 3 (M-key, PCIe x4)
- `SlotTypeM2Socket2` - M.2 Socket 2 (B-key, PCIe x2)
- `SlotTypeM2Socket1_SD` - M.2 Socket 1 (E-key, PCIe x1)
- `SlotTypePciExpressGen3X16` - Standard PCIe x16 slot
- `SlotTypePciExpressGen3X8` - Standard PCIe x8 slot
- `SlotTypePciExpressGen3X4` - Standard PCIe x4 slot
- `SlotTypePciExpressGen3X2` - Standard PCIe x2 slot
- `SlotTypePciExpressGen3X1` - Standard PCIe x1 slot

**Slot Data Bus Width:**
- `SlotDataBusWidth1X` - x1 lane
- `SlotDataBusWidth2X` - x2 lanes
- `SlotDataBusWidth4X` - x4 lanes
- `SlotDataBusWidth8X` - x8 lanes
- `SlotDataBusWidth16X` - x16 lanes

## Configuration Flags Reference

### Common Flags

```c
.flags = PCIE_RP_LTR | PCIE_RP_AER | ...
```

**Flag Options:**
- `PCIE_RP_LTR` - Enable Latency Tolerance Reporting (recommended)
- `PCIE_RP_AER` - Enable Advanced Error Reporting (recommended)
- `PCIE_RP_HOTPLUG` - Mark slot as hotplug-capable
- `PCIE_RP_BUILT_IN` - Mark as built-in device (not a slot)
- `PCIE_RP_CLK_SRC_UNUSED` - No clock source assignment
- `PCIE_RP_CLK_REQ_UNUSED` - No clock request signal

### Clock Source Configuration

**Free-Running Clock (Always On):**
```c
register "pcie_clk_config_flag[X]" = "PCIE_CLK_FREE_RUNNING"
register "pch_pcie_rp[PCH_RP(Y)]" = "{
	.flags = ... | PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
	...
}"
```

**Dynamic Clock (Power Efficient):**
```c
register "pch_pcie_rp[PCH_RP(Y)]" = "{
	.clk_src = X,  // 0-4 for REFCLK0-4
	.clk_req = X,  // Clock request signal index
	.flags = PCIE_RP_LTR | PCIE_RP_AER,  // No CLK_SRC_UNUSED/CLK_REQ_UNUSED
	...
}"
```

## Testing and Validation

### 1. Build and Flash

```bash
make menuconfig  # Select your variant
make -j$(nproc)
# Flash build/coreboot.rom to your board
```

### 2. Verify PCIe Detection

Boot into Linux and check PCIe devices:

```bash
# List all PCIe devices
lspci -tv

# Check specific root port
lspci -vv -s 00:1c.0  # For RP1

# Check PCIe link speed and width
lspci -vv | grep -i 'lnksta\|lnkcap'
```

### 3. Check Power Management

```bash
# Check ASPM status
lspci -vv | grep -i aspm

# Check L1 substates
lspci -vvv | grep -i 'l1subctl'
```

### 4. Monitor System Logs

```bash
# Check for PCIe errors
dmesg | grep -i pci
dmesg | grep -i 'aer\|corrected\|uncorrected'
```

## Troubleshooting

### Device Not Detected

1. **Verify hardware connections** - Check that device is properly seated
2. **Check power** - Ensure device receives adequate power
3. **Try free-running clock** - Some devices don't support dynamic clocking
4. **Disable ASPM** - Try with `ASPM_DISABLE` first
5. **Check device compatibility** - Ensure device supports PCIe (not just USB)

### PCIe Link Training Failures

```
# Symptoms in dmesg:
pcieport 0000:00:1c.0: PCIe Bus Error: ...
pcieport 0000:00:1c.0: AER: Corrected error received
```

**Solutions:**
- Increase detection timeout (add to overridetree):
  ```c
  register "pch_pcie_rp[PCH_RP(X)]" = "{
      ...
      .PcieRpDetectTimeoutMs = 100,  # Default is 50ms
  }"
  ```
- Try disabling LTR if device doesn't support it:
  ```c
  .flags = PCIE_RP_AER | ...,  # Remove PCIE_RP_LTR
  ```

### Build Errors

**Error: "devicetree.cb: chip 'soc/intel/alderlake' has already been opened"**
- Don't repeat `chip soc/intel/alderlake` in overridetree.cb - it's automatically merged

**Error: "Device 'pcie_rp1' not found"**
- Check that you're using the correct device reference name from chipset.cb

### ASPM Doesn't Work

Some devices require specific ASPM configuration:
- Try different ASPM levels (`L0S`, `L1`, `L0S_L1`)
- Check if device firmware supports ASPM
- Some devices need L1 substates disabled even with ASPM enabled

## Best Practices

1. **Start Simple** - Begin with free-running clocks and ASPM disabled
2. **Enable One Port at a Time** - Test each port individually
3. **Document Your Config** - Add comments explaining your carrier board design
4. **Match Hardware** - Ensure SMBIOS slot descriptions match physical implementation
5. **Consider Power** - Use dynamic clocking and ASPM once basic functionality works
6. **Test Thoroughly** - Verify under different loads and power states

## Additional Resources

- `HSIO_MAPPING.md` - Detailed HSIO lane and pinout information
- `README.md` (doc/) - Hardware pinout documentation
- Intel Alder Lake-N Datasheet - Official silicon documentation
- coreboot devicetree documentation - https://doc.coreboot.org/
- PCIe Base Specification - PCI-SIG specifications

## Example: Complete Valkra Configuration

See `variants/valkra/overridetree.cb` for a complete working example that enables 4 additional PCIe ports (RP1, RP2, RP5, RP6) beyond the base configuration.

## Advanced Configuration: Multi-Endpoint FPGA with RAID Storage

The Valkra variant demonstrates an advanced configuration for high-speed data acquisition systems using an FPGA with multiple PCIe endpoints and RAID storage.

### Use Case: Kintex-7 FPGA with 8-Channel ADC

**System Architecture:**
- **FPGA:** Kintex-7 with 4 independent PCIe Gen2/Gen3 endpoints
- **ADC:** 8 channels × 16-bit resolution
- **Storage:** 4× NVMe drives in RAID array
- **Data Flow:** FPGA → 4× PCIe links → CPU → RAID array

### PCIe Gen3 vs Gen2 Performance

| Link Type | Per Link BW | 4× Links Total | Max Sample Rate (8ch×16bit) | Per Channel |
|-----------|-------------|----------------|----------------------------|-------------|
| Gen2 x1   | 400 MB/s    | 1.6 GB/s       | 100 MSPS                   | 12.5 MSPS   |
| Gen3 x1   | 900 MB/s    | 3.6 GB/s       | 225 MSPS                   | 28 MSPS     |

**Gen3 Advantages:**
- 2.25× bandwidth improvement per link
- More headroom for bursts and protocol overhead
- Future-proofing for higher sample rates

**Gen3 Considerations:**
- Requires Gen3-capable soft IP in FPGA (available for Kintex-7)
- More FPGA fabric resources (~10-15% vs ~2-3% for Gen2)
- Higher power consumption (~1-1.5W per lane vs ~0.5W for Gen2)
- Tighter signal integrity requirements on PCB

### Multi-Endpoint FPGA Configuration

The Valkra variant uses 4 independent PCIe endpoints to maximize bandwidth on the x1-only PCH ports.

**Endpoint Allocation:**
```
RP1 (Endpoint 0) → ADC Channels 0, 1
RP2 (Endpoint 1) → ADC Channels 2, 3
RP5 (Endpoint 2) → ADC Channels 4, 5
RP6 (Endpoint 3) → ADC Channels 6, 7
```

**Key Configuration Parameters:**

```c
# From variants/valkra/overridetree.cb

device ref pcie_rp1 on
    register "pcie_clk_config_flag[1]" = "PCIE_CLK_FREE_RUNNING"
    register "pch_pcie_rp[PCH_RP(1)]" = "{
        .flags = PCIE_RP_LTR | PCIE_RP_AER | 
                 PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED | 
                 PCIE_RP_BUILT_IN,
        .pcie_rp_aspm = ASPM_DISABLE,
        .PcieRpL1Substates = L1_SS_DISABLED,
        .PcieRpDetectTimeoutMs = 100,  # Longer timeout for FPGA init
    }"
end
```

**Important Notes:**
- `PCIE_RP_BUILT_IN` flag marks as onboard device (not hot-pluggable)
- `PcieRpDetectTimeoutMs = 100` gives FPGA extra time to initialize
- ASPM disabled for maximum throughput
- Free-running clocks for simplicity (no CLKREQ# signals needed)

### Software Architecture for Multi-Endpoint Data Reassembly

Since each FPGA endpoint operates independently, host software must reassemble the data streams.

**Data Packet Structure (Example):**
```c
struct fpga_adc_packet {
    uint64_t timestamp;      // Nanosecond timestamp from FPGA
    uint32_t sequence_num;   // Monotonic sequence counter
    uint8_t  endpoint_id;    // 0-3
    uint8_t  reserved[3];
    uint16_t samples[2][SAMPLES_PER_PKT];  // 2 channels per endpoint
} __attribute__((packed));
```

**Kernel Driver Architecture:**
```
┌──────────────────────────────────────────┐
│  /dev/fpga_pcie0  (RP1 - Channels 0,1)  │◄── DMA Ring Buffer
├──────────────────────────────────────────┤
│  /dev/fpga_pcie1  (RP2 - Channels 2,3)  │◄── DMA Ring Buffer
├──────────────────────────────────────────┤
│  /dev/fpga_pcie2  (RP5 - Channels 4,5)  │◄── DMA Ring Buffer
├──────────────────────────────────────────┤
│  /dev/fpga_pcie3  (RP6 - Channels 6,7)  │◄── DMA Ring Buffer
└──────────────────────────────────────────┘
```

**Userspace Reassembly (Pseudo-code):**
```c
// 4 reader threads, one per endpoint
void* endpoint_reader_thread(void* arg) {
    int ep_id = *(int*)arg;
    char dev[32];
    snprintf(dev, sizeof(dev), "/dev/fpga_pcie%d", ep_id);
    
    int fd = open(dev, O_RDONLY);
    
    while (running) {
        struct fpga_adc_packet pkt;
        ssize_t n = read(fd, &pkt, sizeof(pkt));
        
        if (n == sizeof(pkt)) {
            // Enqueue packet with timestamp for sorting
            timestamp_queue_insert(ep_id, &pkt);
        }
    }
    close(fd);
    return NULL;
}

// Writer thread reassembles and writes to storage
void* storage_writer_thread(void* arg) {
    int raid_fd = open("/dev/md0", O_WRONLY | O_DIRECT);
    
    void *aligned_buf;
    posix_memalign(&aligned_buf, 4096, BUFFER_SIZE);
    
    while (running) {
        // Get packets from all 4 endpoints in timestamp order
        struct fpga_adc_packet *pkts[4];
        get_synchronized_packets(pkts);
        
        // Reassemble into channel order: Ch0, Ch1, ..., Ch7
        uint16_t *out = (uint16_t*)aligned_buf;
        for (int i = 0; i < SAMPLES_PER_PKT; i++) {
            out[i*8 + 0] = pkts[0]->samples[0][i];  // Ch0
            out[i*8 + 1] = pkts[0]->samples[1][i];  // Ch1
            out[i*8 + 2] = pkts[1]->samples[0][i];  // Ch2
            out[i*8 + 3] = pkts[1]->samples[1][i];  // Ch3
            out[i*8 + 4] = pkts[2]->samples[0][i];  // Ch4
            out[i*8 + 5] = pkts[2]->samples[1][i];  // Ch5
            out[i*8 + 6] = pkts[3]->samples[0][i];  // Ch6
            out[i*8 + 7] = pkts[3]->samples[1][i];  // Ch7
        }
        
        // Write to RAID array
        write(raid_fd, aligned_buf, BUFFER_SIZE);
    }
    
    close(raid_fd);
    return NULL;
}
```

**Performance Considerations:**
- Pin threads to specific CPU cores to avoid migration overhead
- Use huge pages for DMA buffers (`mmap()` with `MAP_HUGETLB`)
- Consider interrupt coalescing to reduce interrupt overhead
- Monitor dropped packets due to buffer overflow

### RAID Configuration for High-Speed Data Logging

The Valkra variant enables 4 NVMe drives (RP8-RP11) for RAID storage.

**RAID Performance Comparison:**

| RAID Level | Drives | Write BW | Redundancy | Usable Capacity | Use Case |
|------------|--------|----------|------------|-----------------|----------|
| RAID 0     | 4      | ~3.6 GB/s | None       | 4× drive size   | Maximum performance, external backup |
| RAID 5     | 4      | ~2.7 GB/s | 1 drive    | 3× drive size   | Balanced performance + redundancy |
| RAID 10    | 4      | ~1.8 GB/s | 50%        | 2× drive size   | High IOPS, lower capacity |

**Creating RAID 5 Array:**
```bash
# Identify NVMe devices
lsblk -d -o NAME,SIZE,MODEL | grep nvme

# Expected devices on Valkra:
# nvme0n1  - Boot drive (RP3)
# nvme1n1  - RAID drive 1 (RP8)
# nvme2n1  - RAID drive 2 (RP9)
# nvme3n1  - RAID drive 3 (RP10)
# nvme4n1  - RAID drive 4 (RP11)

# Create RAID 5 array with 128KB chunk size
mdadm --create /dev/md0 --level=5 --raid-devices=4 \
    --chunk=128 \
    /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1

# Monitor array creation
watch cat /proc/mdstat

# Format with XFS (recommended for streaming writes)
mkfs.xfs -f -d su=128k,sw=3 -l size=128m /dev/md0

# Or ext4 with appropriate stride/stripe-width
mkfs.ext4 -E stride=32,stripe-width=96 /dev/md0

# Mount with optimized options
mkdir -p /mnt/raid
mount -o noatime,nodiratime,discard /dev/md0 /mnt/raid

# Make persistent in /etc/fstab
echo "/dev/md0  /mnt/raid  xfs  noatime,nodiratime,discard  0  2" >> /etc/fstab
```

**Creating RAID 0 Array (Maximum Performance):**
```bash
# No redundancy, maximum speed
mdadm --create /dev/md0 --level=0 --raid-devices=4 \
    --chunk=128 \
    /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1

mkfs.xfs -f -d su=128k,sw=4 /dev/md0
mount -o noatime,nodiratime /dev/md0 /mnt/raid
```

**RAID Configuration File:**
```bash
# Save RAID configuration
mdadm --detail --scan > /etc/mdadm/mdadm.conf

# Update initramfs
update-initramfs -u
```

**Monitoring RAID Health:**
```bash
# Check array status
mdadm --detail /dev/md0

# Monitor performance
iostat -x 1 /dev/md0

# Check for errors
dmesg | grep -i md0
```

### Direct Block Device Writing (Maximum Performance)

For absolute maximum throughput, skip the filesystem and write directly to the RAID device:

```c
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

int main() {
    // Open RAID device directly
    int fd = open("/dev/md0", O_WRONLY | O_DIRECT | O_SYNC);
    
    // Allocate aligned buffer (required for O_DIRECT)
    void *buf;
    size_t buf_size = 1024 * 1024;  // 1MB
    posix_memalign(&buf, 4096, buf_size);
    
    // Write data
    ssize_t written = write(fd, buf, buf_size);
    
    // Fsync to ensure data persistence
    fsync(fd);
    
    free(buf);
    close(fd);
    return 0;
}
```

**Advantages of Direct Block Device Writing:**
- No filesystem overhead (~5-10% performance gain)
- Predictable latency
- Full control over write patterns

**Disadvantages:**
- No file management (manual offset tracking required)
- No crash recovery (filesystem journal)
- Harder to manage data rotation/deletion

### Performance Tuning

**System-Level Tuning:**
```bash
# Increase max read-ahead
echo 8192 > /sys/block/md0/queue/read_ahead_kb

# Disable disk scheduler (none or noop for NVMe)
echo none > /sys/block/nvme1n1/queue/scheduler
echo none > /sys/block/nvme2n1/queue/scheduler
echo none > /sys/block/nvme3n1/queue/scheduler
echo none > /sys/block/nvme4n1/queue/scheduler

# Increase stripe cache size
echo 8192 > /sys/block/md0/md/stripe_cache_size

# Disable NCQ (may help with some drives)
echo 1 > /sys/block/nvme1n1/device/queue_depth
```

**CPU Pinning:**
```bash
# Pin reader threads to cores 0-3
taskset -c 0 ./reader_thread 0 &
taskset -c 1 ./reader_thread 1 &
taskset -c 2 ./reader_thread 2 &
taskset -c 3 ./reader_thread 3 &

# Pin writer thread to core 4
taskset -c 4 ./writer_thread &
```

**Memory:**
```bash
# Use huge pages for DMA buffers
echo 256 > /proc/sys/vm/nr_hugepages

# In application:
void *buf = mmap(NULL, size, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB, -1, 0);
```

### Gen3 Signal Integrity Requirements

When implementing PCIe Gen3 on your carrier board:

**PCB Design:**
- Controlled impedance: 85Ω ±10% (vs ±15% for Gen2)
- Differential pair routing with tight coupling
- Minimize vias (ideally ≤2 vias per trace)
- Keep traces on same layer if possible
- Ground/power plane separation

**Trace Length:**
- Match differential pair lengths within ±5 mils
- Total trace length < 12 inches for Gen3
- Loss budget: <-18dB at Nyquist (4 GHz for Gen3)

**Reference Clock:**
- Jitter: <100ps RMS (vs <200ps for Gen2)
- 100MHz ±300ppm frequency accuracy
- Spread spectrum clocking (SSC) optional but recommended

**Connectors:**
- SODIMM connectors typically support Gen3 if properly specified
- Verify connector specs support 8 GT/s signaling
- Good contact force and impedance matching

**Testing:**
- Use eye diagram analysis to verify signal quality
- Check for excessive jitter or ISI (inter-symbol interference)
- Verify link training completes successfully
- Monitor correctable/uncorrectable errors in LTSSM

### Troubleshooting Multi-Endpoint Systems

**Problem: Some endpoints not detected**
```bash
# Check PCIe link status
lspci -tv
lspci -vv | grep -i "lnksta"

# Check kernel messages
dmesg | grep -i pcie
dmesg | grep -i 'link up\|link down'

# Verify FPGA initialization
# May need to increase PcieRpDetectTimeoutMs in devicetree
```

**Problem: Data corruption or packet loss**
- Check for PCIe errors: `lspci -vvv | grep -i aer`
- Verify timestamp synchronization between endpoints
- Monitor DMA buffer usage (potential overflow)
- Check memory bandwidth with `mbw` or similar tools

**Problem: Lower than expected bandwidth**
- Verify Gen3 link negotiation: `lspci -vv | grep "LnkSta:"`
- Should show "Speed 8GT/s" for Gen3
- Check CPU utilization (may be bottleneck in reassembly)
- Monitor RAID array performance with `iostat`

**Problem: System instability**
- Check power delivery (Gen3 uses more power)
- Verify thermal management (FPGA and NVMe drives generate heat)
- Monitor PCIe correctable errors (excessive errors indicate signal integrity issues)
- Test with Gen2 fallback to isolate Gen3-specific issues

## PCIe Bifurcation Configuration (Advanced)

### Understanding Bifurcation on ADL-N

Intel Alder Lake-N organizes its 9 PCIe lanes into three controllers with flexible bifurcation support:

**Controller Organization:**
- **Controller 1 (HSIO 0-3):** 4 lanes, supports x4, x2x2, x2x1x1, or x1x1x1x1
- **Controller 2 (HSIO 6):** 1 lane, fixed x1
- **Controller 3 (HSIO 8-11):** 4 lanes, supports x4, x2x2, x2x1x1, or x1x1x1x1

**Important Constraint:** Maximum of **5 active PCIe root ports** total across all controllers!

### Bifurcation Mode Reference Table

From Intel Alder Lake-N Datasheet (Document 759603-002):

#### Controller 1 (HSIO Lanes 0-3)

| Mode | HSIO 0 | HSIO 1 | HSIO 2 | HSIO 3 | Root Ports Used | Total Ports |
|------|--------|--------|--------|--------|-----------------|-------------|
| **1x4** | RP1 | RP1 | RP1 | RP1 | RP1 (x4) | 1 |
| **2x2** | RP1 | RP1 | RP3 | RP3 | RP1 (x2), RP3 (x2) | 2 |
| **1x2+2x1** | RP1 | RP1 | RP3 | RP4 | RP1 (x2), RP3 (x1), RP4 (x1) | 3 |
| **4x1** | RP1 | RP2 | RP3 | RP4 | RP1-4 (each x1) | 4 |

#### Controller 3 (HSIO Lanes 8-11)

| Mode | HSIO 8 | HSIO 9 | HSIO 10 | HSIO 11 | Root Ports Used | Total Ports |
|------|--------|--------|---------|---------|-----------------|-------------|
| **1x4** | RP9 | RP9 | RP9 | RP9 | RP9 (x4) | 1 |
| **2x2** | RP9 | RP9 | RP11 | RP11 | RP9 (x2), RP11 (x2) | 2 |
| **1x2+2x1** | RP9 | RP9 | RP11 | RP12 | RP9 (x2), RP11 (x1), RP12 (x1) | 3 |
| **4x1** | RP9 | RP10 | RP11 | RP12 | RP9-12 (each x1) | 4 |

**Note:** Lane Reversal (LR) modes swap the physical lane order but provide the same logical configuration.

### Configuring Bifurcation

**Critical:** Bifurcation modes are set in Flash Descriptor soft straps, **NOT** in coreboot devicetree!

#### Method 1: Intel Flash Image Tool (FIT) - Official

1. Download Intel Flash Image Tool from Intel website
2. Load your flash image
3. Navigate to PCH Strap Configuration
4. Set Controller 1 and Controller 3 bifurcation modes
5. Save and flash updated descriptor

#### Method 2: ifdtool (Open Source)

```bash
cd util/ifdtool
make

# Examine current descriptor
./ifdtool -d your_flash.bin

# Output shows current soft strap configuration
# Bifurcation straps are in PCH Strap section
# Exact bit positions vary by platform - consult datasheet
```

**Warning:** ifdtool does not currently have built-in bifurcation modification for ADL-N. You may need to:
- Manually edit descriptor binary (advanced)
- Use Intel FIT
- Request pre-configured descriptor from hardware vendor

### Bifurcation Configuration Examples

#### Example 1: Valkra Variant (2×x2 NVMe + 1×x4 FPGA)

**Goal:** 2 NVMe drives at x2 each, 1 FPGA at x4

**Configuration:**
```
Controller 1: 2x2 mode
  RP1 = NVMe 1 (x2, HSIO 0-1)
  RP3 = NVMe 2 (x2, HSIO 2-3)

Controller 3: 1x4 mode
  RP9 = FPGA (x4, HSIO 8-11)

Controller 2: x1 mode (default)
  RP7 = Ethernet (x1, HSIO 6)
```

**Total Root Ports:** 4 (RP1, RP3, RP7, RP9) ✓ Within 5-port limit

**devicetree.cb snippet:**
```c
chip soc/intel/alderlake
    device domain 0 on
        device ref pcie_rp1 on  # NVMe 1, will be x2 after bifurcation
            register "pch_pcie_rp[PCH_RP(1)]" = "{ ... }"
            smbios_slot_desc "SlotTypeM2Socket3" "SlotLengthOther"
                             "NVMe Primary" "SlotDataBusWidth2X"
        end

        device ref pcie_rp3 on  # NVMe 2, will be x2 after bifurcation
            register "pch_pcie_rp[PCH_RP(3)]" = "{ ... }"
            smbios_slot_desc "SlotTypeM2Socket3" "SlotLengthOther"
                             "NVMe Secondary" "SlotDataBusWidth2X"
        end

        device ref pcie_rp9 on  # FPGA, will be x4 after bifurcation
            register "pch_pcie_rp[PCH_RP(9)]" = "{ ... }"
            smbios_slot_desc "SlotTypePciExpressGen3X4" "SlotLengthOther"
                             "FPGA ADC" "SlotDataBusWidth4X"
        end
    end
end
```

#### Example 2: Maximum x1 Ports (Storage Server)

**Goal:** Maximum number of independent PCIe devices

**Configuration:**
```
Controller 1: 4x1 mode
  RP1 = NVMe 1 (x1)
  RP2 = NVMe 2 (x1)
  RP3 = NVMe 3 (x1)
  RP4 = NVMe 4 (x1)

Controller 3: 4x1 mode
  RP9 = NVMe 5 (x1)
  (RP10-12 disabled to stay within 5-port limit)
```

**Total Root Ports:** 5 (RP1-4, RP9) ✓ Exactly at limit
**Note:** Cannot enable RP7 (Ethernet) without exceeding 5-port limit!

#### Example 3: Single x4 Accelerator

**Goal:** Maximum bandwidth to single PCIe device

**Configuration:**
```
Controller 1: 1x4 mode
  RP1 = GPU/Accelerator (x4, HSIO 0-3)

Controller 2: x1 mode
  RP7 = Ethernet (x1, HSIO 6)
```

**Total Root Ports:** 2 (RP1, RP7) ✓ Well within limit
**Available:** 3 more root ports can be added if needed

### Verifying Bifurcation Configuration

After flashing with correct bifurcation:

```bash
# Check negotiated link width
lspci -vv | grep "LnkCap:\|LnkSta:"

# Example output for x2 link:
# LnkCap: Port #0, Speed 8GT/s, Width x2, ASPM L0s L1
# LnkSta: Speed 8GT/s (ok), Width x2 (ok)

# Example output for x4 link:
# LnkCap: Port #0, Speed 8GT/s, Width x4, ASPM L0s L1
# LnkSta: Speed 8GT/s (ok), Width x4 (ok)
```

**Common Issues:**
- **Width x1 when expecting x2/x4:** Bifurcation not configured correctly
- **Device not detected:** Port not enabled in devicetree or exceeds 5-port limit
- **Link training failure:** Signal integrity issues or incompatible device

### Limitations and Caveats

1. **5 Root Port Maximum:** This is a silicon limitation, cannot be worked around
2. **No Runtime Changes:** Bifurcation is set at boot from flash descriptor
3. **No Mixed USB3/PCIe on Same Controller:** HSIO lanes 0-3 can be ALL PCIe or SOME USB3, but bifurcation only applies to PCIe mode
4. **UFS Conflicts:** If UFS storage is enabled, HSIO lanes 8-9 become UFS (not PCIe)

## Summary: Valkra Variant Capabilities (Updated for N305)

The Valkra variant configuration optimizes the LattePanda Mu N305 for industrial data acquisition:

**Platform:**
- LattePanda Mu with Intel Core i3-N305 (8-core, 15W TDP)
- 9 HSIO PCIe Gen3 lanes fully utilized
- 4 active PCIe root ports (within 5-port limit)

**PCIe Port Allocation:**
- 1× Gen3 x4 port for FPGA (RP9) = 3.6 GB/s ADC input
- 2× Gen3 x2 ports for NVMe (RP1, RP3) = 3.6 GB/s combined storage
- 1× Gen3 x1 port for Ethernet (RP7) = 1 Gbps network

**Bifurcation Configuration:**
- Controller 1: **2x2** mode (RP1 x2, RP3 x2)
- Controller 3: **1x4** mode (RP9 x4)
- Flash descriptor must be configured before first boot

**Storage:**
- eMMC 5.1 HS400: Primary boot (~400 MB/s)
- 2× NVMe Gen3 x2: RAID 1 for redundancy (~1.8 GB/s effective)

**Performance:**
- ADC Input: 225 MSPS @ 8 channels × 16-bit (3.6 GB/s from FPGA)
- Storage: 1.8 GB/s sustained writes (RAID 1 mirrored)
- Continuous recording: ~112 MSPS to RAID storage
- Burst recording: Full 225 MSPS to RAM, then flush to storage

**Industrial Features:**
- Ethernet-only connectivity (remote deployment)
- RAID 1 storage redundancy
- eMMC boot failover
- ECC RAM support (N305 IBECC)
- USB 2.0 for JTAG and diagnostics

**Power Budget:**
- Idle: ~6-8W (with ASPM enabled)
- Full load (225 MSPS): ~15W
- USB 3.x disabled saves ~1W
- NVMe ASPM L1.2 saves ~2W per drive

**Applications:**
- Industrial data acquisition and monitoring
- Remote sensor networks with high sample rates
- FPGA-based signal processing systems
- Quality control and inspection systems
- Scientific instrumentation

This configuration demonstrates optimal use of LattePanda Mu N305 for high-bandwidth industrial applications while staying within platform limits and maintaining reliability for remote deployment.
