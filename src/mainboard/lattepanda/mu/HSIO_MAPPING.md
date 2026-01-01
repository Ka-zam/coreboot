# LattePanda Mu HSIO and PCIe Configuration

## Overview

The LattePanda Mu uses Intel Alder Lake-N (ADL-N) which provides 12 PCH-based PCIe root ports. The physical HSIO (High-Speed IO) differential pairs are exposed on the SODIMM connector and can be configured as PCIe lanes.

## Intel Alder Lake-N PCIe Architecture

### PCH Root Ports
- **Total PCH Root Ports:** 12
- **CPU Root Ports:** 0 (not available on ADL-N)
- **Thunderbolt Ports:** 0 (not available on ADL-N)
- **PCIe Clock Sources:** 5 (REFCLK0-4)

### PCI Device Mapping
```
Bus 0, Device 0x1c (PCH_DEV_SLOT_PCIE):
  Function 0 = RP1  (pcie_rp1)  - Available
  Function 1 = RP2  (pcie_rp2)  - Available
  Function 2 = RP3  (pcie_rp3)  - Used: M.2 M-key SSD
  Function 3 = RP4  (pcie_rp4)  - Used: M.2 E-key WiFi
  Function 4 = RP5  (pcie_rp5)  - Available
  Function 5 = RP6  (pcie_rp6)  - Available
  Function 6 = RP7  (pcie_rp7)  - Used: RTL8111H GbE
  Function 7 = RP8  (pcie_rp8)  - Available

Bus 0, Device 0x1d (PCH_DEV_SLOT_PCIE_1):
  Function 0 = RP9  (pcie_rp9)  - Available
  Function 1 = RP10 (pcie_rp10) - Available
  Function 2 = RP11 (pcie_rp11) - Available
  Function 3 = RP12 (pcie_rp12) - Available
```

## SODIMM Connector HSIO Lanes

Based on the pinout documentation, the following HSIO differential pairs are exposed:

### Front Side SODIMM Pins

| HSIO Lane | TX Pins | RX Pins (Back) | Notes |
|-----------|---------|----------------|-------|
| HSIO0     | 13, 15  | 16, 18         | Differential pair with coupling caps required |
| HSIO1     | 19, 21  | 22, 24         | Differential pair with coupling caps required |
| HSIO2     | 25, 27  | 28, 30         | Differential pair with coupling caps required |
| HSIO3     | 31, 33  | 34, 36         | Differential pair with coupling caps required |
| HSIO8     | 37, 39  | 40, 42         | Differential pair with coupling caps required |
| HSIO9     | 43, 45  | 46, 48         | Differential pair with coupling caps required |
| HSIO10    | 49, 51  | 52, 54         | Differential pair with coupling caps required |
| HSIO11    | 55, 57  | 58, 60         | Differential pair with coupling caps required |
| HSIO6     | 61, 63  | 64, 66         | Differential pair with coupling caps required |

**Total Available:** 9 HSIO differential lane pairs

### PCIe Reference Clocks (Front Side)

| Clock | Pins | Notes |
|-------|------|-------|
| REFCLK0 | 85, 87 | PCIe reference clock |
| REFCLK1 | 91, 93 | PCIe reference clock |
| REFCLK2 | 97, 99 | PCIe reference clock |
| REFCLK3 | 88, 90 (back) | PCIe reference clock |
| REFCLK4 | 94, 96 (back) | PCIe reference clock |

### Clock Request Signals (Back Side)

| Signal | Pin | SoC GPIO | Notes |
|--------|-----|----------|-------|
| PCIECLK_REQ3# | 100 | GPP_D8 | REFCLK3 clock request |
| PCIECLK_REQ4# | 102 | GPP_H19 | REFCLK4 clock request |

## Current LattePanda Mu Base Configuration

### Enabled PCIe Ports

**Port 3 (RP3) - M.2 M-key 2230 SSD:**
- PCI Address: 0:1c.2
- Clock: Free-running (clock 0)
- Flags: LTR, AER
- ASPM: Disabled
- L1 Substates: Disabled

**Port 4 (RP4) - M.2 E-key 2230 WiFi:**
- PCI Address: 0:1c.3
- Clock: Free-running (clock 3)
- Flags: LTR, AER
- ASPM: Disabled
- L1 Substates: Disabled

**Port 7 (RP7) - RTL8111H Ethernet:**
- PCI Address: 0:1c.6
- Clock: Free-running (clock 4)
- Flags: LTR, AER, BUILT_IN
- ASPM: Disabled
- L1 Substates: Disabled

### Available PCIe Ports

**Unused Ports:** RP1, RP2, RP5, RP6, RP8, RP9, RP10, RP11, RP12 (9 total)

## HSIO to PCIe Port Mapping

**Important Note:** Intel Alder Lake-N handles HSIO lane assignment automatically through the FSP (Firmware Support Package) based on enabled PCIe root ports. The physical HSIO lanes are flexibly assigned by the silicon/FSP when you enable a PCIe root port in the device tree.

### Typical Lane Assignment Pattern

While the exact lane-to-port mapping is managed by FSP, typical patterns are:
- RP1-RP8: First 8 HSIO lanes (flexible assignment)
- RP9-RP12: Remaining HSIO lanes (flexible assignment)
- Unused ports: Associated HSIO lanes are powered down

The key is to enable the PCIe root ports you need in devicetree.cb, and the FSP will handle the physical lane routing.

## Configuring Additional PCIe Ports

### Example: Enable RP1 for Additional M.2 Slot

In your board's devicetree.cb or overridetree.cb:

```
chip soc/intel/alderlake
    device domain 0 on
        device ref pcie_rp1 on
            register "pch_pcie_rp[PCH_RP(1)]" = "{
                .clk_src = 1,
                .clk_req = 1,
                .flags = PCIE_RP_LTR | PCIE_RP_AER,
            }"
            chip drivers/pci/generic
                device pci 00.0 on end
            end
        end
    end
end
```

### Clock Configuration Options

**Free-Running Clock (no CLKREQ#):**
```
.clk_src = PCIE_CLK_FREE_RUNNING,
.flags = PCIE_RP_CLK_SRC_UNUSED | PCIE_RP_CLK_REQ_UNUSED,
```

**Dynamic Clock with CLKREQ#:**
```
.clk_src = 0,  // Use REFCLK0
.clk_req = 0,  // Use CLKREQ0# signal
```

### Common Flags

- `PCIE_RP_LTR` - Enable Latency Tolerance Reporting
- `PCIE_RP_AER` - Enable Advanced Error Reporting
- `PCIE_RP_HOTPLUG` - Mark as hotplug-capable slot
- `PCIE_RP_BUILT_IN` - Mark as built-in device (not a slot)
- `PCIE_RP_CLK_SRC_UNUSED` - No clock source used
- `PCIE_RP_CLK_REQ_UNUSED` - No clock request signal

## Power Management

### ASPM (Active State Power Management)

The base configuration disables ASPM for compatibility. To enable:

```
register "pch_pcie_rp[PCH_RP(X)]" = "{
    .flags = PCIE_RP_LTR | PCIE_RP_AER,
    .pcie_rp_aspm = ASPM_L0S_L1,
}"
```

Options:
- `ASPM_DISABLE` - No ASPM (default)
- `ASPM_L0S` - L0s only
- `ASPM_L1` - L1 only
- `ASPM_L0S_L1` - Both L0s and L1

### L1 Substates

```
register "pch_pcie_rp[PCH_RP(X)]" = "{
    .flags = PCIE_RP_LTR | PCIE_RP_AER,
    .PcieRpL1Substates = L1_SS_L1_2,
}"
```

Options:
- `L1_SS_DISABLED` - Disabled (default)
- `L1_SS_L1_1` - L1.1 only
- `L1_SS_L1_2` - L1.2 only
- `L1_SS_L1_1_L1_2` - Both L1.1 and L1.2

## Valkra Variant HSIO Configuration

The Valkra variant is an industrial data acquisition system optimized for LattePanda Mu N305 with the following HSIO lane allocation:

### Complete HSIO Lane Allocation Table

| HSIO Lane | Physical Signal | Valkra Usage | Controller | Root Port | Bifurcation | Bandwidth |
|-----------|----------------|--------------|------------|-----------|-------------|-----------|
| **0** | PCIE1/USB32_1 | NVMe Drive 1 (lane 0) | Controller 1 | RP1 | 2x2 mode | Part of x2 |
| **1** | PCIE2/USB32_2 | NVMe Drive 1 (lane 1) | Controller 1 | RP1 | 2x2 mode | Part of x2 |
| **2** | PCIE3/USB32_3 | NVMe Drive 2 (lane 0) | Controller 1 | RP3 | 2x2 mode | Part of x2 |
| **3** | PCIE4/USB32_4 | NVMe Drive 2 (lane 1) | Controller 1 | RP3 | 2x2 mode | Part of x2 |
| **6** | PCIE7 | Gigabit Ethernet | Controller 2 | RP7 | x1 mode | 900 MB/s |
| **8** | PCIE9/UFS10 | FPGA (lane 0) | Controller 3 | RP9 | 1x4 mode | Part of x4 |
| **9** | PCIE10/UFS11 | FPGA (lane 1) | Controller 3 | RP9 | 1x4 mode | Part of x4 |
| **10** | PCIE11/SATA0 | FPGA (lane 2) | Controller 3 | RP9 | 1x4 mode | Part of x4 |
| **11** | PCIE12/SATA1 | FPGA (lane 3) | Controller 3 | RP9 | 1x4 mode | Part of x4 |

**Total:** 9/9 HSIO lanes fully utilized

### PCIe Root Port Summary

| Root Port | Width | Device | HSIO Lanes | Bandwidth | Notes |
|-----------|-------|--------|------------|-----------|-------|
| RP1 | x2 | NVMe Primary | 0-1 | ~1.8 GB/s | RAID 1 with RP3 |
| RP3 | x2 | NVMe Secondary | 2-3 | ~1.8 GB/s | RAID 1 with RP1 |
| RP7 | x1 | Gigabit Ethernet | 6 | ~900 MB/s | Realtek RTL8111H |
| RP9 | x4 | FPGA ADC System | 8-11 | ~3.6 GB/s | Kintex-7, 225 MSPS |

**Total Active Root Ports:** 4 (within ADL-N 5-port limit)

### Bifurcation Mode Requirements

**Critical:** The following bifurcation modes must be configured in the Flash Descriptor soft straps **before first boot**:

**Controller 1 (HSIO 0-3):**
- **Mode:** `2x2` (two x2 ports)
- **Result:** RP1 gets lanes 0-1 (x2), RP3 gets lanes 2-3 (x2)
- **From Datasheet Table:** "2x2" row shows RP1/RP1 for lanes 0-1, RP3/RP3 for lanes 2-3

**Controller 2 (HSIO 6):**
- **Mode:** `x1` (default, single lane)
- **Result:** RP7 gets lane 6 (x1)

**Controller 3 (HSIO 8-11):**
- **Mode:** `1x4` (single x4 port)
- **Result:** RP9 gets all lanes 8-11 (x4)
- **From Datasheet Table:** "1x4" row shows RP9/RP9/RP9/RP9 for lanes 8-11

### USB Configuration

**USB 3.x SuperSpeed:** Disabled to free HSIO lanes 0-3 for PCIe
**USB 2.0:** Enabled on ports 0-1 (no HSIO lanes consumed)
- Port 0: JTAG programming interface
- Port 1: Console/diagnostics access

USB 2.0 uses separate signal pins and does not consume HSIO lanes.

### Flash Descriptor Configuration

Bifurcation settings are stored in the Intel Flash Descriptor soft straps and cannot be changed at runtime through FSP UPD parameters.

**To configure bifurcation:**

1. Build ifdtool:
   ```bash
   cd util/ifdtool
   make
   ```

2. Examine current descriptor:
   ```bash
   ./ifdtool -d flash_image.bin
   ```

3. Modify soft straps:
   - Use Intel Flash Image Tool (FIT) for official method
   - Or work with LattePanda to provide correct descriptor configuration
   - Soft strap bit positions are platform-specific (see ADL-N datasheet)

4. Flash updated image with correct bifurcation straps

**Warning:** Incorrect bifurcation configuration will prevent PCIe devices from enumerating!

### Storage Configuration

**eMMC 5.1 HS400:**
- Location: Soldered on LattePanda Mu SoM
- Purpose: Primary boot device
- Bandwidth: ~400 MB/s
- No HSIO lanes consumed (dedicated interface)

**2× NVMe M.2 Drives (Gen3 x2 each):**
- Recommended: mdadm RAID 1 for redundancy
- Individual bandwidth: ~1.8 GB/s per drive
- RAID 1 effective write: ~1.8 GB/s (mirrored)
- Sufficient for 225 MSPS ADC data: 3.6 GB/s > 1.8 GB/s needed

### Performance Analysis

**FPGA → Host (RP9 x4):**
- Peak: 3.6 GB/s (225 MSPS × 8 channels × 16-bit)
- Sufficient for maximum ADC sample rate

**Host → Storage (2× NVMe in RAID 1):**
- Write bandwidth: ~1.8 GB/s
- **Bottleneck:** Cannot sustain continuous 225 MSPS recording
- **Maximum sustained:** ~112 MSPS continuous to RAID 1
- **Solution:** Use buffering or reduce sample rate for continuous recording

**Recommended Operating Modes:**
1. **Burst Mode:** Record at 225 MSPS to RAM, write bursts to NVMe
2. **Continuous Mode:** Reduce to 112 MSPS for sustained RAID 1 writes
3. **Single Drive:** Use one NVMe at ~900 MB/s for 56 MSPS continuous

### Industrial Deployment Notes

**Remote Operation:**
- Ethernet-only connectivity (no WiFi)
- USB 2.0 sufficient for field programming via JTAG
- No user-accessible slots (all devices built-in)

**Reliability Features:**
- RAID 1 mirrored storage
- eMMC boot failover
- ECC RAM (N305 IBECC support)
- Redundant power inputs (carrier board design)

**Power Optimization:**
- NVMe drives use ASPM L0s/L1 + L1.2 substates (~2W idle savings)
- USB 3.x disabled saves ~1W
- WiFi module disabled (RP4 off)
- Estimated idle power: ~6-8W
- Full load (225 MSPS): ~15W

## Carrier Board Design Guidelines

1. **Coupling Capacitors:** All HSIO TX/RX signals require AC coupling capacitors (typically 100nF)

2. **Impedance:** HSIO differential pairs should be 85Ω ±15% impedance

3. **Length Matching:** TX+/TX- and RX+/RX- pairs should be length-matched within ±5 mils

4. **Reference Clocks:** 100MHz differential clocks, typically require 100Ω impedance

5. **Clock Request:** Optional GPIO signals for dynamic clock control (power savings)

6. **PCIe Reset:** Consider adding PERST# signals per the PCIe specification

## USB vs PCIe Configuration

Some HSIO lanes can be configured as either PCIe or USB3 SuperSpeed. The configuration is determined by which devices you enable in the device tree:
- Enable `pcie_rpX` → Lane becomes PCIe
- Enable `usb3_portX` → Lane becomes USB3 SS

Consult the Intel Alder Lake-N datasheet for specific flex-IO lane capabilities.

## References

- Intel Alder Lake-N Datasheet
- coreboot devicetree documentation
- PCIe Base Specification
- LattePanda Mu Hardware Documentation
